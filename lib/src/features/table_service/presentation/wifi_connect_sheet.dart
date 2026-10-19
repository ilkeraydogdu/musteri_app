import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../welcome/application/table_session_provider.dart';

class WifiConnectSheet extends ConsumerStatefulWidget {
  const WifiConnectSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WifiConnectSheet(),
    );
  }

  @override
  ConsumerState<WifiConnectSheet> createState() => _WifiConnectSheetState();
}

class _WifiConnectSheetState extends ConsumerState<WifiConnectSheet> {
  bool _autoConnect = true;

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(tableSessionProvider);
    final venueTitle = table.venueName.isNotEmpty ? table.venueName : 'İşletme';
    final hasWifi = table.showWifi && table.wifiSsid.isNotEmpty;
    final ssid = hasWifi ? table.wifiSsid : 'Ağ Bilgisi Bulunamadı';
    final password = hasWifi && table.wifiPassword.isNotEmpty ? table.wifiPassword : 'Şifresiz';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WiFi Bağlantı', style: AppTypography.headingLarge),
                    const SizedBox(height: 2),
                    Text(
                      '$venueTitle · Hızlı & Ücretsiz',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main WiFi Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.8),
                boxShadow: [
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
                        'MİSAFİR KABLOSUZ AĞI (SSID)',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, color: AppColors.success, size: 8),
                            const SizedBox(width: 5),
                            Text(
                              'Aktif Ağ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ssid,
                          style: AppTypography.headingMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ağ adını kopyala',
                        icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: ssid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ağ adı ($ssid) kopyalandı.'),
                              backgroundColor: AppColors.surfaceElevated,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.border, thickness: 0.8),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('FREKANS & GÜVENLİK', style: AppTypography.caption),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.security_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 4),
                              Text('5 GHz · WPA2', style: AppTypography.titleCard),
                            ],
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Column(
                        children: [
                          Text('KAPSAMA ALANI', style: AppTypography.caption),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.wifi_tethering_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                table.zoneName.isNotEmpty ? table.zoneName : 'Tüm Salon',
                                style: AppTypography.titleCard,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Password & Copy Row
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ağ Şifresi', style: AppTypography.caption),
                        const SizedBox(height: 3),
                        Text(
                          password,
                          style: AppTypography.titleCard.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success),
                              const SizedBox(width: 10),
                              Text('WiFi şifresi panoya kopyalandı!', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                            ],
                          ),
                          backgroundColor: AppColors.textPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Text('Şifreyi Kopyala', style: AppTypography.buttonMedium.copyWith(fontSize: 13, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Auto Connect Toggle Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Otomatik Bağlan', style: AppTypography.bodyLarge),
                  Switch.adaptive(
                    value: _autoConnect,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _autoConnect = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // QR Connect Help Card
            Container(
              padding: const EdgeInsets.all(18),
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
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 32),
                  const SizedBox(height: 10),
                  Text('Kameranızla Bağlanın', style: AppTypography.titleCard),
                  const SizedBox(height: 6),
                  Text(
                    'Masadaki QR kodu kameranıza okutarak WiFi şifresini yazmadan otomatik bağlanabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall,
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
