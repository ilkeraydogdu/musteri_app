import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../cart/application/cart_provider.dart';
import '../../menu/application/menu_provider.dart';
import '../../welcome/application/table_session_provider.dart';

class ChefMascotWheelSheet extends ConsumerStatefulWidget {
  const ChefMascotWheelSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChefMascotWheelSheet(),
    );
  }

  @override
  ConsumerState<ChefMascotWheelSheet> createState() => _ChefMascotWheelSheetState();
}

class _ChefMascotWheelSheetState extends ConsumerState<ChefMascotWheelSheet>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0: Tercihler, 1: Çark & Çevirme, 2: Kazanan Sonuç

  // Tercihler
  String _dietary = 'all'; // all, vegetarian, vegan, gluten_free
  String _categoryPref = 'all'; // all, main, soup_salad, dessert
  final Set<String> _disliked = {};
  bool _withBeverage = true;

  bool _isLoading = false;

  // Çark verileri
  List<Map<String, dynamic>> _wheelItems = [];
  Map<String, dynamic>? _winningItem;
  int _winningIndex = 0;
  Map<String, dynamic>? _suggestedBeverage;
  String _mascotMessage = '';

  // Animasyon
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  double _currentAngle = 0.0;
  double _targetAngle = 0.0;
  int _lastTickSector = -1;

  // Konfeti animasyonu
  late AnimationController _confettiController;
  final List<_ConfettiParticle> _confettiParticles = [];

  final List<Color> _sliceColors = [
    const Color(0xFFEF4444), // Coral Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF10B981), // Emerald
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF14B8A6), // Teal
  ];

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _spinController.addListener(() {
      setState(() {
        _currentAngle = _spinAnimation.value;
      });

      // Haptic tick feedback when crossing sectors
      if (_wheelItems.isNotEmpty) {
        final sectorCount = _wheelItems.length;
        final sliceAngle = (2 * math.pi) / sectorCount;
        final normalized = (_currentAngle % (2 * math.pi));
        final currentSector = (normalized / sliceAngle).floor() % sectorCount;

        if (currentSector != _lastTickSector) {
          _lastTickSector = currentSector;
          HapticFeedback.selectionClick();
          SystemSound.play(SystemSoundType.click);
        }
      }
    });

    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        _startConfetti();
        setState(() {
          _currentStep = 2; // Sonuç ekranına geç
        });
      }
    });

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _confettiController.addListener(() {
      for (final p in _confettiParticles) {
        p.update();
      }
      setState(() {});
    });
  }

  void _startConfetti() {
    _confettiParticles.clear();
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      _confettiParticles.add(_ConfettiParticle(
        x: 150 + random.nextDouble() * 60,
        y: 80 + random.nextDouble() * 40,
        vx: (random.nextDouble() - 0.5) * 12,
        vy: -random.nextDouble() * 8 - 2,
        color: _sliceColors[random.nextInt(_sliceColors.length)],
        size: random.nextDouble() * 8 + 4,
      ));
    }
    _confettiController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchWheelAndStart() async {
    setState(() {
      _isLoading = true;
    });

    final tableSession = ref.read(tableSessionProvider);
    final tenantId = tableSession.lockedTenantId ?? tableSession.venueId;

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.post(ApiConstants.wheelRecommendation, data: {
        'tenant_id': tenantId,
        'dietary': _dietary,
        'disliked_ingredients': _disliked.toList(),
        'category_preference': _categoryPref,
        'with_beverage': _withBeverage,
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final data = res.data;
        final rawItems = (data['wheel_items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (rawItems.isNotEmpty) {
          setState(() {
            _wheelItems = rawItems;
            _winningItem = data['winning_item'] != null
                ? Map<String, dynamic>.from(data['winning_item'] as Map)
                : rawItems.first;
            _winningIndex = data['winning_index'] is int
                ? data['winning_index'] as int
                : 0;
            _suggestedBeverage = data['suggested_beverage'] != null
                ? Map<String, dynamic>.from(data['suggested_beverage'] as Map)
                : null;
            _mascotMessage = data['mascot_message']?.toString() ??
                'Bugün senin için enfes bir lezzet seçtim!';
            _currentStep = 1;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e, st) {
      debugPrint('ChefMascotWheelSheet: Error fetching recommendation: $e\n$st');
    }

    // Fallback: Aktif menüden çark dilimleri oluştur
    _generateFallbackWheel();
  }

  void _generateFallbackWheel() {
    final menuState = ref.read(menuProvider);
    var candidateItems = List<MenuItemModel>.from(menuState.allItems);

    if (candidateItems.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menü ürünleri henüz yüklenemedi. Lütfen menüyü kontrol edin.'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
      return;
    }

    candidateItems.shuffle();
    final count = math.min(8, math.max(4, candidateItems.length));
    _wheelItems = candidateItems.take(count).map((it) {
      return {
        'menu_item_id': it.id,
        'name': it.name,
        'price': it.price,
        'category': 'Menü',
        'image_url': it.imageUrl,
        'description': it.description,
      };
    }).toList();

    final rand = math.Random();
    _winningIndex = rand.nextInt(_wheelItems.length);
    _winningItem = _wheelItems[_winningIndex];
    _mascotMessage = "Harika bir seçim! Çark senin için '${_winningItem!['name']}' dedi. Şimdiden afiyet olsun!";

    setState(() {
      _currentStep = 1;
      _isLoading = false;
    });
  }

  void _spinWheel() {
    if (_spinController.isAnimating) return;

    HapticFeedback.mediumImpact();

    final sectorCount = _wheelItems.length;
    final sliceAngle = (2 * math.pi) / sectorCount;

    final targetSectorCenter = (_winningIndex * sliceAngle) + (sliceAngle / 2);
    final offsetToTop = (1.5 * math.pi) - targetSectorCenter;

    final fullSpins = (6 + math.Random().nextInt(3)) * (2 * math.pi);
    _targetAngle = _currentAngle + fullSpins + (offsetToTop - (_currentAngle % (2 * math.pi)));
    if (_targetAngle <= _currentAngle) {
      _targetAngle += 2 * math.pi * 6;
    }

    _spinAnimation = Tween<double>(
      begin: _currentAngle,
      end: _targetAngle,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    ));

    _spinController.forward(from: 0.0);
  }

  void _addToCartAndClose({bool orderNow = false}) {
    if (_winningItem == null) return;

    final winningId = _winningItem!['menu_item_id']?.toString() ?? '';
    final menuState = ref.read(menuProvider);

    MenuItemModel? matched;
    for (final it in menuState.allItems) {
      if (it.id == winningId || it.name == _winningItem!['name']) {
        matched = it;
        break;
      }
    }

    matched ??= MenuItemModel(
      id: winningId.isNotEmpty ? winningId : 'wheel_win_${DateTime.now().millisecondsSinceEpoch}',
      categoryId: 'wheel',
      name: _winningItem!['name']?.toString() ?? 'Şef Önerisi',
      description: _winningItem!['description']?.toString() ?? 'Şef Qordy çarkından çıktı',
      price: (_winningItem!['price'] is num) ? (_winningItem!['price'] as num).toDouble() : 180.0,
      imageUrl: _winningItem!['image_url']?.toString(),
    );

    ref.read(cartProvider.notifier).addItem(item: matched, quantity: 1);

    if (_suggestedBeverage != null) {
      final bevId = _suggestedBeverage!['menu_item_id']?.toString() ?? '';
      MenuItemModel? matchedBev;
      for (final it in menuState.allItems) {
        if (it.id == bevId || it.name == _suggestedBeverage!['name']) {
          matchedBev = it;
          break;
        }
      }
      matchedBev ??= MenuItemModel(
        id: bevId.isNotEmpty ? bevId : 'wheel_bev_${DateTime.now().millisecondsSinceEpoch}',
        categoryId: 'beverage',
        name: _suggestedBeverage!['name']?.toString() ?? 'İçecek',
        description: 'Şef Qordy eşlikçi içeceği',
        price: (_suggestedBeverage!['price'] is num) ? (_suggestedBeverage!['price'] as num).toDouble() : 45.0,
      );
      ref.read(cartProvider.notifier).addItem(item: matchedBev, quantity: 1);
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${matched.name} sepete eklendi! 🎉',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Ana İçerik
          Column(
            children: [
              // Üst Sürükleme Çubuğu & Başlık
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        // Şef Maskotu Rozeti
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFB8500).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('👨‍🍳', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Şef Qordy Çarkıfeleği',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Bugün ne yiyeceğine yapay zeka şef karar versin!',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Dinamik Adımlar
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircularProgressIndicator(color: AppColors.cyan),
                            Gap(16),
                            Text(
                              'Şef Qordy restoran menüsünü inceliyor...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentStep == 0
                            ? _buildPreferencesStep()
                            : _currentStep == 1
                                ? _buildWheelStep()
                                : _buildWinnerStep(),
                      ),
              ),
            ],
          ),

          // Konfeti parçacıkları katmanı
          if (_confettiParticles.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(particles: _confettiParticles),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ADIM 1: Tercihler & Sorular
  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_0'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Şef Konuşma Baloncuğu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
                  AppColors.primary.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('💬', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selam gurme dostum! Kararsız kaldığını duydum. Bana 2 saniyede damak zevkini söyle, çarkı işletmenin enfes lezzetleriyle doldurayım!',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // 1. Beslenme Tercihi
          const Text(
            'ÖZEL BESLENME TERCİHİN VAR MI?',
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip('Her Şey Serbest', 'all', _dietary, (val) => setState(() => _dietary = val)),
              _buildChoiceChip('🌱 Vejetaryen', 'vegetarian', _dietary, (val) => setState(() => _dietary = val)),
              _buildChoiceChip('🌿 Vegan', 'vegan', _dietary, (val) => setState(() => _dietary = val)),
              _buildChoiceChip('🌾 Glütensiz', 'gluten_free', _dietary, (val) => setState(() => _dietary = val)),
            ],
          ),
          const Gap(20),

          // 2. Kategori Tercihi
          const Text(
            'HANGİ TÜRDE BİR LEZZET ARARSIN?',
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip('Fark Etmez', 'all', _categoryPref, (val) => setState(() => _categoryPref = val)),
              _buildChoiceChip('🥩 Doyurucu Ana Yemek', 'main', _categoryPref, (val) => setState(() => _categoryPref = val)),
              _buildChoiceChip('🍲 Çorba & Hafif Salata', 'soup_salad', _categoryPref, (val) => setState(() => _categoryPref = val)),
              _buildChoiceChip('🍰 Tatlı & Kaçamak', 'dessert', _categoryPref, (val) => setState(() => _categoryPref = val)),
            ],
          ),
          const Gap(20),

          // 3. Sevilmeyen / Alerjen Malzemeler
          const Text(
            'ÇIKARMAK İSTEDİĞİN VEYA SEVMEDİĞİN MALZEMELER',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Soğan', 'Sarımsak', 'Mantar', 'Fıstık', 'Acı Biber', 'Peynir'].map((ing) {
              final isSelected = _disliked.contains(ing.toLowerCase());
              return FilterChip(
                label: Text(
                  isSelected ? '❌ $ing' : ing,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.red.withValues(alpha: 0.3),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                  color: isSelected ? Colors.red : AppColors.borderLight,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _disliked.add(ing.toLowerCase());
                    } else {
                      _disliked.remove(ing.toLowerCase());
                    }
                  });
                },
              );
            }).toList(),
          ),
          const Gap(20),

          // 4. İçecek Eşleşmesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Text('🥤', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Text(
                      'Yanına uyumlu bir içecek öner',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Switch(
                  value: _withBeverage,
                  activeThumbColor: AppColors.cyan,
                  onChanged: (v) => setState(() => _withBeverage = v),
                ),
              ],
            ),
          ),
          const Gap(26),

          // Çarkı Hazırla Butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.casino_rounded, size: 20),
              label: const Text(
                'Çarkı Hazırla & Çevir!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _fetchWheelAndStart,
            ),
          ),
          const Gap(20),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String title, String value, String current, Function(String) onSelect) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      side: BorderSide(
        color: isSelected ? AppColors.cyan : AppColors.borderLight,
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  // ADIM 2: Çarkıfelek & Çevirme
  Widget _buildWheelStep() {
    return Column(
      key: const ValueKey('step_1'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(10),
        // Bilgilendirme
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded, color: AppColors.cyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Çarkı çevir butonuna bas ve talihi bekle!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const Gap(20),

        // ÇARK KANVASI (CustomPainter)
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dönen Çark
                  Transform.rotate(
                    angle: _currentAngle,
                    child: CustomPaint(
                      size: const Size(290, 290),
                      painter: _WheelPainter(
                        items: _wheelItems,
                        colors: _sliceColors,
                      ),
                    ),
                  ),

                  // Orta Göbek (Chef Qordy Hub)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                      border: Border.all(color: const Color(0xFFFFB703), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('👨‍🍳', style: TextStyle(fontSize: 26)),
                    ),
                  ),

                  // Üst İbre (Pointer Arrow - 12 Yönü)
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(28, 36),
                      painter: _PointerArrowPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const Gap(16),

        // Çevir Butonu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFB8500).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 24),
                label: Text(
                  _spinController.isAnimating ? 'Şansın Dönüyor...' : 'ŞİMDİ ÇARKİ ÇEVİR! 🎯',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onPressed: _spinController.isAnimating ? null : _spinWheel,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ADIM 3: Kazanan Sonuç & Aksiyonlar
  Widget _buildWinnerStep() {
    if (_winningItem == null) return const SizedBox.shrink();

    final item = _winningItem!;
    final name = item['name']?.toString() ?? 'Özel Yemek';
    final price = item['price'] is num ? (item['price'] as num).toDouble() : 0.0;
    final category = item['category']?.toString() ?? 'Menü';
    final imageUrl = item['image_url']?.toString();
    final description = item['description']?.toString() ?? '';

    return SingleChildScrollView(
      key: const ValueKey('step_2'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Şef Tebrik Balonu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFB703), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ŞEF QORDY TAVSİYESİ!',
                        style: TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mascotMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // Kazanan Yemek Kartı
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Yemek Resmi
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.restaurant, color: Colors.white38, size: 48),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant_rounded, color: AppColors.cyan, size: 48),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '₺${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFFFB703),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Eşlikçi İçecek Kutucuğu
                      if (_suggestedBeverage != null) ...[
                        const Gap(14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Text('🥤', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ŞEFİN İÇECEK ÖNERİSİ',
                                      style: TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      _suggestedBeverage!['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₺${(_suggestedBeverage!['price'] as num?)?.toStringAsFixed(2) ?? '40.00'}',
                                style: const TextStyle(
                                  color: Color(0xFFFFB703),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
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
          const Gap(20),

          // Sepete Ekle Butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text(
                _suggestedBeverage != null
                    ? 'Yemek ve İçeceği Sepete Ekle'
                    : 'Lezzeti Sepete Ekle',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _addToCartAndClose(orderNow: false),
            ),
          ),
          const Gap(10),

          // Tekrar Çevir Butonu
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Farklı Bir Şey İstiyorum (Tekrar Çevir)'),
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
            ),
          ),
          const Gap(20),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// ÇARKİFELEK ÇİZİCİ (CustomPainter)
// -------------------------------------------------------------
class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final List<Color> colors;

  _WheelPainter({required this.items, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = (2 * math.pi) / items.length;

    final slicePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF0F172A);

    final outerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = const Color(0xFFFFB703);

    for (int i = 0; i < items.length; i++) {
      final startAngle = i * sliceAngle;
      slicePaint.color = colors[i % colors.length];

      // Dilim çiz
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        slicePaint,
      );

      // Dilim sınır çizgisi
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        borderPaint,
      );

      // Dilim içi metin (Yemek adı)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sliceAngle / 2);

      final text = items[i]['name']?.toString() ?? '';
      final textSpan = TextSpan(
        text: text.length > 14 ? '${text.substring(0, 12)}..' : text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: radius * 0.65);

      textPainter.paint(
        canvas,
        Offset(radius * 0.28, -textPainter.height / 2),
      );

      canvas.restore();
    }

    // Dış altın çerçeve
    canvas.drawCircle(center, radius, outerRimPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.items != items;
}

// -------------------------------------------------------------
// ÇARK İBRESİ (Pointer Arrow Painter)
// -------------------------------------------------------------
class _PointerArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    final fillPaint = Paint()
      ..color = const Color(0xFFFFB703)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// KONFETİ PARÇACIK MODELİ & ÇİZİCİ
// -------------------------------------------------------------
class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double rotation = 0;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.35;
    rotation += 0.1;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.7),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
