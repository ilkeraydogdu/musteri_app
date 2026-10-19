import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/order_tracking_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../table_service/application/service_request_provider.dart';
import '../../table_service/presentation/request_bill_sheet.dart';
import '../../table_service/presentation/widgets/table_qr_scanner_sheet.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/past_orders_provider.dart';
import '../application/tracking_provider.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(orderTrackingProvider);
    final venueTable = ref.watch(tableSessionProvider);
    final isSeated = venueTable.isSeated;

    if (!tracking.hasActiveOrder) {
      return _buildInactiveState(context, ref, venueTable, isSeated);
    }

    return _buildActiveTrackingState(context, ref, tracking, venueTable);
  }

  // -------------------------------------------------------------
  // INACTIVE / NO ACTIVE ORDER STATE
  // -------------------------------------------------------------
  Widget _buildInactiveState(
    BuildContext context,
    WidgetRef ref,
    dynamic venueTable,
    bool isSeated,
  ) {
    final pastOrdersAsync = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await ref.read(orderTrackingProvider.notifier).fetchOrderStatus();
            ref.invalidate(pastOrdersProvider);
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sipariş & Mutfak Takibi',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (isSeated)
                      GestureDetector(
                        onTap: () => TableQrScannerSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.primary, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                venueTable.tableName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Empty Order Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 0.8),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.flame_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSeated
                            ? '${venueTable.tableName} İçin Aktif Sipariş Bekleniyor'
                            : 'Bekleyen Aktif Siparişiniz Yok',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSeated
                            ? 'Menüden dilediğiniz lezzetleri seçip sipariş verdiğinizde mutfak hazırlık ve servis süreci gerçek zamanlı olarak burada görüntülenecektir.'
                            : 'Masanızdaki QR kodu okutarak veya menüden sipariş vererek canlı mutfak takibini başlatabilirsiniz.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Primary CTA: Menüye Dön
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.go('/menu');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.book_fill, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Menüyü İncele & Sipariş Ver',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Real-Time Sync / QR Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          if (!isSeated) {
                            TableQrScannerSheet.show(context);
                            return;
                          }
                          await ref.read(orderTrackingProvider.notifier).fetchOrderStatus();
                          ref.invalidate(pastOrdersProvider);
                          if (!context.mounted) return;
                          final hasNow = ref.read(orderTrackingProvider).hasActiveOrder;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    hasNow
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.info_circle_fill,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      hasNow
                                          ? 'Masanızdaki aktif sipariş senkronize edildi!'
                                          : 'Masanızda şu an açık sipariş bulunmuyor.',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: hasNow ? AppColors.emerald : AppColors.textPrimary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: Icon(
                          isSeated ? CupertinoIcons.refresh_bold : CupertinoIcons.qrcode_viewfinder,
                          size: 16,
                        ),
                        label: Text(
                          isSeated
                              ? 'Masa Sipariş Durumunu Şimdi Sorgula'
                              : 'Masa QR Kodunu Okut & Bağlan',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Kitchen Process Visual Stepper (How it works)
                Text(
                  'Mutfak Sürecimiz Nasıl İşler?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),

                _buildKitchenStepGuide(
                  stepNum: '1',
                  title: 'Anlık Şef Onayı',
                  desc: 'Siparişiniz doğrudan mutfak istasyonundaki ekrana düşer ve hazırlık başlatılır.',
                  icon: CupertinoIcons.checkmark_seal_fill,
                ),
                const SizedBox(height: 10),
                _buildKitchenStepGuide(
                  stepNum: '2',
                  title: 'Taş Fırın & Artisan Hazırlık',
                  desc: 'Seçtiğiniz ürünler usta şefler ve baristalar tarafından özenle hazırlanır.',
                  icon: CupertinoIcons.flame_fill,
                ),
                const SizedBox(height: 10),
                _buildKitchenStepGuide(
                  stepNum: '3',
                  title: 'Kalite & Sunum Kontrolü',
                  desc: 'Servis öncesi sıcaklık, sunum tepsisi ve garnitür kontrolleri yapılır.',
                  icon: CupertinoIcons.sparkles,
                ),
                const SizedBox(height: 10),
                _buildKitchenStepGuide(
                  stepNum: '4',
                  title: 'Masanıza Özel Servis',
                  desc: 'Garsonumuz sıcak ve taze olarak siparişinizi masanıza ulaştırır.',
                  icon: CupertinoIcons.bell_fill,
                ),
                const SizedBox(height: 24),

                // Past Orders Section
                pastOrdersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geçmiş Siparişleriniz',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final order in orders)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: ShapeDecoration(
                              color: AppColors.surface,
                              shape: ContinuousRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                                side: const BorderSide(color: AppColors.border, width: 0.8),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: AppColors.emerald, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            order.orderNumber,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${order.createdAt}',
                                            style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        order.itemsSummary,
                                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₺${order.totalAmount.toStringAsFixed(0)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ACTIVE TRACKING STATE (Real-Time Order & Item Status)
  // -------------------------------------------------------------
  Widget _buildActiveTrackingState(
    BuildContext context,
    WidgetRef ref,
    OrderTrackingModel tracking,
    dynamic venueTable,
  ) {
    final isDelivered = tracking.currentStatus == OrderStatusStep.delivered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await ref.read(orderTrackingProvider.notifier).fetchOrderStatus();
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Canlı Mutfak Takibi',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tracking.orderNumber.isNotEmpty ? tracking.orderNumber : tracking.orderId,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Countdown / Status Hero Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: AppColors.cardShadow,
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
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.emerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDelivered
                                    ? 'MASANIZA SERVİS EDİLDİ'
                                    : 'CANLI MUTFAK BAĞLANTISI AKTİF',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isDelivered ? AppColors.emerald : AppColors.primary,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              tracking.tableName,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (isDelivered)
                        Row(
                          children: [
                            const Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.emerald, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Afiyet Olsun!',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.textPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Toplam Hesap: ₺${tracking.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${tracking.remainingMinutes}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DAKİKA KALDI',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₺${tracking.totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: tracking.progressPercentage,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDelivered ? AppColors.emerald : AppColors.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Real-time Ordered Items Card (from live API `items`)
                if (tracking.items.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 0.8),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sipariş Kalemleri (${tracking.items.length})',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Toplam: ₺${tracking.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final item in tracking.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(item.preparationStatus).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.statusLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _statusColor(item.preparationStatus),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '₺${(item.price * item.quantity).toStringAsFixed(0)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // Timeline
                Text(
                  'Mutfak İlerleme Durumu',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                ...tracking.steps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value;
                  final isLast = idx == tracking.steps.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: step.isCompleted
                                    ? AppColors.emerald
                                    : (step.isCurrent
                                        ? AppColors.primary.withValues(alpha: 0.2)
                                        : AppColors.surfaceElevated),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (step.isCompleted || step.isCurrent)
                                      ? (step.isCompleted ? AppColors.emerald : AppColors.primary)
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: step.isCompleted
                                    ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 18)
                                    : (step.isCurrent
                                        ? Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: step.isCompleted ? AppColors.emerald : AppColors.border,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      step.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: (step.isCompleted || step.isCurrent)
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                        fontSize: 15,
                                        fontWeight: step.isCurrent ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                    if (step.time != null && step.time!.isNotEmpty)
                                      Text(
                                        step.time!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  step.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Action Buttons Row (Siparişe Ekle, Garson Çağır, Hesap İste)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.border, width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/menu');
                          },
                          child: Text(
                            'Ek Sipariş',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            RequestBillSheet.show(context);
                          },
                          child: Text(
                            'Hesap İste',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(serviceRequestProvider.notifier).sendRequest('Garson Çağrıldı');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text('Garson çağrınız personele iletildi.'),
                                  ],
                                ),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: Text(
                            'Garson Çağır',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String raw) {
    switch (raw.toUpperCase()) {
      case 'SERVED':
      case 'DELIVERED':
        return AppColors.emerald;
      case 'READY':
        return AppColors.gold;
      case 'PREPARING':
      case 'IN_PROGRESS':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildKitchenStepGuide({
    required String stepNum,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
