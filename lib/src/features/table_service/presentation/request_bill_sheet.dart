import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../cart/application/cart_provider.dart';
import '../../tracking/application/tracking_provider.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/service_request_provider.dart';
import 'review_dialog.dart';

class RequestBillSheet extends ConsumerStatefulWidget {
  const RequestBillSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RequestBillSheet(),
    );
  }

  @override
  ConsumerState<RequestBillSheet> createState() => _RequestBillSheetState();
}

class _RequestBillSheetState extends ConsumerState<RequestBillSheet> {
  int _selectedTipPercent = 0;
  int _splitPersonCount = 1;
  String _selectedPaymentMethod = 'Kredi Kartı';

  @override
  void initState() {
    super.initState();
    final guests = ref.read(tableSessionProvider).guestCount;
    _splitPersonCount = guests.clamp(1, 12);
  }

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(tableSessionProvider);
    final cart = ref.watch(cartProvider);
    final tracking = ref.watch(orderTrackingProvider);
    final serviceNotifier = ref.read(serviceRequestProvider.notifier);

    final double trackedTotal = tracking.hasActiveOrder ? tracking.totalAmount : 0.0;
    final double baseAmount = trackedTotal + cart.subtotal;
    final double discount = cart.discountAmount;
    final double netAmount = (baseAmount - discount) > 0 ? (baseAmount - discount) : 0.0;
    final double includedVat = netAmount - (netAmount / 1.10);
    final double tipAmount = netAmount * (_selectedTipPercent / 100.0);
    final double grandTotal = netAmount + tipAmount;
    final double perPerson = _splitPersonCount > 0 ? (grandTotal / _splitPersonCount) : grandTotal;
    final hasAnyItems = tracking.items.isNotEmpty || cart.items.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 0.8),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hesabınız',
                          style: AppTypography.headingLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${table.venueName} · ${table.tableName.isNotEmpty ? table.tableName : "Masa Seçilmedi"}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.textMuted, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: ShapeDecoration(
                    color: AppColors.surface,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                      side: const BorderSide(color: AppColors.border, width: 0.8),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sipariş Özeti',
                            style: AppTypography.titleCard,
                          ),
                          if (tracking.orderNumber.isNotEmpty)
                            Text(
                              tracking.orderNumber,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (hasAnyItems) ...[
                        ...tracking.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity} × ${item.name}',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    '₺${item.totalPrice.toStringAsFixed(2)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        ...cart.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity} × ${item.menuItem.name} (Sepette)',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    '₺${item.totalPrice.toStringAsFixed(2)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Masanızda henüz onaylanmış bir sipariş kalemi bulunmuyor.',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ),

                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, thickness: 0.8),
                      const SizedBox(height: 8),

                      _buildBreakdownRow('Sipariş Tutarı', '₺${baseAmount.toStringAsFixed(2)}'),
                      if (discount > 0)
                        _buildBreakdownRow(
                          'Kupon İndirimi',
                          '-₺${discount.toStringAsFixed(2)}',
                          isDiscount: true,
                        ),
                      if (netAmount > 0)
                        _buildBreakdownRow('Dahil KDV (%10)', '₺${includedVat.toStringAsFixed(2)}'),
                      if (tipAmount > 0)
                        _buildBreakdownRow('Bahşiş (%$_selectedTipPercent)', '₺${tipAmount.toStringAsFixed(2)}'),

                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, thickness: 0.8),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Genel Toplam', style: AppTypography.headingSmall),
                          Text('₺${grandTotal.toStringAsFixed(2)}', style: AppTypography.priceLarge),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tip Selection (%0, %5, %10, %15)
                Row(
                  children: [
                    const Icon(CupertinoIcons.heart_fill, color: AppColors.error, size: 16),
                    const SizedBox(width: 6),
                    Text('Bahşiş Tercihi', style: AppTypography.titleCard),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [0, 5, 10, 15].map((percent) {
                    final isSelected = _selectedTipPercent == percent;
                    final tipVal = netAmount * (percent / 100.0);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: percent == 15 ? 0 : 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTipPercent = percent);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: 0.8,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              percent == 0 ? 'Yok' : '%$percent (₺${tipVal.toStringAsFixed(0)})',
                              style: isSelected
                                  ? AppTypography.buttonMedium.copyWith(fontSize: 11.5, color: Colors.white)
                                  : AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

            // Ödeme Yöntemi Seçimi
            Text(
              'Ödeme Yöntemi',
              style: AppTypography.headingSmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Kredi Kartı', 'Nakit', 'Yemek Kartı'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPaymentMethod = method);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          method,
                          style: isSelected
                              ? AppTypography.buttonMedium.copyWith(fontSize: 12, color: Colors.white)
                              : AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Split Bill Card (Hesabı Böl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hesabı Böl ($_splitPersonCount Kişi)',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kişi başı: ₺${perPerson.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (_splitPersonCount > 1) {
                              HapticFeedback.lightImpact();
                              setState(() => _splitPersonCount--);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.remove_rounded, color: AppColors.textMuted, size: 16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$_splitPersonCount',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (_splitPersonCount < 12) {
                              HapticFeedback.lightImpact();
                              setState(() => _splitPersonCount++);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary Button: Hesabı Öde & Kapat
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    final ok = await serviceNotifier.requestBill(
                      paymentMethod: _selectedPaymentMethod,
                      tipPercent: _selectedTipPercent.toDouble(),
                      tipAmount: tipAmount,
                      totalAmount: grandTotal,
                    );
                    if (context.mounted) {
                      final current = ref.read(serviceRequestProvider);
                      Navigator.pop(context);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    current.successMessage ?? 'Hesap talebiniz garsona iletildi.',
                                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.textPrimary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(current.errorMessage ?? 'Hesap talebi iletilemedi.'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      }
                    }
                  },
                  child: Text('Hesabı Öde & Kapat', style: AppTypography.buttonLarge),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rate experience
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  ReviewDialog.show(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Deneyiminizi puanlayın: ', style: AppTypography.caption),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: isDiscount ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
