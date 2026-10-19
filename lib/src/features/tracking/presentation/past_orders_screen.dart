import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/past_order_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../cart/application/cart_provider.dart';
import '../../menu/application/menu_provider.dart';
import '../application/past_orders_provider.dart';
import '../application/tracking_provider.dart';

enum OrderFilter { all, active, completed }

class PastOrdersScreen extends ConsumerStatefulWidget {
  const PastOrdersScreen({super.key});

  @override
  ConsumerState<PastOrdersScreen> createState() => _PastOrdersScreenState();
}

class _PastOrdersScreenState extends ConsumerState<PastOrdersScreen> {
  OrderFilter _selectedFilter = OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (Navigator.of(context).canPop()) const SizedBox(width: 14),
                  Text(
                    'Sipariş Geçmişim',
                    style: AppTypography.headingLarge.copyWith(fontSize: 24),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 20),
                      onPressed: () => ref.refresh(pastOrdersProvider),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _buildFilterTab(OrderFilter.all, 'Tümü'),
                  const SizedBox(width: 8),
                  _buildFilterTab(OrderFilter.active, 'Aktif'),
                  const SizedBox(width: 8),
                  _buildFilterTab(OrderFilter.completed, 'Tamamlanan'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Orders Content
            Expanded(
              child: ordersAsync.when(
                data: (allOrders) {
                  final filtered = allOrders.where((order) {
                    if (_selectedFilter == OrderFilter.active) {
                      return order.isActive;
                    } else if (_selectedFilter == OrderFilter.completed) {
                      return !order.isActive;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => ref.refresh(pastOrdersProvider),
                      color: AppColors.cyan,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: AppColors.textMuted.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bu filtrede sipariş bulunamadı.',
                                  style: AppTypography.titleSmall.copyWith(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Yenilemek için ekranı aşağı çekebilirsiniz.',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(pastOrdersProvider),
                    color: AppColors.cyan,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _buildOrderCard(filtered[index]);
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan),
                ),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 14),
                      Text(
                        'Sipariş geçmişi yüklenemedi.',
                        style: AppTypography.titleSmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(pastOrdersProvider),
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                        label: Text('Tekrar Dene', style: AppTypography.buttonSmall.copyWith(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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

  Widget _buildFilterTab(OrderFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.cyan : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(PastOrderModel order) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final isActive = order.isActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? AppColors.primary.withValues(alpha: 0.15) : const Color(0x080F172A),
            blurRadius: 14,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.createdAt.isNotEmpty ? order.createdAt : 'Tarih belirtilmedi',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        order.venueName,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          order.tableName,
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isActive)
                InkWell(
                  onTap: () {
                    ref.read(orderTrackingProvider.notifier).trackOrder(
                          order.orderId,
                          orderNumber: order.orderNumber,
                        );
                    context.go('/tracking');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TAKİP ET',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const CircleAvatar(radius: 3.5, backgroundColor: AppColors.cyan),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status == 'SERVED' ? 'Servis Edildi' : 'Tamamlandı',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Sipariş detayları',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.itemCount} Kalem · ${order.orderNumber}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormat.format(order.totalAmount),
                style: AppTypography.priceMedium.copyWith(fontSize: 20),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? AppColors.surfaceElevated : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isActive ? AppColors.border : Colors.transparent,
                    ),
                  ),
                  elevation: isActive ? 0 : 3,
                ),
                onPressed: () {
                  if (isActive) {
                    ref.read(orderTrackingProvider.notifier).trackOrder(
                          order.orderId,
                          orderNumber: order.orderNumber,
                        );
                    context.go('/tracking');
                  } else {
                    final menuState = ref.read(menuProvider);
                    final names = order.itemsSummary
                        .split(',')
                        .map((e) => e.trim().toLowerCase())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    int addedCount = 0;
                    for (final n in names) {
                      final match = menuState.allItems.cast<dynamic>().firstWhere(
                            (it) => it.name.toString().toLowerCase().contains(n) ||
                                n.contains(it.name.toString().toLowerCase()),
                            orElse: () => null,
                          );
                      if (match != null) {
                        ref.read(cartProvider.notifier).addItem(item: match);
                        addedCount++;
                      }
                    }
                    if (addedCount == 0 && menuState.allItems.isNotEmpty) {
                      ref.read(cartProvider.notifier).addItem(item: menuState.allItems.first);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sipariş ürünleri sepete eklendi!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.go('/cart');
                  }
                },
                child: Text(
                  isActive ? 'Sipariş Detayı' : 'Tekrar Sipariş',
                  style: AppTypography.buttonSmall.copyWith(
                    color: isActive ? AppColors.textPrimary : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
