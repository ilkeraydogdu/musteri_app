import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../cart/application/cart_provider.dart';
import '../../table_service/presentation/request_bill_sheet.dart';
import '../../table_service/presentation/widgets/table_qr_scanner_sheet.dart';
import '../../welcome/application/table_session_provider.dart';
import '../../wheel/presentation/chef_chat_sheet.dart';
import '../application/menu_provider.dart';
import 'widgets/featured_carousel.dart';
import 'widgets/floating_cart_bar.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_sheet.dart';

/// Trendyol Yemek, Getir Yemek ve Yemeksepeti standartlarında
/// tam teşekküllü modern dijital masa menü ekranı.
class DigitalMenuScreen extends ConsumerStatefulWidget {
  const DigitalMenuScreen({super.key});

  @override
  ConsumerState<DigitalMenuScreen> createState() => _DigitalMenuScreenState();
}

class _DigitalMenuScreenState extends ConsumerState<DigitalMenuScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sessionNotifier = ref.read(tableSessionProvider.notifier);
      var session = ref.read(tableSessionProvider);
      if (session.venueId.isEmpty) {
        await sessionNotifier.fetchLiveVenueInfo();
        session = ref.read(tableSessionProvider);
      }
      ref.read(menuProvider.notifier).fetchMenu(
            tenantId: session.venueId.isNotEmpty ? session.venueId : null,
            tableId: session.tableId.isNotEmpty ? session.tableId : null,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _quickAddToCart(MenuItemModel item) {
    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addItem(
          item: item,
          quantity: 1,
        );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.name} sepete eklendi.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueTable = ref.watch(tableSessionProvider);
    final menuState = ref.watch(menuProvider);
    final menuNotifier = ref.read(menuProvider.notifier);

    final currentCategoryName = menuState.categories
        .firstWhere(
          (c) => c.id == menuState.selectedCategoryId,
          orElse: () => const MenuCategory(id: '', name: 'Tüm Lezzetler'),
        )
        .name;

    final isSearching = menuState.searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  await Future.wait([
                    menuNotifier.fetchMenu(silent: true),
                    ref.read(tableSessionProvider.notifier).fetchLiveVenueInfo(),
                  ]);
                },
              ),

              // 1. Modern Gourmet Header
              SliverToBoxAdapter(
                child: _buildModernHeader(venueTable),
              ),

              // 2. Seated Table Information Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildTableSeatingCard(venueTable),
                ),
              ),

              // 3. Permanent Search Box (Yemeksepeti / Trendyol Yemek standardı)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _buildSearchBar(menuNotifier),
                ),
              ),

              // 4. Horizontal Category Scroll Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCategoryList(menuState, menuNotifier),
                ),
              ),

              // 5. Featured Carousel (Only shown when not searching)
              if (!isSearching && menuState.featuredItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FeaturedCarousel(
                      featuredItems: menuState.featuredItems,
                      onItemTap: (item) => ProductDetailSheet.show(context, item),
                    ),
                  ),
                ),

              // 6. Category Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatCategoryTitle(currentCategoryName),
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Text(
                          '${menuState.filteredItems.length} Çeşit',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Product List
              if (menuState.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (menuState.filteredItems.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Aradığınız lezzet bulunamadı.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Farklı bir arama terimi deneyin veya diğer kategorilere göz atın.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = menuState.filteredItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ProductCard(
                            item: item,
                            onTap: () => ProductDetailSheet.show(context, item),
                            onAddTap: () => _quickAddToCart(item),
                          ),
                        );
                      },
                      childCount: menuState.filteredItems.length,
                    ),
                  ),
                ),
            ],
          ),

          // Floating Cart Bar
          const FloatingCartBar(),
        ],
      ),
    );
  }

  // —— 1. MODERN GOURMET HEADER ——
  Widget _buildModernHeader(dynamic venueTable) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final venueName = (venueTable.venueName.isNotEmpty) ? venueTable.venueName : 'Qordy Menü';
    final cuisineType = (venueTable.cuisineType.isNotEmpty) ? venueTable.cuisineType : 'Menü';

    return Container(
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 8, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Vitrine Dön Butonu
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.go('/welcome');
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Mekan Logosu & Bilgisi
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.6),
            ),
            child: ClipOval(
              child: (venueTable.logoUrl != null && venueTable.logoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: venueTable.logoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        venueName,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        cuisineType,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sağ Butonlar: Şefe Sor & Garson Çağır
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ChefChatSheet.show(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.sparkles, color: AppColors.primary, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    'Şefe Sor',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/service');
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: const Icon(
                Icons.room_service_rounded,
                color: AppColors.textPrimary,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // —— 2. SEATED TABLE INFORMATION CARD ——
  Widget _buildTableSeatingCard(dynamic venueTable) {
    final isSeated = venueTable.isSeated == true;

    if (isSeated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_restaurant_rounded, color: AppColors.emerald, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${venueTable.tableName} (${venueTable.zoneName})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Aktif',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.emerald,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Siparişleriniz masanıza servis edilecektir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Hızlı Eylemler: Garson & Hesap & Wifi
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniActionChip(
                  icon: Icons.room_service_outlined,
                  label: 'Garson',
                  onTap: () => context.push('/service'),
                ),
                const SizedBox(width: 6),
                _buildMiniActionChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Hesap',
                  onTap: () => RequestBillSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        TableQrScannerSheet.show(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masadan Sipariş Ver',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Masadaki QR kodu okutarak anında oturum açın.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— 3. PERMANENT SEARCH BAR ——
  Widget _buildSearchBar(MenuNotifier menuNotifier) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Menüde veya lezzetlerde ara (örn: Burger, Somon)...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (q) {
                menuNotifier.setSearchQuery(q);
                setState(() {});
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                menuNotifier.setSearchQuery('');
                setState(() {});
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.cancel_rounded, color: AppColors.textMuted, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // —— 4. CATEGORY PILLS LIST ——
  Widget _buildCategoryList(MenuState menuState, MenuNotifier menuNotifier) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: menuState.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = menuState.categories[idx];
          final isSelected = menuState.selectedCategoryId == cat.id;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              menuNotifier.selectCategory(cat.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border,
                  width: 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  if (cat.icon != null && cat.icon!.isNotEmpty) ...[
                    Text(cat.icon!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _formatCategoryTitle(cat.name),
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

  String _formatCategoryTitle(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word == '&') return '&';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 18),
      ),
    );
  }
}
