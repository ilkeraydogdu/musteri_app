import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/menu_models.dart';
import '../../../core/models/venue_table_model.dart';
import '../../menu/application/menu_provider.dart';
import '../../menu/presentation/widgets/product_detail_sheet.dart';
import '../../table_service/presentation/widgets/table_qr_scanner_sheet.dart';
import '../application/table_session_provider.dart';

/// İşletme Vitrini — Trendyol Yemek / Getir Yemek tarzı pazarlama ekranı.
///
/// Bu ekran tamamen işletmenin kendi reklamına ayrılmıştır. Müşterinin tek
/// aksiyonu sağ üstteki küçük "Masaya Otur" (QR) butonudur. Tüm içerik
/// (reklam slaytları, kampanyalar, kategoriler, ürünler, mekan bilgisi)
/// canlı Qordy API'sinden (`tableSessionProvider` & `menuProvider`) gelir.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

// =============================================================================
// Palette — aydınlık, iştah açıcı pazaryeri tonları
// =============================================================================
class _P {
  static const Color bg = Color(0xFFF5F4F1);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF16171C);
  static const Color inkSoft = Color(0xFF5C606B);
  static const Color muted = Color(0xFF9A9EA8);
  static const Color line = Color(0xFFECEAE6);
  static const Color skeleton = Color(0xFFE9E7E3);
  static const Color accent = Color(0xFFF2541B); // paprika turuncusu
  static const Color yellow = Color(0xFFFFC529);
  static const Color green = Color(0xFF12A150);
  static const Color red = Color(0xFFE5383B);

  static const List<List<Color>> promoGradients = [
    [Color(0xFFF2541B), Color(0xFFFF8A3D)],
    [Color(0xFF6C3CE1), Color(0xFF9B6BFF)],
    [Color(0xFF0E9F6E), Color(0xFF3CCB8E)],
    [Color(0xFFE83E8C), Color(0xFFFF7AAE)],
    [Color(0xFFFF9F0A), Color(0xFFFFC94D)],
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

TextStyle _t(double size, FontWeight weight, Color color,
        {double? height, double spacing = 0}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

// =============================================================================
// Helpers
// =============================================================================
String _fmtPrice(double p) =>
    '₺${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2)}';

String _trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

String _trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

const Map<String, String> _latinFixes = {
  'pızza': 'pizza',
  'pızzalar': 'pizzalar',
  'mılkshake': 'milkshake',
  'smoothıe': 'smoothie',
  'chıcken': 'chicken',
  'frıes': 'fries',
  'tıramısu': 'tiramisu',
  'panını': 'panini',
  'ıced': 'iced',
  'drınks': 'drinks',
};

String _trTitle(String s) {
  return s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        var lower = _trLower(w);
        lower = _latinFixes[lower] ?? lower;
        if (lower.length == 1) return _trUpper(lower);
        return _trUpper(lower.substring(0, 1)) + lower.substring(1);
      })
      .join(' ');
}

bool _has(String? s) => s != null && s.trim().isNotEmpty;

String _discountLabel(VenueCampaign c) {
  final v = c.discountValue;
  final num = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return c.discountType == 'percentage' ? '%$num' : '₺$num';
}

typedef _TimeRange = ({int sh, int sm, int eh, int em});

_TimeRange? _parseRange(String text) {
  final m = RegExp(r'(\d{1,2})[:.](\d{2})\s*[-–—]\s*(\d{1,2})[:.](\d{2})')
      .firstMatch(text);
  if (m == null) return null;
  final sh = int.parse(m.group(1)!), sm = int.parse(m.group(2)!);
  final eh = int.parse(m.group(3)!), em = int.parse(m.group(4)!);
  if (sh > 23 || eh > 24 || sm > 59 || em > 59) return null;
  return (sh: sh, sm: sm, eh: eh, em: em);
}

/// Saat aralığının şu an geçerli olup olmadığını (gece yarısını aşan aralıklar dahil) döner.
bool _inRange(_TimeRange r, DateTime now) {
  final cur = now.hour * 60 + now.minute;
  final start = r.sh * 60 + r.sm;
  final end = r.eh * 60 + r.em;
  if (end > start) return cur >= start && cur < end;
  return cur >= start || cur < end; // overnight
}

String _hhmm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Kampanya saat aralığına göre canlı durum metni.
({String text, bool active})? _campaignStatus(VenueCampaign c, DateTime now) {
  final r = _parseRange('${c.title} ${c.description}');
  if (r == null) return null;
  if (_inRange(r, now)) {
    final cur = now.hour * 60 + now.minute;
    var end = r.eh * 60 + r.em;
    if (end <= cur) end += 24 * 60;
    final left = end - cur;
    final h = left ~/ 60, m = left % 60;
    return (
      text: 'Şu an geçerli · ${h > 0 ? '$h sa ' : ''}$m dk kaldı',
      active: true,
    );
  }
  return (
    text: 'Geçerlilik: ${_hhmm(r.sh, r.sm)} – ${_hhmm(r.eh, r.em)}',
    active: false,
  );
}

class _CategoryGroup {
  final String id;
  final String name;
  final List<MenuItemModel> items;
  final String? imageUrl;

  const _CategoryGroup(this.id, this.name, this.items, this.imageUrl);

  String? get cover {
    if (_has(imageUrl)) return imageUrl;
    for (final it in items) {
      if (_has(it.imageUrl)) return it.imageUrl;
    }
    return null;
  }

  double get minPrice => items
      .map((e) => e.price)
      .where((p) => p > 0)
      .fold<double>(double.infinity, (a, b) => b < a ? b : a);
}

class _Slide {
  final String image;
  final String title;
  final String subtitle;
  final String badge;
  const _Slide(this.image, this.title, this.subtitle, this.badge);
}

class _Story {
  final String label;
  final String image;
  final String headline;
  final String body;
  final String badge;
  const _Story(this.label, this.image, this.headline, this.body, this.badge);
}

// =============================================================================
// Screen
// =============================================================================
class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _heroCtrl = PageController();
  int _heroIndex = 0;
  int _heroCount = 0;
  Timer? _heroTimer;
  Timer? _clockTimer;

  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS → koyu ikonlar
    systemNavigationBarColor: _P.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroCtrl.hasClients || _heroCount < 2) return;
      _heroCtrl.animateToPage(
        (_heroIndex + 1) % _heroCount,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
    // Kampanya geri sayımları ve açık/kapalı durumu için dakikalık tazeleme
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableSessionProvider.notifier).fetchLiveVenueInfo();
      ref.read(menuProvider.notifier).fetchMenu(silent: true);
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _clockTimer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data shaping (live data only — no mock content)
  // ---------------------------------------------------------------------------
  List<_CategoryGroup> _groups(MenuState menu, List<MenuItemModel> items) {
    final byId = <String, List<MenuItemModel>>{};
    for (final it in items) {
      byId.putIfAbsent(it.categoryId, () => []).add(it);
    }
    final out = <_CategoryGroup>[];
    final used = <String>{};
    for (final c in menu.categories) {
      if (c.id == 'all' || used.contains(c.id)) continue;
      final list = byId[c.id];
      if (list == null || list.isEmpty) continue;
      used.add(c.id);
      out.add(_CategoryGroup(c.id, _trTitle(c.name), list, c.imageUrl));
    }
    for (final e in byId.entries) {
      if (used.contains(e.key) || e.key.isEmpty) continue;
      out.add(_CategoryGroup(
          e.key, _trTitle(e.key.replaceAll(RegExp(r'[-_]'), ' ')), e.value, null));
    }
    return out;
  }

  List<_Slide> _heroSlides(VenueTableModel v, List<MenuItemModel> featured) {
    final out = <_Slide>[];
    for (final s in v.promoSlides) {
      final img = s.isVideo ? (s.poster ?? '') : s.url;
      if (!_has(img)) continue;
      out.add(_Slide(
        img,
        _has(s.title) ? s.title : v.venueName,
        s.subtitle,
        s.isVideo ? 'MUTFAKTAN' : 'ÖNE ÇIKAN',
      ));
    }
    if (out.isEmpty && _has(v.bannerUrl)) {
      out.add(_Slide(v.bannerUrl!, _has(v.welcomeTitle) ? v.welcomeTitle : v.venueName,
          v.welcomeSubtitle, 'HOŞ GELDİNİZ'));
    }
    if (featured.isNotEmpty && _has(featured.first.imageUrl)) {
      final f = featured.first;
      out.add(_Slide(
        f.imageUrl!,
        f.name,
        _has(f.description) ? f.description : 'Şefin özel tarifi · ${_fmtPrice(f.price)}',
        'ŞEFİN ÖNERİSİ',
      ));
    }
    return out;
  }

  List<_Story> _stories(
      VenueTableModel v, List<MenuItemModel> featured, List<_CategoryGroup> groups) {
    final out = <_Story>[];
    final campaignImg = featured.length > 1 ? featured[1].imageUrl : v.bannerUrl;
    for (final c in v.campaigns) {
      if (!_has(campaignImg)) break;
      out.add(_Story('Fırsat', campaignImg!, '${_discountLabel(c)} İndirim',
          '${c.title}\n\n${c.description}'.trim(), 'KAMPANYA'));
    }
    if (featured.isNotEmpty && _has(featured.first.imageUrl)) {
      final f = featured.first;
      out.add(_Story('Şefin Seçimi', f.imageUrl!, f.name,
          _has(f.description) ? f.description : 'Mutfağımızın imza lezzeti', _fmtPrice(f.price)));
    }
    for (final g in groups.take(6)) {
      final cover = g.cover;
      if (!_has(cover)) continue;
      final min = g.minPrice;
      out.add(_Story(
        g.name.split(' ').first,
        cover!,
        g.name,
        '${g.items.length} çeşit${min.isFinite ? ' · en uygun ${_fmtPrice(min)}' : ''}\n\n'
        '${g.items.take(4).map((e) => e.name).join(' · ')}',
        'MENÜ',
      ));
    }
    if (_has(v.bannerUrl)) {
      out.add(_Story('Mekan', v.bannerUrl!, v.venueName,
          [v.address, v.workingHours].where(_has).join('\n'), 'MEKAN'));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _onTablePill(VenueTableModel venue) {
    HapticFeedback.mediumImpact();
    if (venue.isSeated) {
      _showTableActionsModal(venue);
    } else {
      TableQrScannerSheet.show(context);
    }
  }

  void _showTableActionsModal(VenueTableModel venue) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.checkmark_seal_fill, color: _P.green, size: 20),
            const SizedBox(width: 8),
            Text(
              '${venue.tableName} · ${venue.venueName}',
              style: _t(16, FontWeight.w800, _P.ink),
            ),
          ],
        ),
        message: Text(
          'Masanızda aktif oturumdasınız (${venue.guestCount} kişi).',
          style: _t(13, FontWeight.w500, _P.inkSoft),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/menu');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.book_fill, size: 18, color: _P.ink),
                const SizedBox(width: 8),
                Text('Dijital Menüyü Gör', style: _t(15, FontWeight.w700, _P.ink)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              TableQrScannerSheet.show(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.qrcode_viewfinder, size: 18, color: _P.ink),
                const SizedBox(width: 8),
                Text('Masayı Değiştir (QR Okut)', style: _t(15, FontWeight.w600, _P.ink)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              final res = await ref.read(tableSessionProvider.notifier).leaveTable();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Masadan ayrıldınız.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _P.ink,
                  ),
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.square_arrow_left, size: 18, color: _P.red),
                const SizedBox(width: 8),
                Text('Masadan Ayrıl (Oturumu Kapat)', style: _t(15, FontWeight.w700, _P.red)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Kapat', style: _t(16, FontWeight.w600, _P.inkSoft)),
        ),
      ),
    );
  }

  void _onItemTap(MenuItemModel item) {
    HapticFeedback.lightImpact();
    ProductDetailSheet.show(context, item);
  }

  void _onCategoryTap(String categoryId) {
    HapticFeedback.lightImpact();
    ref.read(menuProvider.notifier).selectCategory(categoryId);
    context.go('/menu');
  }

  void _openStories(List<_Story> stories, int index, VenueTableModel venue) {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => _StoryViewer(
        stories: stories,
        initialIndex: index,
        venueName: venue.venueName,
        logoUrl: venue.logoUrl,
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(tableSessionProvider);
    final menu = ref.watch(menuProvider);
    final live = menu.lastSyncedAt != null;
    final items = live ? menu.allItems : const <MenuItemModel>[];
    final featured = live ? menu.featuredItems : const <MenuItemModel>[];
    final groups = _groups(menu, items);
    final slides = _heroSlides(venue, featured);
    final stories = _stories(venue, featured, groups);
    final now = DateTime.now();

    _heroCount = slides.length;
    if (_heroIndex >= _heroCount && _heroCount > 0) _heroIndex = 0;

    final railGroups = groups.where((g) => g.items.length >= 3).take(4).toList();
    final featuredIds = featured.map((e) => e.id).toSet();

    // Günün tavsiyesi: öne çıkanlardan güne göre dönen ürün
    MenuItemModel? spotlight;
    if (featured.isNotEmpty) {
      var idx = now.day % featured.length;
      if (idx == 0 && featured.length > 1) idx = 1;
      spotlight = featured[idx];
    }

    // Mozaik: farklı kategorilerden birer ürün
    final mosaic = <MenuItemModel>[];
    for (final g in groups) {
      final pick = g.items.firstWhere(
        (e) => _has(e.imageUrl) && !featuredIds.contains(e.id) && e.id != spotlight?.id,
        orElse: () => g.items.first,
      );
      if (_has(pick.imageUrl)) mosaic.add(pick);
      if (mosaic.length == 3) break;
    }

    // Cep dostu: en uygun fiyatlılar
    final budget = items.where((e) => e.price > 0 && _has(e.imageUrl)).toList()
      ..sort((a, b) => a.price.compareTo(b.price));

    final sections = <Widget>[
      const SizedBox(height: 12),
      _buildHero(slides),
      if (stories.isNotEmpty) _buildStories(stories, venue),
      if (venue.campaigns.isNotEmpty) ...[
        const _SectionHeader('Size Özel Fırsatlar', 'Bugün geçerli kampanyalarımız'),
        _buildCampaigns(venue.campaigns, now),
      ],
      if (!live) ..._buildSkeletons(),
      if (groups.isNotEmpty) ...[
        _SectionHeader('Menüde Neler Var?', '${groups.length} kategori · ${items.length} lezzet'),
        _buildCategoryTiles(groups),
      ],
      if (featured.isNotEmpty) ...[
        const _SectionHeader('Şefin Önerileri', 'Mutfağımızın imza lezzetleri'),
        _buildVerticalRail(featured, badge: 'ŞEF'),
      ],
      if (spotlight != null && _has(spotlight.imageUrl)) ...[
        const _SectionHeader('Günün Tavsiyesi', 'Bugün mutlaka denemelisiniz'),
        _buildSpotlight(spotlight),
      ],
      for (var i = 0; i < railGroups.length; i++) ...[
        _SectionHeader(
          railGroups[i].name,
          '${railGroups[i].items.length} çeşit'
          '${railGroups[i].minPrice.isFinite ? ' · en uygun ${_fmtPrice(railGroups[i].minPrice)}' : ''}',
        ),
        i.isEven
            ? _buildWideRail(railGroups[i].items)
            : _buildVerticalRail(railGroups[i].items),
        if (i == 1 && mosaic.length == 3) ...[
          const _SectionHeader('Popüler Lezzetler', 'Misafirlerimizin favorileri'),
          _buildMosaic(mosaic),
        ],
        if (i == 1 && budget.length >= 4) ...[
          const _SectionHeader('Cep Dostu Lezzetler', 'Uygun fiyatlı seçkimiz'),
          _buildVerticalRail(budget.take(10).toList(), priceTag: true),
        ],
      ],
      if (railGroups.length < 2 && budget.length >= 4) ...[
        const _SectionHeader('Cep Dostu Lezzetler', 'Uygun fiyatlı seçkimiz'),
        _buildVerticalRail(budget.take(10).toList(), priceTag: true),
      ],
      if (_has(venue.venueName)) ...[
        _SectionHeader('Mekanı Tanıyın', venue.venueName),
        _buildVenueCard(venue, now),
      ],
      if (!venue.isSeated) _buildHowItWorks(),
      _buildFooter(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: _P.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildTopBar(venue, now),
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await Future.wait([
                  ref.read(tableSessionProvider.notifier).fetchLiveVenueInfo(),
                  ref.read(menuProvider.notifier).fetchMenu(silent: true),
                ]);
              },
            ),
            SliverList(delegate: SliverChildListDelegate(sections)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP BAR — logo, isim, durum + tek küçük QR butonu
  // ===========================================================================
  Widget _buildTopBar(VenueTableModel venue, DateTime now) {
    final hours = _parseRange(venue.workingHours);
    final open = hours == null ? null : _inRange(hours, now);
    final rating = venue.rating > 0 ? ' · ★ ${venue.rating.toStringAsFixed(1)}' : '';

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _P.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.6,
      shadowColor: const Color(0x22000000),
      systemOverlayStyle: _overlay,
      toolbarHeight: 66,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _P.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _has(venue.logoUrl)
                ? _NetImg(venue.logoUrl!)
                : Center(
                    child: Text(
                      venue.venueName.isNotEmpty ? venue.venueName[0] : 'Q',
                      style: _t(18, FontWeight.w800, _P.accent),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  venue.venueName.isNotEmpty ? venue.venueName : 'Qordy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(16, FontWeight.w800, _P.ink, spacing: -0.2),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (open != null) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: open ? _P.green : _P.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        venue.workingHours.isNotEmpty
                            ? '${open == null ? '' : (open ? 'Açık · ' : 'Kapalı · ')}'
                              '${venue.workingHours.replaceAll(' - ', ' – ')}$rating'
                            : (venue.statusText.isNotEmpty ? venue.statusText : 'Canlı Menü'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(11.5, FontWeight.w600, _P.inkSoft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TablePill(venue: venue, onTap: () => _onTablePill(venue)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. HERO AD CAROUSEL
  // ===========================================================================
  Widget _buildHero(List<_Slide> slides) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final height = (width * 0.62).clamp(190.0, 300.0);

    if (slides.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _Skeleton(height: height, radius: 22),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _heroCtrl,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemBuilder: (_, i) {
              final s = slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetImg(s.image),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.35, 1.0],
                            colors: [Colors.transparent, Color(0xD9000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _Badge(s.badge, color: _P.accent),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _t(23, FontWeight.w800, Colors.white,
                                  height: 1.15, spacing: -0.4),
                            ),
                            if (_has(s.subtitle)) ...[
                              const SizedBox(height: 6),
                              Text(
                                s.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _t(13, FontWeight.w500,
                                    Colors.white.withValues(alpha: 0.88), height: 1.35),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == _heroIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _P.accent : const Color(0xFFD3D0CA),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 3. STORIES — Instagram / Trendyol tarzı hikayeler
  // ===========================================================================
  Widget _buildStories(List<_Story> stories, VenueTableModel venue) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: stories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final s = stories[i];
            return GestureDetector(
              onTap: () => _openStories(stories, i, venue),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [_P.accent, _P.yellow, Color(0xFFE83E8C), _P.accent],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: _P.bg,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(child: _NetImg(s.image)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: _t(11.5, FontWeight.w600, _P.ink),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. CAMPAIGN COUPON CARDS
  // ===========================================================================
  Widget _buildCampaigns(List<VenueCampaign> campaigns, DateTime now) {
    final single = campaigns.length == 1;
    final width = MediaQuery.sizeOf(context).width - 32;

    Widget card(VenueCampaign c, int i) {
      final g = _P.promoGradients[i % _P.promoGradients.length];
      final status = _campaignStatus(c, now);
      return Container(
        width: single ? width : 300,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: g.first.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: _Circle(130, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              right: 40,
              bottom: -50,
              child: _Circle(100, Colors.white.withValues(alpha: 0.08)),
            ),
            // Kupon çentikleri
            const Positioned(left: 98, top: -9, child: _Circle(18, _P.bg)),
            const Positioned(left: 98, bottom: -9, child: _Circle(18, _P.bg)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(_discountLabel(c),
                              style: _t(34, FontWeight.w900, Colors.white, spacing: -1)),
                        ),
                        Text('İNDİRİM',
                            style: _t(10.5, FontWeight.w800,
                                Colors.white.withValues(alpha: 0.85), spacing: 1.2)),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(c.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(14.5, FontWeight.w800, Colors.white, height: 1.25)),
                        if (_has(c.description)) ...[
                          const SizedBox(height: 4),
                          Text(c.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _t(11.5, FontWeight.w500,
                                  Colors.white.withValues(alpha: 0.88), height: 1.3)),
                        ],
                        if (status != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: status.active ? 0.95 : 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.clock_fill,
                                    size: 11, color: status.active ? g.first : Colors.white),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    status.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _t(10.5, FontWeight.w800,
                                        status.active ? g.first : Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (single) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: card(campaigns.first, 0),
      );
    }
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        itemCount: campaigns.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => card(campaigns[i], i),
      ),
    );
  }

  // ===========================================================================
  // 5. CATEGORY TILES
  // ===========================================================================
  Widget _buildCategoryTiles(List<_CategoryGroup> groups) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final g = groups[i];
          final cover = g.cover;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onCategoryTap(g.id),
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _P.surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: _P.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: cover != null
                        ? _NetImg(cover)
                        : const Icon(CupertinoIcons.square_grid_2x2, color: _P.muted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    g.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _t(11.5, FontWeight.w700, _P.ink, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 6. PRODUCT RAILS (dikey kart / yatay geniş kart)
  // ===========================================================================
  Widget _buildVerticalRail(List<MenuItemModel> items, {String? badge, bool priceTag = false}) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onItemTap(it),
            child: Container(
              width: 152,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _P.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _has(it.imageUrl) ? _NetImg(it.imageUrl!) : Container(color: _P.skeleton),
                        if (badge != null)
                          Positioned(top: 8, left: 8, child: _Badge(badge, color: _P.ink)),
                        if (priceTag)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _P.yellow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_fmtPrice(it.price),
                                  style: _t(12.5, FontWeight.w900, _P.ink)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _t(13, FontWeight.w700, _P.ink, height: 1.25)),
                          const Spacer(),
                          Row(
                            children: [
                              Text(_fmtPrice(it.price),
                                  style: _t(14, FontWeight.w800, _P.accent)),
                              const Spacer(),
                              if (it.prepTimeMinutes > 0) ...[
                                const Icon(CupertinoIcons.timer, size: 12, color: _P.muted),
                                const SizedBox(width: 3),
                                Text('${it.prepTimeMinutes} dk',
                                    style: _t(11, FontWeight.w600, _P.muted)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWideRail(List<MenuItemModel> items) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onItemTap(it),
            child: Container(
              width: 276,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _P.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 106,
                    height: double.infinity,
                    child: _has(it.imageUrl) ? _NetImg(it.imageUrl!) : Container(color: _P.skeleton),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(13.5, FontWeight.w700, _P.ink, height: 1.25)),
                        if (_has(it.description)) ...[
                          const SizedBox(height: 3),
                          Text(it.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(11.5, FontWeight.w500, _P.inkSoft)),
                        ],
                        const Spacer(),
                        Text(_fmtPrice(it.price), style: _t(15, FontWeight.w800, _P.accent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 7. SPOTLIGHT — Günün Tavsiyesi (büyük ürün reklamı)
  // ===========================================================================
  Widget _buildSpotlight(MenuItemModel it) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTap(it),
        child: Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: _P.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
          children: [
            _NetImg(it.imageUrl!),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE6000000), Color(0x33000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge('GÜNÜN TAVSİYESİ', color: _P.yellow, textColor: _P.ink),
                  const Spacer(),
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.62,
                    child: Text(it.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _t(26, FontWeight.w800, Colors.white, height: 1.1, spacing: -0.5)),
                  ),
                  if (_has(it.description)) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.62,
                      child: Text(it.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12.5, FontWeight.w500,
                              Colors.white.withValues(alpha: 0.85), height: 1.35)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _P.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_fmtPrice(it.price), style: _t(16, FontWeight.w900, Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ===========================================================================
  // 8. MOSAIC GRID
  // ===========================================================================
  Widget _buildMosaic(List<MenuItemModel> m) {
    Widget tile(MenuItemModel it, {bool big = false}) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _P.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetImg(it.imageUrl!),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(big ? 17 : 13.5, FontWeight.w800, Colors.white, height: 1.2)),
                  const SizedBox(height: 3),
                  Text(_fmtPrice(it.price),
                      style: _t(big ? 14 : 12.5, FontWeight.w800, _P.yellow)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 260,
        child: Row(
          children: [
            Expanded(flex: 6, child: tile(m[0], big: true)),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Expanded(child: tile(m[1])),
                  const SizedBox(height: 12),
                  Expanded(child: tile(m[2])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 9. VENUE INFO CARD
  // ===========================================================================
  Widget _buildVenueCard(VenueTableModel v, DateTime now) {
    final hours = _parseRange(v.workingHours);
    final open = hours == null ? null : _inRange(hours, now);

    Widget row(IconData icon, Color tint, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(13.5, FontWeight.w700, _P.ink)),
                    if (_has(sub))
                      Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w500, _P.inkSoft, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _P.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (v.rating > 0)
              row(CupertinoIcons.star_fill, const Color(0xFFF5A300),
                  '${v.rating.toStringAsFixed(1)} Misafir Puanı',
                  v.reviewCount > 0 ? '${v.reviewCount}+ değerlendirme' : ''),
            if (_has(v.workingHours))
              row(CupertinoIcons.clock_fill, open == false ? _P.red : _P.green,
                  open == null ? 'Çalışma Saatleri' : (open ? 'Şu an açık' : 'Şu an kapalı'),
                  v.workingHours.replaceAll(' - ', ' – ')),
            if (_has(v.address))
              row(CupertinoIcons.location_solid, _P.accent, 'Adres', v.address),
            if (v.showWifi && _has(v.wifiSsid))
              row(CupertinoIcons.wifi, const Color(0xFF3B82F6), 'Ücretsiz Wi-Fi',
                  'Masaya oturduğunuzda şifre otomatik paylaşılır'),
            if (_has(v.cuisineType))
              row(CupertinoIcons.flame_fill, const Color(0xFFE83E8C), 'Mutfak', v.cuisineType),
            if (v.amenities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: v.amenities
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: _P.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _P.line),
                          ),
                          child: Text(a, style: _t(11.5, FontWeight.w700, _P.inkSoft)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 10. HOW IT WORKS (bilgilendirme — buton değil)
  // ===========================================================================
  Widget _buildHowItWorks() {
    Widget step(IconData icon, String title) => Expanded(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: _t(11.5, FontWeight.w700, Colors.white, height: 1.25)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: _P.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text('Masadan sipariş 3 adımda',
                style: _t(15, FontWeight.w800, Colors.white)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                step(CupertinoIcons.qrcode_viewfinder, 'Masadaki QR\'ı okutun'),
                step(CupertinoIcons.book_fill, 'Menüden seçin'),
                step(CupertinoIcons.bell_fill, 'Siparişiniz masanıza gelsin'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 28, 16, MediaQuery.paddingOf(context).bottom + 24),
      child: Center(
        child: Text('Qordy ile güçlendirilmiştir',
            style: _t(11, FontWeight.w600, _P.muted, spacing: 0.3)),
      ),
    );
  }

  List<Widget> _buildSkeletons() {
    return [
      const _SectionHeader('Menüde Neler Var?', 'Menü yükleniyor…'),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const _Skeleton(width: 80, height: 80, radius: 22),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const _Skeleton(width: 152, height: 220, radius: 18),
        ),
      ),
    ];
  }
}

// =============================================================================
// Small widgets
// =============================================================================
class _TablePill extends StatelessWidget {
  final VenueTableModel venue;
  final VoidCallback onTap;
  const _TablePill({required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final seated = venue.isSeated;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: seated ? _P.green : _P.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              seated ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.qrcode_viewfinder,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                seated ? (venue.tableName.isNotEmpty ? venue.tableName : 'Masam') : 'Masaya Otur',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12.5, FontWeight.w800, Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader(this.title, [this.subtitle]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(19, FontWeight.w800, _P.ink, spacing: -0.3)),
          if (_has(subtitle)) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12.5, FontWeight.w500, _P.inkSoft)),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _Badge(this.text, {required this.color, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: _t(10, FontWeight.w800, textColor, spacing: 0.6)),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Skeleton({this.width, required this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _P.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _NetImg extends StatelessWidget {
  final String url;
  const _NetImg(this.url);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => Container(color: _P.skeleton),
      errorWidget: (_, _, _) => Container(
        color: _P.skeleton,
        child: const Icon(CupertinoIcons.photo, color: _P.muted),
      ),
    );
  }
}

// =============================================================================
// Story viewer — tam ekran, otomatik ilerleyen hikayeler
// =============================================================================
class _StoryViewer extends StatefulWidget {
  final List<_Story> stories;
  final int initialIndex;
  final String venueName;
  final String? logoUrl;

  const _StoryViewer({
    required this.stories,
    required this.initialIndex,
    required this.venueName,
    this.logoUrl,
  });

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;
  bool _closing = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    })
    ..forward();

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _ctrl.forward(from: 0);
    } else {
      _close();
    }
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stories[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Material(
        color: Colors.black,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final w = MediaQuery.sizeOf(context).width;
            d.localPosition.dx < w / 3 ? _prev() : _next();
          },
          onLongPressStart: (_) => _ctrl.stop(),
          onLongPressEnd: (_) => _ctrl.forward(),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 250) _close();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetImg(s.image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.22, 0.5, 1.0],
                    colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, _) => Row(
                          children: List.generate(widget.stories.length, (i) {
                            final v = i < _index ? 1.0 : (i == _index ? _ctrl.value : 0.0);
                            return Expanded(
                              child: Container(
                                height: 2.6,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _has(widget.logoUrl)
                                ? _NetImg(widget.logoUrl!)
                                : const Icon(CupertinoIcons.house_fill, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(widget.venueName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(14, FontWeight.w800, Colors.white)),
                          ),
                          GestureDetector(
                            onTap: _close,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _Badge(s.badge, color: _P.accent),
                      const SizedBox(height: 10),
                      Text(s.headline,
                          style: _t(30, FontWeight.w800, Colors.white, height: 1.1, spacing: -0.6)),
                      if (_has(s.body)) ...[
                        const SizedBox(height: 10),
                        Text(s.body,
                            maxLines: 7,
                            overflow: TextOverflow.ellipsis,
                            style: _t(15, FontWeight.w500,
                                Colors.white.withValues(alpha: 0.9), height: 1.45)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
