import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/cart_model.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/models/order_tracking_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/location_helper.dart';
import '../../tracking/application/tracking_provider.dart';
import '../../welcome/application/table_session_provider.dart';

class CartState {
  final List<CartItemModel> items;
  final CouponModel? appliedCoupon;
  final bool isSubmitting;
  final String? errorMessage;
  final String? lastOrderNumber;

  const CartState({
    this.items = const [],
    this.appliedCoupon,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastOrderNumber,
  });

  int get totalItemCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get discountAmount {
    if (appliedCoupon == null) return 0.0;
    return appliedCoupon!.calculateDiscount(subtotal);
  }

  double get vatAmount {
    final taxable = subtotal - discountAmount;
    return taxable > 0 ? taxable * 0.10 : 0.0;
  }

  double get grandTotal {
    final base = (subtotal - discountAmount) + vatAmount;
    return base > 0 ? base : 0.0;
  }

  CartState copyWith({
    List<CartItemModel>? items,
    CouponModel? appliedCoupon,
    bool clearCoupon = false,
    bool? isSubmitting,
    String? errorMessage,
    String? lastOrderNumber,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      lastOrderNumber: lastOrderNumber ?? this.lastOrderNumber,
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CartNotifier(ref, apiClient);
});

class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;
  final ApiClient _apiClient;

  CartNotifier(this._ref, this._apiClient)
      : super(const CartState(items: []));

  void addItem({
    required MenuItemModel item,
    int quantity = 1,
    ProductVariant? selectedVariant,
    String? cookingDegree,
    List<MenuOptionExtra> extras = const [],
    List<String> removedIngredients = const [],
    String? note,
  }) {
    final newItem = CartItemModel(
      id: 'cart_${DateTime.now().millisecondsSinceEpoch}_${state.items.length}',
      menuItem: item,
      quantity: quantity,
      selectedVariant: selectedVariant,
      cookingDegree: cookingDegree,
      selectedExtras: extras,
      removedIngredients: removedIngredients,
      note: note,
    );

    state = state.copyWith(items: [...state.items, newItem], errorMessage: null);
  }

  void increment(String cartItemId) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id == cartItemId) {
          return item.copyWith(quantity: item.quantity + 1);
        }
        return item;
      }).toList(),
    );
  }

  void decrement(String cartItemId) {
    state = state.copyWith(
      items: state.items.where((item) {
        if (item.id == cartItemId) {
          return item.quantity > 1;
        }
        return true;
      }).map((item) {
        if (item.id == cartItemId) {
          return item.copyWith(quantity: item.quantity - 1);
        }
        return item;
      }).toList(),
    );
  }

  void removeItem(String cartItemId) {
    final updated = state.items.where((i) => i.id != cartItemId).toList();
    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  void applyCoupon(CouponModel coupon) {
    state = state.copyWith(appliedCoupon: coupon);
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  Future<bool> sendOrder({String? customerNote}) async {
    if (state.items.isEmpty) return false;

    final table = _ref.read(tableSessionProvider);
    if (!table.isSeated) {
      state = state.copyWith(
        errorMessage: 'Sipariş vermek için lütfen önce masanızdaki QR kodu okutun.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final coords = await LocationHelper.getCurrentCoordinates();

    final orderPayload = {
      'table_id': table.tableId,
      'tenant_id': table.lockedTenantId ?? table.venueId,
      'guest_count': table.guestCount,
      'customer_note': customerNote ?? '',
      if (state.appliedCoupon != null) ...{
        'coupon_code': state.appliedCoupon!.code,
        'discount_amount': state.discountAmount,
      },
      'items': state.items.map((e) => e.toApiPayload()).toList(),
      if (coords != null) ...{
        'latitude': coords['latitude'],
        'longitude': coords['longitude'],
        'accuracy': coords['accuracy'],
      },
    };

    final submittedTrackedItems = state.items
        .map(
          (ci) => TrackedOrderItem(
            name: ci.menuItem.name,
            quantity: ci.quantity,
            price: ci.unitPrice,
            preparationStatus: 'PENDING',
          ),
        )
        .toList();

    try {
      final res = await _apiClient.post(
        ApiConstants.placeOrder,
        data: orderPayload,
      );
      if (res.statusCode == 200 &&
          res.data != null &&
          (res.data['success'] == true || res.data['status'] == 'success')) {
        if (res.data['token'] != null && !_apiClient.hasToken) {
          final token = res.data['token'].toString();
          if (token.isNotEmpty) {
            await _apiClient.persistTokens(access: token);
          }
        }
        final orderId = res.data['order_id']?.toString() ?? '';
        final orderNumber = res.data['order_number']?.toString() ??
            (orderId.isNotEmpty ? 'SIP-${orderId.toUpperCase()}' : 'SIP-LIVE');

        final trackingNotifier = _ref.read(orderTrackingProvider.notifier);
        await trackingNotifier.startNewOrder(
          orderId.isNotEmpty ? orderId : orderNumber,
          state.grandTotal,
          orderNumber: orderNumber,
          items: submittedTrackedItems,
        );

        state = state.copyWith(
          isSubmitting: false,
          items: [],
          clearCoupon: true,
          errorMessage: null,
          lastOrderNumber: orderNumber,
        );
        return true;
      } else {
        final errMsg = res.data?['message']?.toString() ??
            res.data?['error']?.toString() ??
            'Sipariş gönderilemedi. Lütfen tekrar deneyin.';
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: errMsg,
        );
        return false;
      }
    } on DioException catch (e) {
      debugPrint('CartProvider: DioException placing order: $e');
      String errMsg = 'Bağlantı hatası nedeniyle sipariş iletilemedi.';
      final respData = e.response?.data;
      if (respData is Map) {
        errMsg = respData['message']?.toString() ??
            respData['error']?.toString() ??
            errMsg;
      }
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: errMsg,
      );
      return false;
    } catch (e) {
      debugPrint('CartProvider: Unexpected error placing order: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Sipariş gönderilirken bir hata oluştu: $e',
      );
      return false;
    }
  }
}
