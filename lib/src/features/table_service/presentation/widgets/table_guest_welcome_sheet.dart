import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../menu/application/menu_provider.dart';
import '../../../welcome/application/table_session_provider.dart';

class TableGuestWelcomeSheet extends ConsumerStatefulWidget {
  final String tableId;
  final String tableName;
  final String zoneName;
  final String tenantId;
  final String venueName;
  final String? wifiSsid;
  final String? wifiPassword;

  const TableGuestWelcomeSheet({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.zoneName,
    required this.tenantId,
    required this.venueName,
    this.wifiSsid,
    this.wifiPassword,
  });

  static Future<void> show(
    BuildContext context, {
    required String tableId,
    required String tableName,
    required String zoneName,
    required String tenantId,
    required String venueName,
    String? wifiSsid,
    String? wifiPassword,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TableGuestWelcomeSheet(
        tableId: tableId,
        tableName: tableName,
        zoneName: zoneName,
        tenantId: tenantId,
        venueName: venueName,
        wifiSsid: wifiSsid,
        wifiPassword: wifiPassword,
      ),
    );
  }

  @override
  ConsumerState<TableGuestWelcomeSheet> createState() => _TableGuestWelcomeSheetState();
}

class _TableGuestWelcomeSheetState extends ConsumerState<TableGuestWelcomeSheet> {
  int _guestCount = 2;

  final List<int> _guestOptions = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Venue & Table Welcome Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan, width: 1.5),
                  ),
                  child: const Icon(Icons.table_restaurant_rounded, color: AppColors.cyan, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.venueName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            widget.tableName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.zoneName,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const Text(
            'Masanıza Hoş Geldiniz!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kaç kişi oturuyorsunuz? Servis ve ikramlarımızı kişi sayısına göre hazırlayalım:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Guest count selector chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _guestOptions.map((count) {
              final isSelected = _guestCount == count;
              return GestureDetector(
                onTap: () => setState(() => _guestCount = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 68,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.cyan : AppColors.border,
                      width: isSelected ? 2.0 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        count == 1
                            ? Icons.person_rounded
                            : count <= 3
                                ? Icons.group_rounded
                                : Icons.groups_rounded,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count Kişi',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Action CTA: Confirm & Open Menu
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
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
                onPressed: () async {
                  final res = await ref.read(tableSessionProvider.notifier).confirmTableSeating(
                    tableId: widget.tableId,
                    tableName: widget.tableName,
                    zoneName: widget.zoneName,
                    tenantId: widget.tenantId,
                    venueName: widget.venueName,
                    guestCount: _guestCount,
                    wifiSsid: widget.wifiSsid,
                    wifiPassword: widget.wifiPassword,
                  );

                  if (!context.mounted) return;

                  if (res['success'] != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ?? 'Masaya oturulamadı.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Refresh live menu for this seated table
                  ref.read(menuProvider.notifier).fetchMenu(
                    tenantId: widget.tenantId,
                    tableId: widget.tableId,
                  );

                  Navigator.pop(context);
                  context.go('/menu');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'Masayı Onayla ve Menüyü Gör ($_guestCount Kişi)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary CTA: Only browse menu
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/menu');
            },
            child: const Text(
              'Şimdilik Sadece Menüyü İncele',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
