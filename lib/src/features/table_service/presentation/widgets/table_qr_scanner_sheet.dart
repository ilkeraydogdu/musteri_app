import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../welcome/application/table_session_provider.dart';
import 'table_seating_guest_sheet.dart';

class TableQrScannerSheet extends ConsumerStatefulWidget {
  const TableQrScannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TableQrScannerSheet(),
    );
  }

  @override
  ConsumerState<TableQrScannerSheet> createState() => _TableQrScannerSheetState();
}

class _TableQrScannerSheetState extends ConsumerState<TableQrScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetected(String rawCode) async {
    if (_isProcessing || rawCode.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final notifier = ref.read(tableSessionProvider.notifier);
    final resolved = await notifier.resolveTableQr(rawCode.trim());

    if (!mounted) return;

    if (resolved != null && resolved['success'] == true) {
      final table = resolved['table'] as Map<String, dynamic>? ?? {};
      final venue = resolved['venue'] as Map<String, dynamic>? ?? {};

      Navigator.pop(context); // Close scanner modal
      TableSeatingGuestSheet.show(
        context,
        tableId: table['table_id']?.toString() ?? '',
        tableName: table['name']?.toString() ?? 'Masa',
        zoneName: table['zone_name']?.toString() ?? 'Genel Alan',
        tenantId: venue['tenant_id']?.toString() ?? table['tenant_id']?.toString() ?? '',
        venueName: venue['venue_name']?.toString() ?? (ref.read(tableSessionProvider).venueName.isNotEmpty ? ref.read(tableSessionProvider).venueName : 'İşletme'),
        wifiSsid: venue['wifi_ssid']?.toString(),
        wifiPassword: venue['wifi_password']?.toString(),
      );
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Geçersiz QR kod veya masa bulunamadı. Lütfen masanızdaki QR etiketi tekrar okutun.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Title & Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masa QR Kodu Okutun',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Masanızdaki etiketi kamera çerçevesine hizalayın',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Error banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Camera Scanner Area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final rawValue = barcode.rawValue;
                            if (rawValue != null && rawValue.isNotEmpty) {
                              _handleQrDetected(rawValue);
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // Viewfinder frame
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Loading overlay
                if (_isProcessing)
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        const SizedBox(height: 14),
                        Text(
                          'Masa Doğrulanıyor...',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Camera Controls (Torch & Flip)
                Positioned(
                  bottom: 30,
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.65),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: ValueListenableBuilder(
                          valueListenable: _scannerController,
                          builder: (context, state, child) {
                            return Icon(
                              state.torchState == TorchState.on
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: state.torchState == TorchState.on
                                  ? Colors.amber
                                  : Colors.white,
                            );
                          },
                        ),
                        onPressed: () => _scannerController.toggleTorch(),
                      ),
                      const SizedBox(width: 20),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.65),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                        onPressed: () => _scannerController.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Security Badge footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Fiziksel masa QR doğrulaması ile sipariş güvenliği sağlanır',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
