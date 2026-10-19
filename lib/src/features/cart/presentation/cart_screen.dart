import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../menu/application/menu_provider.dart';
import '../../table_service/presentation/widgets/table_qr_scanner_sheet.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/cart_provider.dart';
import 'widgets/order_confirmation_sheet.dart';

/// Trendyol Yemek & Getir Yemek standardında modern sepet ve sipariş onay ekranı.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final table = ref.watch(tableSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: cart.items.isEmpty
            ? _buildEmptyState(context, cartNotifier)
            : Column(
                children: [
                  // Top Header
                  _buildHeader(context, table, cartNotifier),

                  // Cart Content (Scrollable items + cross-sell + note)
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        // Seated table info banner
                        _buildTableBanner(context, table),
                        const SizedBox(height: 14),

                        // Section Title: Seçilen Lezzetler
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Seçilen Lezzetler',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${cart.totalItemCount} Adet',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Items
                        for (final item in cart.items) ...[
                          _buildCartItemCard(item, cartNotifier),
                          const SizedBox(height: 10),
                        ],

                        const SizedBox(height: 14),

                        // Cross-sell recommendations
                        _buildCrossSellSection(cartNotifier),
                        const SizedBox(height: 16),

                        // Kitchen Note
                        _buildKitchenNoteField(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // Bottom Summary & Order CTA
                  _buildBottomCheckoutBar(context, cart, cartNotifier, table),
                ],
              ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TOP HEADER
  // -------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    dynamic table,
    CartNotifier cartNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sipariş Sepetim',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: AppColors.coral,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('Sepeti Temizle'),
                  content: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Sepetinizdeki tüm lezzetler kaldırılacaktır. Emin misiniz?',
                    ),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Vazgeç'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        cartNotifier.clearCart();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Evet, Temizle'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(CupertinoIcons.trash, size: 16),
            label: Text(
              'Temizle',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TABLE BANNER
  // -------------------------------------------------------------
  Widget _buildTableBanner(BuildContext context, dynamic table) {
    final isSeated = table.isSeated == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSeated ? AppColors.emerald.withValues(alpha: 0.35) : AppColors.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isSeated ? AppColors.emerald.withValues(alpha: 0.12) : AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSeated ? Icons.table_restaurant_rounded : Icons.qr_code_scanner_rounded,
              color: isSeated ? AppColors.emerald : AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSeated ? '${table.tableName} • ${table.zoneName}' : 'Masa Oturumu Başlatılmadı',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isSeated
                      ? 'Siparişleriniz doğrudan masanıza servis edilecektir'
                      : 'Sipariş vermek için masanızdaki QR kodu okutun',
                  style: GoogleFonts.plusJakartaSans(
                    color: isSeated ? AppColors.emerald : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              color: isSeated ? AppColors.emerald : AppColors.primary,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              TableQrScannerSheet.show(context);
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CART ITEM CARD
  // -------------------------------------------------------------
  Widget _buildCartItemCard(dynamic item, CartNotifier cartNotifier) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 74,
              height: 74,
              child: item.menuItem.imageUrl != null && item.menuItem.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.menuItem.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.surfaceLight),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.restaurant, color: AppColors.textMuted),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(Icons.restaurant, color: AppColors.textMuted),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.menuItem.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        cartNotifier.removeItem(item.id);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                      ),
                    ),
                  ],
                ),

                if (item.summaryText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.summaryText,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₺${item.totalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    // Stepper (- count +)
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            iconSize: 13,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: const Icon(Icons.remove, color: AppColors.primary),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              cartNotifier.decrement(item.id);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${item.quantity}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: 13,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              cartNotifier.increment(item.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CROSS-SELL CAROUSEL ("Birlikte Harika Gider")
  // -------------------------------------------------------------
  Widget _buildCrossSellSection(CartNotifier cartNotifier) {
    final menuState = ref.watch(menuProvider);
    final cartIds = ref.watch(cartProvider).items.map((e) => e.menuItem.id).toSet();
    final crossSellItems = menuState.allItems
        .where((i) => !cartIds.contains(i.id))
        .take(5)
        .toList();

    if (crossSellItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.sparkles, color: AppColors.primary, size: 16),
            const SizedBox(width: 7),
            Text(
              'Birlikte Harika Gider',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: crossSellItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = crossSellItems[index];
              return Container(
                width: 250,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 66,
                        height: 66,
                        child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: AppColors.surfaceLight),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceLight,
                                  child: const Icon(CupertinoIcons.sparkles, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceLight,
                                child: const Icon(CupertinoIcons.sparkles, color: AppColors.textMuted),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₺${product.price.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              cartNotifier.addItem(item: product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.name} sepete eklendi!'),
                                  backgroundColor: AppColors.primary,
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.plus, color: AppColors.primary, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Ekle',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // KITCHEN NOTE FIELD
  // -------------------------------------------------------------
  Widget _buildKitchenNoteField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 7),
              Text(
                'Şefe Özel Not (İsteğe Bağlı)',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Örn: Soslar ayrı kapta gelsin, burger orta pişmiş olsun...',
              hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // BOTTOM CHECKOUT BAR
  // -------------------------------------------------------------
  Widget _buildBottomCheckoutBar(
    BuildContext context,
    dynamic cart,
    CartNotifier cartNotifier,
    dynamic table,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coupon tag (if applied)
          if (cart.appliedCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.emerald, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${cart.appliedCoupon!.code} • ${cart.appliedCoupon!.badgeText} aktif',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => cartNotifier.removeCoupon(),
                    child: const Icon(CupertinoIcons.xmark, color: AppColors.textMuted, size: 14),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => context.push('/coupons'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.tag_fill, color: AppColors.primary, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'İndirim Kuponu veya Kampanya Kullan',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(CupertinoIcons.chevron_right, color: AppColors.textMuted, size: 12),
                  ],
                ),
              ),
            ),

          // Compact Price Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Genel Toplam',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₺${cart.grandTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),

              // Submit CTA Button
              SizedBox(
                width: 210,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: cart.isSubmitting
                        ? null
                        : () async {
                            HapticFeedback.heavyImpact();
                            final success = await cartNotifier.sendOrder(
                              customerNote: _noteController.text.trim(),
                            );
                            if (!context.mounted) return;
                            if (!success) {
                              final err = ref.read(cartProvider).errorMessage ?? 'Sipariş gönderilemedi.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err), backgroundColor: AppColors.coral),
                              );
                              return;
                            }
                            if (success) {
                              final realOrderNo = ref.read(cartProvider).lastOrderNumber ?? '#SIP';
                              await OrderConfirmationSheet.show(
                                context,
                                orderNo: realOrderNo,
                                estMinutes: '15 Dakika',
                              );
                              if (context.mounted) {
                                context.go('/tracking');
                              }
                            }
                          },
                    child: cart.isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 17),
                              const SizedBox(width: 6),
                              Text(
                                'Siparişi Onayla',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // EMPTY STATE WITH CHEF PICKS
  // -------------------------------------------------------------
  Widget _buildEmptyState(BuildContext context, CartNotifier cartNotifier) {
    final menuState = ref.watch(menuProvider);
    final topPicks = (menuState.featuredItems.isNotEmpty
            ? menuState.featuredItems
            : menuState.allItems)
        .take(3)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sepetiniz Şu An Boş',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Masanıza sipariş vermek için menümüzdeki gurme lezzetleri keşfedin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Menüye Dön CTA
          SizedBox(
            width: double.infinity,
            height: 46,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go('/menu');
                },
                child: Text(
                  'Menüyü İncele',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // En Çok Tercih Edilenler
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Şefin Tavsiyeleri',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...topPicks.map((pick) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CachedNetworkImage(
                          imageUrl: pick.imageUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.surfaceLight),
                          errorWidget: (_, _, _) => Container(color: AppColors.surfaceLight),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pick.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₺${pick.price.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        cartNotifier.addItem(item: pick);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${pick.name} sepete eklendi!'),
                            backgroundColor: AppColors.primary,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: Text(
                        '+ Ekle',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
