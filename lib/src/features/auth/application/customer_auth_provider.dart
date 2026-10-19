import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class CustomerUserState {
  final bool isLoggedIn;
  final String? customerId;
  final String? name;
  final String? email;
  final String? phone;
  final int loyaltyPoints;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  const CustomerUserState({
    this.isLoggedIn = false,
    this.customerId,
    this.name,
    this.email,
    this.phone,
    this.loyaltyPoints = 0,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  CustomerUserState copyWith({
    bool? isLoggedIn,
    String? customerId,
    String? name,
    String? email,
    String? phone,
    int? loyaltyPoints,
    String? token,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomerUserState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final customerAuthProvider = StateNotifierProvider<CustomerAuthNotifier, CustomerUserState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerAuthNotifier(apiClient);
});

class CustomerAuthNotifier extends StateNotifier<CustomerUserState> {
  final ApiClient _apiClient;

  CustomerAuthNotifier(this._apiClient) : super(const CustomerUserState()) {
    _apiClient.onSessionExpired = _onSessionExpired;
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      await _apiClient.restoreTokens();
      if (!_apiClient.hasToken) return;

      // Token varsa ama user bilgisi yoksa, sunucudan doğrulamayı dene
      // (Bu kısım opsiyonel; şu an sadece local state'i dolduruyoruz)
      // Gerçek uygulamada /me endpoint'i ile validate edilebilir.

      // Şimdilik token varlığına güveniyoruz, UI açılışında /me çağrısı yapılabilir.
      state = state.copyWith(isLoggedIn: true, token: _apiClient.accessToken);
    } catch (e) {
      debugPrint('CustomerAuthNotifier: Error loading session: $e');
    }
  }

  void _onSessionExpired() {
    logout();
  }

  Future<Map<String, dynamic>> checkEmailDomain(String email) async {
    try {
      final res = await _apiClient.post(ApiConstants.checkEmail, data: {'email': email});
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('CustomerAuthNotifier: checkEmailDomain failed: $e');
    }
    return {'valid': false, 'error': 'E-posta doğrulanamadı.'};
  }

  Future<Map<String, dynamic>> _postAuth(String path, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.postAuth(path, data: data);
      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final token = res.data['token']?.toString();
        final refreshToken = res.data['refresh_token']?.toString();
        final user = res.data['user'] as Map<String, dynamic>? ?? {};

        if (token != null) {
          await _apiClient.persistTokens(access: token, refresh: refreshToken);
        }

        state = CustomerUserState(
          isLoggedIn: true,
          token: token,
          customerId: user['customer_id']?.toString(),
          name: user['name']?.toString(),
          email: user['email']?.toString(),
          phone: user['phone']?.toString(),
          loyaltyPoints: int.tryParse(user['loyalty_points']?.toString() ?? '0') ?? 0,
          isLoading: false,
        );

        return {'success': true};
      }

      final err = res.data?['error']?.toString() ?? 'İşlem gerçekleştirilemedi.';
      state = state.copyWith(isLoading: false, errorMessage: err);
      return {'success': false, 'error': err};
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Bağlantı hatası: $e');
      return {'success': false, 'error': 'Bağlantı hatası'};
    }
  }

  Future<bool> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? tenantId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _postAuth(ApiConstants.registerCustomer, {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.replaceAll(RegExp(r'\s+'), ''),
      'password': password,
      'tenant_id': tenantId,
    });
    return result['success'] == true;
  }

  Future<bool> loginCustomer({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _postAuth(ApiConstants.loginCustomer, {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return result['success'] == true;
  }

  Future<void> logout() async {
    await _apiClient.clearPersistedTokens();
    state = const CustomerUserState();
  }
}