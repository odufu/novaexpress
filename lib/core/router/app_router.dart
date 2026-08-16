import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/main_bottom_nav_shell.dart';
import '../../features/finance/presentation/pages/log_remittance_page.dart';
import '../../features/finance/presentation/pages/remittance_details_page.dart';
import '../../features/finance/presentation/pages/remittance_history_page.dart';
import '../../features/orders/presentation/pages/confirm_delivery_pod_page.dart';
import '../../features/orders/presentation/pages/log_delivery_failure_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/orders/presentation/pages/orders_list_page.dart';
import '../../features/orders/presentation/pages/scan_to_collect_page.dart';
import '../../features/stock/presentation/pages/stock_details_grazer_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/forgot-password';

      if (session == null && !isLoggingIn) {
        return '/login';
      }
      if (session != null && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainBottomNavShell(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const UserProfilePage(),
      ),
      GoRoute(
        path: '/cash/remit',
        builder: (context, state) => const LogRemittancePage(),
      ),
      GoRoute(
        path: '/cash/history',
        builder: (context, state) => const RemittanceHistoryPage(),
      ),
      GoRoute(
        path: '/cash/remittance/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'REM-001';
          return RemittanceDetailsPage(remittanceId: id);
        },
      ),
      GoRoute(
        path: '/orders/scan',
        builder: (context, state) => const ScanToCollectPage(),
      ),
      GoRoute(
        path: '/stock/details/:name',
        builder: (context, state) {
          final name = state.pathParameters['name'] ?? 'Grazer Herbal Tea';
          return StockDetailsGrazerPage(productName: name);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return OrderDetailPage(orderId: id);
            },
            routes: [
              GoRoute(
                path: 'deliver-pod',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return ConfirmDeliveryPodPage(orderId: id);
                },
              ),
              GoRoute(
                path: 'log-failure',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return LogDeliveryFailurePage(orderId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
