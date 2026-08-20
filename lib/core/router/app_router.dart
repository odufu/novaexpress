import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/main_bottom_nav_shell.dart';
import '../../features/finance/presentation/pages/log_remittance_page.dart';
import '../../features/finance/presentation/pages/payouts_page.dart';
import '../../features/finance/presentation/pages/remittance_details_page.dart';
import '../../features/finance/presentation/pages/remittance_history_page.dart';
import '../../features/finance/presentation/pages/transaction_history_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/orders/presentation/pages/confirm_delivery_pod_page.dart';
import '../../features/orders/presentation/pages/log_delivery_failure_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/orders/presentation/pages/orders_list_page.dart';
import '../../features/orders/presentation/pages/scan_to_collect_page.dart';
import '../../features/stock/presentation/pages/inventory_audit_page.dart';
import '../../features/stock/presentation/pages/process_returns_page.dart';
import '../../features/stock/presentation/pages/request_stock_page.dart';
import '../../features/stock/presentation/pages/stock_details_grazer_page.dart';
import '../../features/stock/presentation/pages/stock_handover_page.dart';
import '../../features/stock/presentation/pages/stock_history_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';
import '../../features/dc_console/presentation/pages/dc_console_layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthFromState = ref.watch(authProvider.select((s) => s.isAuthenticated));

  return GoRouter(
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      Session? session;
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {}
      final isAuthenticated = isAuthFromState || session != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/forgot-password';

      debugPrint('[AUTH_ROUTER] 🚦 Route check: location="${state.matchedLocation}", isAuthenticated=$isAuthenticated (riverpod=$isAuthFromState, supabase=${session != null})');

      if (isSplash) {
        return null;
      }
      if (!isAuthenticated && !isLoggingIn) {
        debugPrint('[AUTH_ROUTER] 🛑 Access denied for unauthenticated state -> Redirecting to /login');
        return '/login';
      }
      if (isAuthenticated && isLoggingIn) {
        final authState = ref.read(authProvider);
        if (authState.user?.isDcManager == true) {
          debugPrint('[AUTH_ROUTER] 🏢 Authenticated DC Manager -> Redirecting to /dc');
          return '/dc';
        }
        debugPrint('[AUTH_ROUTER] ✅ Authenticated Rider user -> Redirecting to /');
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
        path: '/dc',
        builder: (context, state) => const DCConsoleLayout(),
        routes: [
          GoRoute(path: 'dashboard', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'orders', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'inventory', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'remittances', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'returns', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'payouts', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'riders', builder: (context, state) => const DCConsoleLayout()),
          // Aliases for seamless backward compatibility
          GoRoute(path: 'fleet', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'stock', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'dispatch', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'finance', builder: (context, state) => const DCConsoleLayout()),
          GoRoute(path: 'analytics', builder: (context, state) => const DCConsoleLayout()),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
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
        path: '/finance/payouts',
        builder: (context, state) => const PayoutsPage(),
      ),
      GoRoute(
        path: '/finance/transactions',
        builder: (context, state) => const TransactionHistoryPage(),
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
        path: '/stock/request',
        builder: (context, state) => const RequestStockPage(),
      ),
      GoRoute(
        path: '/stock/handover/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'REQ-00482';
          return StockHandoverPage(requestId: id);
        },
      ),
      GoRoute(
        path: '/stock/audit',
        builder: (context, state) => const InventoryAuditPage(),
      ),
      GoRoute(
        path: '/stock/returns',
        builder: (context, state) => const ProcessReturnsPage(),
      ),
      GoRoute(
        path: '/stock/details/:name',
        builder: (context, state) {
          final name = state.pathParameters['name'] ?? 'Respira Detox Tea';
          return StockDetailsGrazerPage(productName: name);
        },
      ),
      GoRoute(
        path: '/stock/history',
        builder: (context, state) => const StockHistoryPage(),
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
});

class AppRouter {
  static GoRouter get router => GoRouter(
    initialLocation: '/splash',
    routes: [],
  );
}
