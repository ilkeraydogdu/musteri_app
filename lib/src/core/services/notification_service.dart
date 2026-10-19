import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../network/api_client.dart';

/// Müşteri uygulaması için bildirim servisi.
///
/// - Android 13+ runtime izin kontrolü yapar
/// - Backend'e device token kaydeder
/// - Watchdog poller ile WebSocket kesintilerinde bile bildirimleri yakalar
class CustomerNotificationService {
  static final CustomerNotificationService _instance =
      CustomerNotificationService._internal();
  factory CustomerNotificationService() => _instance;
  CustomerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isInitialized = false;

  static const String channelId = 'qordy_customer_channel';
  static const String channelName = 'Qordy Sipariş & Masa Bildirimleri';
  static const String channelDesc =
      'Sipariş durumu, garson çağrısı ve masa bildirimleri';

  Timer? _watchdogTimer;
  final Set<String> _handledNotificationIds = {};
  bool _isPolling = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[CustomerNotif] Clicked with payload: ${response.payload}');
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    _isInitialized = true;
  }

  /// Masa oturumu açıldığında, sipariş verildiğinde veya bildirim gösterileceğinde izin ister.
  Future<bool> requestPermissionsIfNeeded() async {
    try {
      if (!_isInitialized) await init();
      if (Platform.isIOS) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        return await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      } else if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('[CustomerNotif] permission error: $e');
    }
    return false;
  }

  /// Yüksek öncelikli heads-up bildirim gösterir.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      if (!_isInitialized) await init();
      await requestPermissionsIfNeeded();

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Qordy Bildirim',
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notifId =
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
      notifId,
      title,
      body,
      details,
      payload: payload,
      );
    } catch (e) {
      debugPrint('[CustomerNotif] show error: $e');
    }
  }

  /// Cihazı backend'e kaydeder.
  Future<void> registerDeviceWithBackend(ApiClient api) async {
    try {
      var deviceId = await _storage.read(key: 'qordy_customer_device_uuid');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'customer_${const Uuid().v4()}';
        await _storage.write(key: 'qordy_customer_device_uuid', value: deviceId);
      }

      await api.post(
        '/mobile/customer/register-device',
        data: {
          'token': deviceId,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'device_id': deviceId,
        },
      );
      debugPrint('[CustomerNotif] Device registered: $deviceId');
    } catch (e) {
      debugPrint('[CustomerNotif] registerDevice error: $e');
    }
  }

  /// Background watchdog — WebSocket kesilse bile bildirimleri yakalar.
  void startWatchdog(ApiClient api) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isPolling) return;
      _isPolling = true;
      try {
        final res = await api.get('/mobile/customer/notifications', queryParameters: {'limit': 10});
        final responseData = res.data is Map ? res.data as Map<String, dynamic> : {};
        final items = (responseData['data'] is Map ? responseData['data']['items'] : null) as List? ?? [];
        for (final item in items) {
          final id = item['notification_id']?.toString() ?? '';
          final isRead = item['is_read'] == true || item['is_read'] == 1;
          if (!isRead && id.isNotEmpty && !_handledNotificationIds.contains(id)) {
            _handledNotificationIds.add(id);
            await showNotification(
              title: (item['title']?.toString() ?? '').isNotEmpty
                  ? item['title'].toString()
                  : 'Yeni Qordy Bildirimi',
              body: item['body']?.toString() ?? '',
              payload: id,
            );
          }
        }
      } catch (e) {
        // Silently ignore network hiccup during background poll
      } finally {
        _isPolling = false;
      }
    });
    debugPrint('[CustomerNotif] Watchdog started (4s interval)');
  }

  void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
}