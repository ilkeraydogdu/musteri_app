import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/customer_auth_provider.dart';
import '../../../menu/application/menu_provider.dart';
import '../../../welcome/application/table_session_provider.dart';

class TableSeatingGuestSheet extends ConsumerStatefulWidget {
  final String tableId;
  final String tableName;
  final String zoneName;
  final String tenantId;
  final String venueName;
  final String? wifiSsid;
  final String? wifiPassword;

  const TableSeatingGuestSheet({
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
      builder: (_) => TableSeatingGuestSheet(
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
  ConsumerState<TableSeatingGuestSheet> createState() => _TableSeatingGuestSheetState();
}

class _TableSeatingGuestSheetState extends ConsumerState<TableSeatingGuestSheet> {
  int _adults = 2;
  int _children = 0;
  int _babies = 0;
  bool _isSubmitting = false;

  int get _totalGuests => _adults + _children + _babies;

  Widget _buildCounterRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Stepper: [-] value [+]
          Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: value > minValue
                      ? AppColors.primaryLight
                      : AppColors.border.withValues(alpha: 0.3),
                  foregroundColor: value > minValue ? AppColors.primary : AppColors.textMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.remove, size: 18),
                onPressed: value > minValue
                    ? () {
                        HapticFeedback.lightImpact();
                        onChanged(value - 1);
                      }
                    : null,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: value < maxValue
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.add, size: 18),
                onPressed: value < maxValue
                    ? () {
                        HapticFeedback.lightImpact();
                        onChanged(value + 1);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmSeating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final userState = ref.read(customerAuthProvider);
    final customerName = (userState.name != null && userState.name!.isNotEmpty) ? userState.name : null;
    final customerPhone = (userState.phone != null && userState.phone!.isNotEmpty) ? userState.phone : null;

    final res = await ref.read(tableSessionProvider.notifier).confirmTableSeating(
          tableId: widget.tableId,
          tableName: widget.tableName,
          zoneName: widget.zoneName,
          tenantId: widget.tenantId,
          venueName: widget.venueName,
          guestCount: _totalGuests,
          adultCount: _adults,
          childCount: _children,
          babyCount: _babies,
          customerName: customerName,
          customerPhone: customerPhone,
          wifiSsid: widget.wifiSsid,
          wifiPassword: widget.wifiPassword,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

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

    // Refresh menu for the seated table
    ref.read(menuProvider.notifier).fetchMenu(
          tenantId: widget.tenantId,
          tableId: widget.tableId,
        );

    Navigator.pop(context);
    context.go('/menu');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
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
            const SizedBox(height: 16),

            // Venue & Table Welcome Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 0.8),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.0),
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.venueName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.zoneName,
                                style: const TextStyle(
                                  color: AppColors.primary,
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
            const SizedBox(height: 20),

            const Text(
              'Masanıza Hoş Geldiniz!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kaç kişi oturuyorsunuz? Servis, kuver ve ikramlarımızı kişi sayısına göre hazırlıyoruz:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),

            // 1. Yetişkin
            _buildCounterRow(
              title: 'Yetişkin',
              subtitle: '13 yaş ve üzeri misafirler',
              icon: Icons.person_rounded,
              iconColor: AppColors.primary,
              value: _adults,
              minValue: 1,
              maxValue: 20,
              onChanged: (val) => setState(() => _adults = val),
            ),
            const SizedBox(height: 10),

            // 2. Çocuk
            _buildCounterRow(
              title: 'Çocuk',
              subtitle: '3 - 12 yaş arası küçük misafirler',
              icon: Icons.child_care_rounded,
              iconColor: Colors.amber,
              value: _children,
              minValue: 0,
              maxValue: 10,
              onChanged: (val) => setState(() => _children = val),
            ),
            const SizedBox(height: 10),

            // 3. Bebek
            _buildCounterRow(
              title: 'Bebek',
              subtitle: 'Mama sandalyesi talebi içerir',
              icon: Icons.baby_changing_station_rounded,
              iconColor: Colors.pinkAccent,
              value: _babies,
              minValue: 0,
              maxValue: 5,
              onChanged: (val) => setState(() => _babies = val),
            ),
            const SizedBox(height: 22),

            // Summary Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.groups_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Toplam $_totalGuests Misafir ($_adults Yetişkin${_children > 0 ? ', $_children Çocuk' : ''}${_babies > 0 ? ', $_babies Bebek' : ''})',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Seating Action CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 14,
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
                  onPressed: _isSubmitting ? null : _handleConfirmSeating,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Masaya Otur & Menüyü Aç ($_totalGuests Kişi)',
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
          ],
        ),
      ),
    );
  }
}
