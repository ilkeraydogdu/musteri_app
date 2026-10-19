import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../welcome/application/table_session_provider.dart';

class ServiceRequestState {
  final bool isSubmitting;
  final String? lastRequestTitle;
  final String? lastRequestTime;
  final String? estimatedArrival;
  final String? assignedWaiter;
  final String? successMessage;
  final String? errorMessage;

  const ServiceRequestState({
    this.isSubmitting = false,
    this.lastRequestTitle,
    this.lastRequestTime,
    this.estimatedArrival,
    this.assignedWaiter,
    this.successMessage,
    this.errorMessage,
  });

  ServiceRequestState copyWith({
    bool? isSubmitting,
    String? lastRequestTitle,
    String? lastRequestTime,
    String? estimatedArrival,
    String? assignedWaiter,
    String? successMessage,
    String? errorMessage,
  }) {
    return ServiceRequestState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastRequestTitle: lastRequestTitle ?? this.lastRequestTitle,
      lastRequestTime: lastRequestTime ?? this.lastRequestTime,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      assignedWaiter: assignedWaiter ?? this.assignedWaiter,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

final serviceRequestProvider =
    StateNotifierProvider<ServiceRequestNotifier, ServiceRequestState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ServiceRequestNotifier(ref, apiClient);
});

class ServiceRequestNotifier extends StateNotifier<ServiceRequestState> {
  final Ref _ref;
  final ApiClient _apiClient;

  ServiceRequestNotifier(this._ref, this._apiClient)
      : super(const ServiceRequestState());

  Future<bool> sendRequest(String title, {String? details}) async {
    final table = _ref.read(tableSessionProvider);
    if (!table.isSeated || table.tableId.isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Lütfen önce masanızdaki QR kodu okutun.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, successMessage: null, errorMessage: null);

    try {
      final tenantId = (table.lockedTenantId != null && table.lockedTenantId!.isNotEmpty)
          ? table.lockedTenantId!
          : table.venueId;
      final res = await _apiClient.post(ApiConstants.callWaiter, data: {
        'tenant_id': tenantId,
        'table_id': table.tableId,
        'table_name': table.tableName,
        'type': title,
        'reason': title,
        'details': details ?? '',
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final serverWaiter = res.data['assigned_waiter']?.toString();
        final serverEstimate = res.data['estimated_arrival']?.toString();
        state = state.copyWith(
          isSubmitting: false,
          lastRequestTitle: title,
          lastRequestTime: 'Az önce',
          estimatedArrival: serverEstimate ?? '~2-3 dk',
          assignedWaiter: (serverWaiter != null && serverWaiter.isNotEmpty)
              ? serverWaiter
              : (table.assignedWaiter.isNotEmpty ? table.assignedWaiter : 'Masa Sorumlusu'),
          successMessage: res.data['message']?.toString() ?? '$title talebiniz garsona iletildi.',
        );
        return true;
      } else {
        final err = res.data?['error']?.toString() ?? 'Garson çağrısı iletilemedi.';
        state = state.copyWith(isSubmitting: false, errorMessage: err);
        return false;
      }
    } catch (e) {
      debugPrint('ServiceRequestNotifier: callWaiter error: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Ağ bağlantısı kurulamadı: Garson çağrısı iletilemedi.',
      );
      return false;
    }
  }

  Future<bool> requestBill({
    required String paymentMethod,
    double tipPercent = 0.0,
    double tipAmount = 0.0,
    double totalAmount = 0.0,
  }) async {
    final table = _ref.read(tableSessionProvider);
    if (!table.isSeated || table.tableId.isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Lütfen önce masanızdaki QR kodu okutun.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, successMessage: null, errorMessage: null);

    try {
      final tenantId = (table.lockedTenantId != null && table.lockedTenantId!.isNotEmpty)
          ? table.lockedTenantId!
          : table.venueId;
      final res = await _apiClient.post(ApiConstants.requestBill, data: {
        'tenant_id': tenantId,
        'table_id': table.tableId,
        'table_name': table.tableName,
        'payment_method': paymentMethod,
        'tip_percent': tipPercent,
        'tip_amount': tipAmount,
        'total_amount': totalAmount,
      });

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final serverWaiter = res.data['assigned_waiter']?.toString();
        final serverEstimate = res.data['estimated_arrival']?.toString();
        state = state.copyWith(
          isSubmitting: false,
          lastRequestTitle: 'Hesap İstendi ($paymentMethod)',
          lastRequestTime: 'Az önce',
          estimatedArrival: serverEstimate ?? '~2 dk',
          assignedWaiter: (serverWaiter != null && serverWaiter.isNotEmpty)
              ? serverWaiter
              : (table.assignedWaiter.isNotEmpty ? table.assignedWaiter : 'Masa Sorumlusu'),
          successMessage: res.data['message']?.toString() ?? 'Hesap talebiniz garsona iletildi.',
        );
        return true;
      } else {
        final err = res.data?['error']?.toString() ?? 'Hesap talebi iletilemedi.';
        state = state.copyWith(isSubmitting: false, errorMessage: err);
        return false;
      }
    } catch (e) {
      debugPrint('ServiceRequestNotifier: requestBill error: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Ağ bağlantısı kurulamadı: Hesap talebi iletilemedi.',
      );
      return false;
    }
  }

  Future<bool> submitReview({
    required int generalRating,
    required int foodRating,
    required int serviceRating,
    required int ambianceRating,
    required int priceRating,
    required List<String> tags,
    String? comment,
    bool isAnonymous = false,
  }) async {
    final table = _ref.read(tableSessionProvider);
    final tenantId = (table.lockedTenantId != null && table.lockedTenantId!.isNotEmpty)
        ? table.lockedTenantId!
        : table.venueId;

    state = state.copyWith(isSubmitting: true, successMessage: null, errorMessage: null);

    try {
      final summary =
          'Genel: $generalRating/5, Yemek: $foodRating/5, Servis: $serviceRating/5, Ambiyans: $ambianceRating/5, F/P: $priceRating/5'
          '${tags.isNotEmpty ? " | Etiketler: ${tags.join(", ")}" : ""}'
          '${(comment != null && comment.trim().isNotEmpty) ? " | Yorum: ${comment.trim()}" : ""}';

      if (table.isSeated && table.tableId.isNotEmpty) {
        await _apiClient.post(ApiConstants.callWaiter, data: {
          'tenant_id': tenantId,
          'table_id': table.tableId,
          'table_name': table.tableName,
          'type': 'Müşteri Değerlendirmesi ($generalRating⭐)',
          'reason': 'Müşteri Değerlendirmesi ($generalRating⭐)',
          'details': summary,
          'is_anonymous': isAnonymous,
        });
      }
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Değerlendirmeniz işletmeye iletildi. Teşekkür ederiz!',
      );
      return true;
    } catch (e) {
      debugPrint('ServiceRequestNotifier: submitReview error: $e');
      state = state.copyWith(isSubmitting: false);
      return true;
    }
  }
}
