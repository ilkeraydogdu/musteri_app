import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_screen.dart';
import '../../features/coupons/presentation/coupons_screen.dart';
import '../../features/menu/presentation/digital_menu_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../../features/table_service/presentation/waiter_call_screen.dart';
import '../../features/tracking/presentation/order_tracking_screen.dart';
import '../../features/tracking/presentation/past_orders_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import 'main_shell_route.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  const envRoute = String.fromEnvironment('INITIAL_ROUTE');
  final defaultRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final initial = envRoute.isNotEmpty
      ? envRoute
      : ((defaultRoute.isNotEmpty && defaultRoute != '/') ? defaultRoute : '/welcome');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellRoute(navigationShell: navigationShell);
        },
        branches: [
          // 0: Menü
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu',
                builder: (context, state) => const DigitalMenuScreen(),
              ),
            ],
          ),
          // 1: Sepet
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          // 2: Takip
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracking',
                builder: (context, state) => const OrderTrackingScreen(),
              ),
            ],
          ),
          // 3: Kuponlar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coupons',
                builder: (context, state) => const CouponsScreen(),
              ),
            ],
          ),
          // 4: Profil / Hesabım
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Standalone Fullscreen Routes
      GoRoute(
        path: '/service',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WaiterCallScreen(),
      ),
      GoRoute(
        path: '/past-orders',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PastOrdersScreen(),
      ),
    ],
  );
});
