import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/order_tracking_model.dart';
import '../../../core/models/venue_table_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../welcome/application/table_session_provider.dart';

final orderTrackingProvider =
    StateNotifierProvider<OrderTrackingNotifier, OrderTrackingModel>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderTrackingNotifier(apiClient, ref);
});

class OrderTrackingNotifier extends StateNotifier<OrderTrackingModel> {
  final ApiClient _apiClient;
  final Ref _ref;
  Timer? _pollTimer;
  bool _isFetching = false;

  OrderTrackingNotifier(this._apiClient, this._ref)
      : super(OrderTrackingModel.empty()) {
    _ref.listen<VenueTableModel>(tableSessionProvider, (prev, next) {
      if (prev?.tableId != next.tableId) {
        if (!next.isSeated) {
          clearOrder();
        } else {
          fetchOrderStatus();
        }
      }
    });
    _initLiveTracking();
  }

  Future<void> _initLiveTracking() async {
    await fetchOrderStatus();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isFetching) {
        fetchOrderStatus();
      }
    });
  }

  Future<void> fetchOrderStatus() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrderId = prefs.getString(ApiConstants.keyActiveOrderId);

      final tableSession = _ref.read(tableSessionProvider);
      final tableId = tableSession.isSeated ? tableSession.tableId : '';
      final tenantId = tableSession.lockedTenantId ?? tableSession.venueId;

      if ((savedOrderId == null || savedOrderId.isEmpty) && tableId.isEmpty) {
        _isFetching = false;
        return;
      }

      final query = <String, dynamic>{};
      if (savedOrderId != null && savedOrderId.isNotEmpty) {
        query['order_id'] = savedOrderId;
      }
      if (tableId.isNotEmpty) {
        query['table_id'] = tableId;
      }
      if (tenantId.isNotEmpty) {
        query['tenant_id'] = tenantId;
      }

      final res = await _apiClient.get(
        ApiConstants.orderStatus,
        queryParameters: query,
      );
      if (res.statusCode == 200 &&
          res.data != null &&
          res.data['success'] == true) {
        final data = res.data as Map<String, dynamic>;
        if (data['has_active_order'] == true) {
          final model = OrderTrackingModel.fromJson(data);
          final prevStatus = state.currentStatus;
          final hadOrder = state.hasActiveOrder && state.orderId == model.orderId;

          state = model;

          if (hadOrder && prevStatus != model.currentStatus) {
            HapticFeedback.mediumImpact();
            _notifyStatusChange(model);
          }

          if (model.orderId.isNotEmpty) {
            await prefs.setString(ApiConstants.keyActiveOrderId, model.orderId);
          }
        } else {
          if (state.hasActiveOrder) {
            state = OrderTrackingModel.empty();
          }
        }
      }
    } catch (e) {
      debugPrint('OrderTrackingNotifier: background poll error: $e');
    } finally {
      _isFetching = false;
    }
  }

  void _notifyStatusChange(OrderTrackingModel model) {
    String title = 'Sipariş Durumu Güncellendi';
    String body = '${model.orderNumber} numaralı siparişiniz güncellendi.';
    switch (model.currentStatus) {
      case OrderStatusStep.received:
        title = 'Siparişiniz Alındı ✨';
        body = 'Siparişiniz mutfak ekranına iletildi.';
        break;
      case OrderStatusStep.preparing:
        title = 'Şef Hazırlıyor 👨‍🍳';
        body = '${model.orderNumber} numaralı siparişiniz şu an hazırlanıyor.';
        break;
      case OrderStatusStep.ready:
        title = 'Siparişiniz Servise Hazır 🔔';
        body = 'Siparişiniz hazırlandı, masanıza doğru yola çıktı!';
        break;
      case OrderStatusStep.delivered:
        title = 'Afiyet Olsun! 🍽️';
        body = 'Siparişiniz masanıza servis edildi.';
        break;
    }
    CustomerNotificationService().showNotification(title: title, body: body);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> trackOrder(String orderId, {String? orderNumber}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (orderId.isNotEmpty) {
        await prefs.setString(ApiConstants.keyActiveOrderId, orderId);
      }
    } catch (e) {
      debugPrint('OrderTrackingNotifier: error saving tracked orderId: $e');
    }
    _startPolling();
    await fetchOrderStatus();
  }

  Future<void> startNewOrder(
    String orderId,
    double totalAmount, {
    String? orderNumber,
    List<TrackedOrderItem>? items,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (orderId.isNotEmpty) {
        await prefs.setString(ApiConstants.keyActiveOrderId, orderId);
      }
    } catch (e) {
      debugPrint('OrderTrackingNotifier: error saving activeOrderId: $e');
    }

    setSimulatedOrder(
      orderId,
      totalAmount,
      orderNumber: orderNumber,
      items: items,
    );
    _startPolling();
    await fetchOrderStatus();
  }

  void setSimulatedOrder(
    String orderId,
    double totalAmount, {
    String? orderNumber,
    List<TrackedOrderItem>? items,
  }) {
    final table = _ref.read(tableSessionProvider);
    state = OrderTrackingModel(
      hasActiveOrder: true,
      orderId: orderId.isNotEmpty ? orderId : 'SIP-LIVE',
      orderNumber: (orderNumber != null && orderNumber.isNotEmpty)
          ? orderNumber
          : (orderId.isNotEmpty ? orderId : 'SIP-LIVE'),
      tableName: table.isSeated ? table.tableName : 'Masa',
      estimatedRemainingMinutes: 15,
      currentStatus: OrderStatusStep.received,
      rawStatus: 'OPEN',
      totalAmount: totalAmount,
      items: items ?? const [],
      timeline: const [
        TrackingStepItem(
          step: OrderStatusStep.received,
          title: 'Sipariş Alındı',
          description: 'Siparişiniz mutfağa iletildi ve sıraya alındı.',
          time: 'Şimdi',
          isCompleted: false,
          isCurrent: true,
        ),
        TrackingStepItem(
          step: OrderStatusStep.preparing,
          title: 'Şef Tarafından Hazırlanıyor',
          description: 'Siparişiniz özenle hazırlanıyor.',
          time: 'Tahmini: 10 dk',
          isCompleted: false,
          isCurrent: false,
        ),
        TrackingStepItem(
          step: OrderStatusStep.ready,
          title: 'Servise Hazır',
          description: 'Tabak sunumu tamamlandı, garsonumuz teslim alıyor.',
          time: 'Tahmini: 13 dk',
          isCompleted: false,
          isCurrent: false,
        ),
        TrackingStepItem(
          step: OrderStatusStep.delivered,
          title: 'Masanıza Servis Edildi',
          description: 'Siparişiniz masanıza ulaştı. Afiyet olsun!',
          time: 'Tahmini: 15 dk',
          isCompleted: false,
          isCurrent: false,
        ),
      ],
    );
  }

  Future<void> clearOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.keyActiveOrderId);
    } catch (e) {
      debugPrint('OrderTrackingNotifier: error clearing activeOrderId: $e');
    }
    state = OrderTrackingModel.empty();
  }
}
