import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/customer_auth_provider.dart';
import '../../cart/application/cart_provider.dart';
import '../../tracking/application/past_orders_provider.dart';
import '../../welcome/application/table_session_provider.dart';
import '../../wheel/presentation/chef_mascot_wheel_sheet.dart';

final couponsProvider = FutureProvider.autoDispose<List<CouponModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final session = ref.watch(tableSessionProvider);

  try {
    final query = <String, dynamic>{};
    final tenantId = session.lockedTenantId ?? session.venueId;
    if (tenantId.isNotEmpty) {
      query['tenant_id'] = tenantId;
    }

    final res = await apiClient.get(ApiConstants.getCoupons, queryParameters: query);
    if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
      final raw = res.data['campaigns'] as List<dynamic>? ?? [];
      final list = raw.map((c) => CouponModel.fromJson(c as Map<String, dynamic>)).toList();
      for (final vc in session.campaigns) {
        final code = vc.id.toUpperCase();
        if (!list.any((c) => c.code == code || c.title == vc.title)) {
          list.add(
            CouponModel(
              code: code.isNotEmpty ? code : 'KAMPANYA',
              title: vc.title,
              description: vc.description,
              discountValue: vc.discountValue,
              discountType: vc.discountType,
              validUntil: 'Aktif Kampanya',
            ),
          );
        }
      }
      if (list.isNotEmpty) return list;
    }
  } catch (e) {
    debugPrint('couponsProvider fetch error: $e');
  }

  // Gourmet Curated Fallback Vouchers for Bistro & Lounge
  return const [
    CouponModel(
      code: 'GURME20',
      title: '%20 Gurme Lezzet İndirimi',
      description: 'Tüm Burger & Taş Fırın Pizza lezzetlerinde geçerli özel masaya indirim.',
      discountValue: 20.0,
      discountType: 'percentage',
      validUntil: 'Bu Akşam Geçerli',
      minSpend: 250.0,
    ),
    CouponModel(
      code: 'KAHVEHEDIYE',
      title: '50₺ Kahve İkram Çeki',
      description: 'Günün taze tatlı veya kruvasan seçiminizin yanına 3. nesil demleme kahve indirimi.',
      discountValue: 50.0,
      discountType: 'fixed',
      validUntil: 'Tüm Gün',
      minSpend: 200.0,
    ),
    CouponModel(
      code: 'SEF15',
      title: '%15 Şefin İmzası İndirimi',
      description: 'Truffle Angus Burger ve Dry Aged Ribeye siparişlerinde şefin masanıza özel ikramı.',
      discountValue: 15.0,
      discountType: 'percentage',
      validUntil: 'Masa Oturumuna Özel',
      minSpend: 300.0,
    ),
    CouponModel(
      code: 'VIPTERAS',
      title: '%10 Teras Lounge Ayrıcalığı',
      description: 'Teras katında gün boyu tüm gurme kaseler ve içeceklerde geçerlidir.',
      discountValue: 10.0,
      discountType: 'percentage',
      validUntil: 'Aktif Oturum',
      minSpend: 150.0,
    ),
  ];
});

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  String? _validationError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndApplyCoupon(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      setState(() => _validationError = 'Lütfen bir kupon kodu girin.');
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final apiClient = ref.read(apiClientProvider);
    final session = ref.read(tableSessionProvider);
    final cart = ref.read(cartProvider);

    try {
      final res = await apiClient.post(ApiConstants.validateCoupon, data: {
        'code': trimmed,
        'cart_total': cart.subtotal,
        'tenant_id': session.lockedTenantId ?? session.venueId,
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final data = res.data;
        final coupon = CouponModel(
          code: trimmed,
          title: data['title']?.toString() ?? trimmed,
          description: data['message']?.toString() ?? 'Kupon başarıyla uygulandı',
          discountValue: (data['discount_value'] as num?)?.toDouble() ?? 15.0,
          discountType: data['discount_type']?.toString() ?? 'percentage',
          validUntil: 'Aktif',
        );

        ref.read(cartProvider.notifier).applyCoupon(coupon);
        _codeController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$trimmed kuponu başarıyla uygulandı!'),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    // Fallback validation for preset codes
    CouponModel? matched;
    if (trimmed == 'GURME20') {
      matched = const CouponModel(
        code: 'GURME20',
        title: '%20 Gurme Lezzet İndirimi',
        description: 'Tüm Burger & Taş Fırın lezzetlerinde geçerli indirim.',
        discountValue: 20.0,
        discountType: 'percentage',
        validUntil: 'Bugün',
      );
    } else if (trimmed == 'KAHVEHEDIYE') {
      matched = const CouponModel(
        code: 'KAHVEHEDIYE',
        title: '50₺ Kahve İkram Çeki',
        description: 'Özel kahve indirimi.',
        discountValue: 50.0,
        discountType: 'fixed',
        validUntil: 'Bugün',
      );
    } else if (trimmed == 'SEF15') {
      matched = const CouponModel(
        code: 'SEF15',
        title: '%15 Şefin İmzası İndirimi',
        description: 'İmza lezzetlerde masanıza özel avantaj.',
        discountValue: 15.0,
        discountType: 'percentage',
        validUntil: 'Bugün',
      );
    }

    if (matched != null) {
      ref.read(cartProvider.notifier).applyCoupon(matched);
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$trimmed kuponu başarıyla uygulandı!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      setState(() => _validationError = 'Geçersiz kupon kodu. Lütfen kontrol ediniz.');
    }

    if (mounted) {
      setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(couponsProvider);
    final activeCoupon = ref.watch(cartProvider.select((s) => s.appliedCoupon));
    final userState = ref.watch(customerAuthProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Kuponlar & Ayrıcalıklar',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Masa siparişinizde anında kullanabileceğiniz gurme indirimler.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // QORDY Club VIP Loyalty Card
              _buildLoyaltyCard(userState),
              const SizedBox(height: 18),

              // Şans Çarkıfeleği Banner
              _buildWheelBanner(context),
              const SizedBox(height: 20),

              // Manual Code Input Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.confirmation_num_outlined, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Promosyon Kodu Girin',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Örn: GURME20, SEF15',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                                letterSpacing: 0,
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                            onSubmitted: (val) => _validateAndApplyCoupon(val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isValidating
                              ? null
                              : () => _validateAndApplyCoupon(_codeController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isValidating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Uygula',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    if (_validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validationError!,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.coral, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Active Coupon Banner (if applied)
              if (activeCoupon != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${activeCoupon.code} Sepetinize Uygulandı',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeCoupon.discountBadge} sepet toplamından düşülecektir.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.emerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                        onPressed: () {
                          ref.read(cartProvider.notifier).removeCoupon();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kupon sepetten kaldırıldı.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Campaigns List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aktif Kampanyalar',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  couponsAsync.maybeWhen(
                    data: (c) => Text(
                      '${c.length} Fırsat',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              couponsAsync.when(
                data: (coupons) {
                  return Column(
                    children: [
                      for (final coupon in coupons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildCouponCard(context, ref, coupon, activeCoupon),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // QORDY CLUB VIP LOYALTY CARD
  // -------------------------------------------------------------
  Widget _buildLoyaltyCard(CustomerUserState userState) {
    final ordersAsync = ref.watch(pastOrdersProvider);
    final pastOrderPts = ordersAsync.maybeWhen(
      data: (orders) => orders.fold<int>(
        0,
        (sum, o) => sum + (o.totalAmount * 0.05).round(),
      ),
      orElse: () => 0,
    );
    final points = userState.loyaltyPoints > 0
        ? userState.loyaltyPoints
        : (pastOrderPts > 0 ? pastOrderPts : 120);
    final nextRewardPoints = ((points ~/ 300) + 1) * 300;
    final progress = (points % 300) / 300.0;
    final remainingPoints = nextRewardPoints - points;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'QORDY VIP CLUB',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'GOLD GURME',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$points',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Gurme Puan',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress.clamp(0.05, 1.0),
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ücretsiz Tatlı için $remainingPoints puan kaldı',
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'San Sebastian = 300 P',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ŞEFİN ÇARKI BANNER
  // -------------------------------------------------------------
  Widget _buildWheelBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.casino_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne Yesem? Şefin Çarkıfeleği',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kararsız mısınız? Çarkı çevirin, günün sürpriz lezzetini keşfedin.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ChefMascotWheelSheet.show(context);
            },
            child: Text(
              'Çevir',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TICKET COUPON CARD
  // -------------------------------------------------------------
  Widget _buildCouponCard(
    BuildContext context,
    WidgetRef ref,
    CouponModel coupon,
    CouponModel? activeCoupon,
  ) {
    final isApplied = activeCoupon != null && activeCoupon.code == coupon.code;
    final discountBadge = coupon.discountType == 'percentage'
        ? '%${coupon.discountPercent.toStringAsFixed(0)} İNDİRİM'
        : '₺${coupon.discountValue.toStringAsFixed(0)} İNDİRİM';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApplied ? AppColors.emerald : AppColors.border,
          width: isApplied ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol kupon rozeti
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: const Center(
                      child: Icon(Icons.percent_rounded, color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Başlık ve Açıklama
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                coupon.title,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                discountBadge,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (coupon.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            coupon.description,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dashed Divider Separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(
                  28,
                  (index) => Expanded(
                    child: Container(
                      color: index % 2 == 0 ? AppColors.border : Colors.transparent,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Kupon Kodu & Kopyala
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: coupon.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${coupon.code} kopyalandı!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'KOD: ${coupon.code}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Kullan / Kaldır Butonu
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApplied ? AppColors.surface : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isApplied ? AppColors.emerald : Colors.transparent,
                        ),
                      ),
                      elevation: isApplied ? 0 : 2,
                    ),
                    onPressed: () {
                      if (isApplied) {
                        ref.read(cartProvider.notifier).removeCoupon();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kupon kaldırıldı.')),
                        );
                      } else {
                        ref.read(cartProvider.notifier).applyCoupon(coupon);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${coupon.code} kuponu uygulandı!'),
                            backgroundColor: AppColors.emerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        context.go('/cart');
                      }
                    },
                    child: Text(
                      isApplied ? 'Uygulandı ✓' : 'Kullan',
                      style: GoogleFonts.plusJakartaSans(
                        color: isApplied ? AppColors.emerald : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
