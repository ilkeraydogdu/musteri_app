import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/core/network/api_client.dart';
import 'src/core/routing/app_router.dart';
import 'src/core/services/notification_service.dart';
import 'src/core/theme/app_colors.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/cart/application/cart_provider.dart';
import 'src/features/menu/application/menu_provider.dart';
import 'src/features/table_service/presentation/widgets/table_qr_scanner_sheet.dart';
import 'src/features/tracking/application/tracking_provider.dart';
import 'src/features/welcome/application/table_session_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait only — never landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set iOS system bar styling for dark luxury theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: QordyMusteriApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await CustomerNotificationService().init();
      await CustomerNotificationService().requestPermissionsIfNeeded();
    } catch (e) {
      debugPrint('[CustomerNotificationService] init error: $e');
    }
  });
}

class _IosScrollBehavior extends CupertinoScrollBehavior {
  const _IosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class QordyMusteriApp extends ConsumerStatefulWidget {
  const QordyMusteriApp({super.key});

  @override
  ConsumerState<QordyMusteriApp> createState() => _QordyMusteriAppState();
}

class _QordyMusteriAppState extends ConsumerState<QordyMusteriApp>
    with WidgetsBindingObserver {
  static WidgetRef? _activeRef;

  @override
  void initState() {
    super.initState();
    _activeRef = ref;
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      try {
        developer.registerExtension('ext.qordy.testAction', (method, params) async {
          final r = _activeRef;
          if (r == null) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'status': 'error', 'error': 'no active ref'}),
            );
          }
          try {
            final route = params['route'];
            final action = params['action'];
            if (action == 'seat') {
              await r.read(tableSessionProvider.notifier).confirmTableSeating(
                    tableId: 'TBL_69653f43c3d01',
                    tableName: 'Masa 12',
                    zoneName: 'Teras Bahçe',
                    guestCount: 2,
                    adultCount: 2,
                  );
            } else if (action == 'unseat') {
              await r.read(tableSessionProvider.notifier).clearSession();
            } else if (action == 'add_cart') {
              final items = r.read(menuProvider).allItems;
              if (items.isNotEmpty) {
                r.read(cartProvider.notifier).addItem(item: items.first, quantity: 2);
                if (items.length > 1) {
                  r.read(cartProvider.notifier).addItem(item: items[1], quantity: 1);
                }
              }
            } else if (action == 'scroll') {
              final offset = double.tryParse(params['offset'] ?? '0') ?? 0;
              ScrollableState? target;
              void visit(Element e) {
                if (target != null) return;
                if (e is StatefulElement &&
                    e.state is ScrollableState &&
                    (e.state as ScrollableState).position.axis == Axis.vertical) {
                  target = e.state as ScrollableState;
                  return;
                }
                e.visitChildren(visit);
              }
              WidgetsBinding.instance.rootElement?.visitChildren(visit);
              final pos = target?.position;
              if (pos != null) {
                pos.jumpTo(offset.clamp(pos.minScrollExtent, pos.maxScrollExtent));
              }
            } else if (action == 'open_qr') {
              final nav = r.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
              if (nav != null) {
                TableQrScannerSheet.show(nav);
              }
            } else if (action == 'track_order') {
              r.read(orderTrackingProvider.notifier).trackOrder(
                    params['order_id'] ?? 'ORD_699c621b20bd8',
                    orderNumber: params['order_number'] ?? '#4758',
                  );
            }
            if (route != null && route.isNotEmpty) {
              r.read(appRouterProvider).go(route);
            }
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'status': 'ok', 'route': route, 'action': action}),
            );
          } catch (e) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'status': 'error', 'error': e.toString()}),
            );
          }
        });
      } catch (_) {}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = ref.read(apiClientProvider);
      CustomerNotificationService().startWatchdog(api);
      try {
        await CustomerNotificationService().init();
        await CustomerNotificationService().registerDeviceWithBackend(api);
      } catch (e) {
        debugPrint('CustomerNotificationService init error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CustomerNotificationService().stopWatchdog();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately synchronize live venue, menu, and active order status on iOS resume
      ref.read(tableSessionProvider.notifier).fetchLiveVenueInfo();
      ref.read(menuProvider.notifier).fetchMenu(silent: true);
      ref.read(orderTrackingProvider.notifier).fetchOrderStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Qordy Müşteri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const _IosScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
