import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Müşteri uygulaması API istemcisi.
///
/// * Token'lar FlutterSecureStorage üzerinde saklanır.
/// * 401 durumunda refresh token ile tek seferlik yenileme yapılır.
/// * Başarısız refresh'te [onSessionExpired] tetiklenir.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'QordyCustomer',
        },
        validateStatus: (_) => true,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  void Function()? onSessionExpired;

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;

  // ─── Token Yönetimi ──────────────────────────────────────

  void setTokens({required String? access, String? refresh}) {
    _accessToken = access;
    if (refresh != null) _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Future<void> restoreTokens() async {
    _accessToken = await _storage.read(key: ApiConstants.keyCustomerToken);
    _refreshToken = await _storage.read(key: '${ApiConstants.keyCustomerToken}_refresh');
  }

  Future<void> persistTokens({required String access, String? refresh}) async {
    _accessToken = access;
    await _storage.write(key: ApiConstants.keyCustomerToken, value: access);
    if (refresh != null) {
      _refreshToken = refresh;
      await _storage.write(key: '${ApiConstants.keyCustomerToken}_refresh', value: refresh);
    }
  }

  Future<void> clearPersistedTokens() async {
    clearTokens();
    await _storage.delete(key: ApiConstants.keyCustomerToken);
    await _storage.delete(key: '${ApiConstants.keyCustomerToken}_refresh');
  }

  // ─── Interceptor ─────────────────────────────────────────

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null &&
        _accessToken!.isNotEmpty &&
        options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  // ─── Public API ──────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters);
  }

  /// Auth akışları için ham response dönen özel metot.
  /// Refresh mantığı devre dışı bırakılır (login/register sırasında gereksiz).
  Future<Response> postAuth(String path, {dynamic data}) async {
    return await _dio.post(
      path,
      data: data,
      options: Options(extra: {'skipRefresh': true}),
    );
  }

  // ─── Core ────────────────────────────────────────────────

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool retried = false,
  }) async {
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      throw _networkError(e);
    }

    final status = response.statusCode ?? 0;
    final data = _asMap(response.data);
    final skipRefresh = response.requestOptions.extra['skipRefresh'] == true;

    if (status == 401 &&
        !retried &&
        !skipRefresh &&
        _refreshToken != null &&
        !path.contains('/auth/refresh') &&
        !path.contains('/login') &&
        !path.contains('/register')) {
      final ok = await _refreshTokens();
      if (ok) {
        return request(method, path, query: query, body: body, retried: true);
      }
      onSessionExpired?.call();
    }

    final success = data['success'];
    if (status >= 200 && status < 300 && success != false) {
      return data;
    }

    final message = _extractError(data, status);
    if (status == 401 && retried) {
      onSessionExpired?.call();
    }
    throw ApiException(message, statusCode: status, payload: data);
  }

  Future<bool> _refreshTokens() {
    _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _dio.post<dynamic>(
        '/mobile/customer/refresh-token',
        data: {'refresh_token': refresh},
        options: Options(
          headers: {'Authorization': 'Bearer $refresh'},
          extra: {'skipRefresh': true},
        ),
      );
      final data = _asMap(response.data);
      if ((response.statusCode ?? 0) >= 200 &&
          (response.statusCode ?? 0) < 300 &&
          data['success'] != false) {
        final payload = _asMap(data['data'] ?? data);
        final newAccess = payload['token']?.toString() ?? payload['access_token']?.toString();
        final newRefresh = payload['refresh_token']?.toString();
        if (newAccess != null && newAccess.isNotEmpty) {
          await persistTokens(access: newAccess, refresh: newRefresh);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] Token refresh failed: $e');
    }
    return false;
  }

  // ─── Helpers ─────────────────────────────────────────────

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) return {'success': true, 'data': raw};
    if (raw is String && raw.isNotEmpty) return {'success': false, 'error': raw};
    return <String, dynamic>{};
  }

  String _extractError(Map<String, dynamic> data, int status) {
    final error = data['error'];
    if (error is String && error.isNotEmpty) return error;
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    return switch (status) {
      401 => 'Oturum süresi doldu, lütfen yeniden giriş yapın',
      403 => 'Bu işlem için yetkiniz yok',
      404 => 'Kayıt bulunamadı',
      422 => 'Girilen bilgiler geçersiz',
      429 => 'Çok fazla istek, lütfen bekleyin',
      >= 500 => 'Sunucu hatası, lütfen tekrar deneyin',
      _ => 'İşlem başarısız ($status)',
    };
  }

  ApiException _networkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'Sunucuya ulaşılamadı (zaman aşımı). İnternet bağlantınızı kontrol edin.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'İnternet bağlantısı yok veya sunucuya erişilemiyor.',
          code: 'NO_CONNECTION',
        );
      case DioExceptionType.cancel:
        return const ApiException('İstek iptal edildi.', code: 'CANCELLED');
      default:
        return ApiException(e.message ?? 'Ağ hatası', code: 'NETWORK');
    }
  }
}

/// Hata bilgilerini taşıyan exception sınıfı.
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  const ApiException(this.message, {this.code, this.statusCode, this.payload});

  bool get isUnauthorized =>
      statusCode == 401 || code == 'TOKEN_EXPIRED' || code == 'TOKEN_INVALID';
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);