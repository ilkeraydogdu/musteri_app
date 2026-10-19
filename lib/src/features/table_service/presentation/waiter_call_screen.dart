import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../welcome/application/table_session_provider.dart';
import '../application/service_request_provider.dart';
import 'request_bill_sheet.dart';
import 'review_dialog.dart';
import 'widgets/table_qr_scanner_sheet.dart';
import 'wifi_connect_sheet.dart';

class WaiterCallScreen extends ConsumerWidget {
  const WaiterCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(tableSessionProvider);
    final serviceState = ref.watch(serviceRequestProvider);
    final serviceNotifier = ref.read(serviceRequestProvider.notifier);
    final canPop = Navigator.of(context).canPop();
    final waiterName = (serviceState.assignedWaiter != null && serviceState.assignedWaiter!.isNotEmpty)
        ? serviceState.assignedWaiter!
        : (table.assignedWaiter.isNotEmpty ? table.assignedWaiter : 'Masa Sorumlusu');

    final serviceItems = [
      {
        'title': 'Garson Çağır',
        'icon': '🙋',
        'action': () => serviceNotifier.sendRequest('Garson Çağrıldı'),
      },
      {
        'title': 'Su İste',
        'icon': '💧',
        'action': () => serviceNotifier.sendRequest('Su İstendi'),
      },
      {
        'title': 'Ek Malzeme İste',
        'icon': '🧂',
        'action': () => serviceNotifier.sendRequest('Ek Malzeme / Sos İstendi'),
      },
      {
        'title': 'Peçete İste',
        'icon': '🧻',
        'action': () => serviceNotifier.sendRequest('Peçete / Islak Mendil İstendi'),
      },
      {
        'title': 'Hesap İste',
        'icon': '📋',
        'action': () => RequestBillSheet.show(context),
      },
      {
        'title': 'Masa Temizliği',
        'icon': '🧹',
        'action': () => serviceNotifier.sendRequest('Masa Temizliği İstendi'),
      },
    ];

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (canPop) ...[
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 0.8),
                              ),
                              child: const Icon(
                                CupertinoIcons.chevron_back,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Servis Talebi',
                                style: AppTypography.headingLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${table.venueName} · ${table.isSeated && table.tableName.isNotEmpty ? table.tableName : "Masa Seçilmedi"}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          WifiConnectSheet.show(context);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: const Icon(CupertinoIcons.wifi, color: AppColors.primary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ReviewDialog.show(context);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: const Icon(CupertinoIcons.star_fill, color: AppColors.warning, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!table.isSeated) ...[
                GestureDetector(
                  onTap: () => TableQrScannerSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.qrcode_viewfinder, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Masaya Oturulmadı',
                                style: AppTypography.titleCard.copyWith(fontSize: 13, color: AppColors.primary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Garson çağırmak için masanızdaki QR kodu okutun.',
                                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'QR Okut',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 6 Service Request Cards in 2-column Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: serviceItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final item = serviceItems[index];
                  final isLastSent = serviceState.lastRequestTitle != null &&
                      serviceState.lastRequestTitle!.contains(item['title'] as String);

                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (serviceState.isSubmitting) return;
                      final fn = item['action'] as Function;
                      final dynamic ok = await fn();
                      if (context.mounted && item['title'] != 'Hesap İste') {
                        final current = ref.read(serviceRequestProvider);
                        if (ok == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      current.successMessage ?? '${item['title']} talebiniz iletildi.',
                                      style: AppTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.textPrimary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } else if (current.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(current.errorMessage!),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              action: !table.isSeated
                                  ? SnackBarAction(
                                      label: 'QR OKUT',
                                      textColor: Colors.white,
                                      onPressed: () => TableQrScannerSheet.show(context),
                                    )
                                  : null,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLastSent ? AppColors.primary : AppColors.border,
                          width: isLastSent ? 1.4 : 0.8,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isLastSent ? AppColors.primaryLight : AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              item['icon'] as String,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          Text(
                            item['title'] as String,
                            style: AppTypography.titleCard,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Last Request Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: serviceState.lastRequestTitle != null
                    ? Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.circle, color: AppColors.success, size: 14),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Son Talep: ${serviceState.lastRequestTitle} - ${serviceState.lastRequestTime ?? "Az önce"}',
                                  style: AppTypography.titleCard.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tahmini Varış: ${serviceState.estimatedArrival ?? "~2-3 dk"}',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Henüz bir talep gönderilmedi',
                                  style: AppTypography.titleCard.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Yukarıdaki kartlardan birine dokunarak çağrı oluşturabilirsiniz.',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),

              // Assigned Waiter Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 0.8),
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
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.person_fill, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Garsonunuz',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          waiterName,
                          style: AppTypography.titleCard,
                        ),
                      ],
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
}
