import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
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
import '../../features/stock/domain/entities/stock_item.dart';
import '../../features/stock/presentation/pages/stock_details_grazer_page.dart';
import '../../features/stock/presentation/pages/stock_handover_page.dart';
import '../../features/stock/presentation/pages/stock_history_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';
import '../../features/dc_console/presentation/pages/dc_console_layout.dart';
import '../../features/client_portal/presentation/pages/client_portal_layout.dart';
import '../../features/client_portal/presentation/pages/closer_mobile_portal_page.dart';
import '../../presentation/presentation_root.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.user != next.user ||
            previous?.isAuthenticated != next.isAuthenticated ||
            previous?.isInitialized != next.isInitialized ||
            previous?.user?.role != next.user?.role ||
            previous?.user?.isClient != next.user?.isClient ||
            previous?.user?.isDcManager != next.user?.isDcManager ||
            previous?.user?.isCloser != next.user?.isCloser ||
            previous?.user?.isClientAdmin != next.user?.isClientAdmin) {
          notifyListeners();
        }
      },
    );
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

/// Pure, deterministic route redirection & isolation logic for all 4 operational consoles
String? appRouteRedirect({
  required AuthState authState,
  required String matchedLocation,
  bool hasSupabaseSession = false,
}) {
  final isAuthFromState = authState.isAuthenticated;
  final isAuthenticated = isAuthFromState || hasSupabaseSession;
  final isSplash = matchedLocation == '/splash';
  final isPresentation = matchedLocation == '/presentation';
  final isLoggingIn = matchedLocation == '/login' || matchedLocation == '/forgot-password';

  debugPrint('[AUTH_ROUTER] 🚦 Route check: location="$matchedLocation", isAuthenticated=$isAuthenticated (riverpod=$isAuthFromState, supabase=$hasSupabaseSession)');

  if (isSplash || isPresentation) {
    return null;
  }
  if (!isAuthenticated && !isLoggingIn) {
    debugPrint('[AUTH_ROUTER] 🛑 Access denied for unauthenticated state -> Redirecting to /login');
    return '/login';
  }
  if (isAuthenticated) {
    final user = authState.user;

    // 🚨 CRITICAL ROLE GATE: If authenticated session exists but user profile/role is still resolving,
    // DO NOT guess, DO NOT default to Rider, and NEVER render the Rider console ('/').
    // Hold user on /splash until the UserEntity is fully resolved.
    if (user == null) {
      debugPrint('[AUTH_ROUTER] ⏳ Session detected but UserEntity still resolving -> holding on /splash');
      return '/splash';
    }

    final isDc = user.isDcManager;
    final isCloser = user.isCloser;
    final isClientAdmin = user.isClientAdmin;
    final isRider = user.isRider;

    // Canonical home console path based strictly on the user's role
    final String homePath = user.homeConsoleRoute;

    // 1. If currently on login or forgot-password, redirect immediately to assigned console
    if (isLoggingIn) {
      debugPrint('[AUTH_ROUTER] 🎯 Authenticated ${user.roleDescription} -> Directing to designated console: $homePath');
      return homePath;
    }

    // 2. Strict Console Isolation: Distribution Center Console (/dc/**)
    if (matchedLocation.startsWith('/dc')) {
      if (!isDc) {
        debugPrint('[AUTH_ROUTER] 🛑 Access Denied: User role "${user.role}" cannot access DC Console -> Redirecting to $homePath');
        return homePath;
      }
    }

    // 3. Strict Console Isolation: Client Merchant Portal (/client/**)
    if (matchedLocation.startsWith('/client')) {
      if (!isClientAdmin) {
        debugPrint('[AUTH_ROUTER] 🛑 Access Denied: User role "${user.role}" cannot access Client Merchant Portal -> Redirecting to $homePath');
        return homePath;
      }
    }

    // 4. Strict Console Isolation: Telesales Closer Portal (/closer/**)
    if (matchedLocation.startsWith('/closer')) {
      if (!isCloser) {
        debugPrint('[AUTH_ROUTER] 🛑 Access Denied: User role "${user.role}" cannot access Closer Portal -> Redirecting to $homePath');
        return homePath;
      }
    }

    // 5. Strict Console Isolation: Field Delivery Agent (Rider) Routes
    // Only confirmed Riders can access root ('/'), rider orders list ('/orders'), scanner, POD confirmation, failure reporting, stock, and remittance
    final isRiderOnlyPath = matchedLocation == '/' ||
        matchedLocation == '/orders' ||
        matchedLocation.startsWith('/orders/scan') ||
        matchedLocation.endsWith('/deliver-pod') ||
        matchedLocation.endsWith('/log-failure') ||
        matchedLocation.startsWith('/stock') ||
        matchedLocation.startsWith('/cash') ||
        matchedLocation.startsWith('/finance');

    if (isRiderOnlyPath && !isRider) {
      debugPrint('[AUTH_ROUTER] 🛑 Access Denied: Role "${user.role}" cannot access Rider route "$matchedLocation" -> Redirecting to $homePath');
      return homePath;
    }
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      Session? session;
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {}
      return appRouteRedirect(
        authState: authState,
        matchedLocation: state.matchedLocation,
        hasSupabaseSession: session != null,
      );
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
        path: '/presentation',
        builder: (context, state) => const PresentationRoot(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainBottomNavShell(),
      ),
      GoRoute(
        path: '/closer',
        builder: (context, state) => const CloserMobilePortalPage(),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => const ClientPortalLayout(),
        routes: [
          GoRoute(path: 'dashboard', builder: (context, state) => const ClientPortalLayout()),
          GoRoute(path: 'orders', builder: (context, state) => const ClientPortalLayout()),
          GoRoute(path: 'products', builder: (context, state) => const ClientPortalLayout()),
        ],
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
        path: '/remittance/receipt/:id',
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
          final name = state.pathParameters['name'] ?? '';
          final stockItem = state.extra is StockItemEntity ? state.extra as StockItemEntity : null;
          return StockDetailsGrazerPage(
            productName: name,
            stockItem: stockItem,
          );
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
