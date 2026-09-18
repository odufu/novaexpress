import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('Role-Based Route Gating & Isolation Suite', () {
    const merchantUser = UserModel(
      id: 'usr-client-01',
      email: 'client.test@novaxpress.ng',
      firstName: 'Merchant',
      lastName: 'Admin',
      phone: '08011111111',
      role: 'client',
      clientId: 'cli-01',
      clientCompanyName: 'Novacale Limited',
    );

    const dcUser = UserModel(
      id: 'usr-dc-01',
      email: 'dc.test@novaxpress.ng',
      firstName: 'DC',
      lastName: 'Manager',
      phone: '08022222222',
      role: 'dc_manager',
      distributionCenterId: 'dc-01',
      distributionCenterName: 'Wuse DC',
    );

    const closerUser = UserModel(
      id: 'usr-closer-01',
      email: 'closer.test@novaxpress.ng',
      firstName: 'Sales',
      lastName: 'Closer',
      phone: '08033333333',
      role: 'closer',
      closerId: 'cls-01',
      clientId: 'cli-01',
    );

    const riderUser = UserModel(
      id: 'usr-rider-01',
      email: 'rider.test@novaxpress.ng',
      firstName: 'Field',
      lastName: 'Rider',
      phone: '08044444444',
      role: 'delivery_agent',
      deliveryAgentId: 'rider-01',
      deliveryAgentCode: 'PDA-101',
    );

    test('1. UserEntity homeConsoleRoute maps strictly to each role console', () {
      expect(merchantUser.homeConsoleRoute, '/client');
      expect(merchantUser.isClientAdmin, true);
      expect(merchantUser.isRider, false);
      expect(merchantUser.roleDescription, 'E-Commerce Merchant Admin');

      expect(dcUser.homeConsoleRoute, '/dc');
      expect(dcUser.isDcManager, true);
      expect(dcUser.isRider, false);
      expect(dcUser.roleDescription, 'DC Operations Supervisor');

      expect(closerUser.homeConsoleRoute, '/closer');
      expect(closerUser.isCloser, true);
      expect(closerUser.isRider, false);
      expect(closerUser.roleDescription, 'Telesales Closer');

      expect(riderUser.homeConsoleRoute, '/');
      expect(riderUser.isRider, true);
      expect(riderUser.roleDescription, 'Field Delivery Agent (PDA)');
    });

    test('2. Merchant account accessing root ("/") is redirected directly to "/client"', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: merchantUser, isInitialized: true),
        matchedLocation: '/',
      );
      expect(redirect, '/client');
    });

    test('3. Merchant account accessing sub-route ("/client/orders") is permitted (null redirect)', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: merchantUser, isInitialized: true),
        matchedLocation: '/client/orders',
      );
      expect(redirect, isNull);
    });

    test('4. Merchant account attempting to access DC console ("/dc") is redirected to "/client"', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: merchantUser, isInitialized: true),
        matchedLocation: '/dc',
      );
      expect(redirect, '/client');
    });

    test('5. DC Manager accessing root ("/") is redirected directly to "/dc"', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: dcUser, isInitialized: true),
        matchedLocation: '/',
      );
      expect(redirect, '/dc');
    });

    test('6. DC Manager accessing sub-route ("/dc/inventory") is permitted (null redirect)', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: dcUser, isInitialized: true),
        matchedLocation: '/dc/inventory',
      );
      expect(redirect, isNull);
    });

    test('7. Sales Closer accessing root ("/") is redirected directly to "/closer"', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: closerUser, isInitialized: true),
        matchedLocation: '/',
      );
      expect(redirect, '/closer');
    });

    test('8. Field Rider accessing root ("/") is permitted without redirect (null)', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: riderUser, isInitialized: true),
        matchedLocation: '/',
      );
      expect(redirect, isNull);
    });

    test('9. Field Rider accessing rider-only route ("/orders") is permitted (null)', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: riderUser, isInitialized: true),
        matchedLocation: '/orders',
      );
      expect(redirect, isNull);
    });

    test('10. Non-rider attempting to access rider-only route ("/orders") is redirected to their own console', () {
      final merchantRedirect = appRouteRedirect(
        authState: const AuthState(user: merchantUser, isInitialized: true),
        matchedLocation: '/orders',
      );
      expect(merchantRedirect, '/client');

      final dcRedirect = appRouteRedirect(
        authState: const AuthState(user: dcUser, isInitialized: true),
        matchedLocation: '/orders',
      );
      expect(dcRedirect, '/dc');
    });

    test('11. Unauthenticated session accessing root ("/") is redirected to "/login"', () {
      final redirect = appRouteRedirect(
        authState: const AuthState(user: null, isInitialized: true),
        matchedLocation: '/',
        hasSupabaseSession: false,
      );
      expect(redirect, '/login');
    });

    test('12. Active session with unresolved user entity holds on "/splash" and never defaults to Rider app', () {
      // Accessing '/' while session exists in Supabase but UserEntity is still resolving
      final rootRedirect = appRouteRedirect(
        authState: const AuthState(user: null, isLoading: true, isInitialized: false),
        matchedLocation: '/',
        hasSupabaseSession: true,
      );
      expect(rootRedirect, '/splash');

      // Accessing '/client' while session exists in Supabase but UserEntity is still resolving
      final clientRedirect = appRouteRedirect(
        authState: const AuthState(user: null, isLoading: true, isInitialized: false),
        matchedLocation: '/client',
        hasSupabaseSession: true,
      );
      expect(clientRedirect, '/splash');

      // Being on '/splash' while UserEntity is still resolving stays on '/splash' (null)
      final splashRedirect = appRouteRedirect(
        authState: const AuthState(user: null, isLoading: true, isInitialized: false),
        matchedLocation: '/splash',
        hasSupabaseSession: true,
      );
      expect(splashRedirect, isNull);
    });

    test('13. Authenticated user on login page is routed directly to their home console', () {
      final merchantLoginRedirect = appRouteRedirect(
        authState: const AuthState(user: merchantUser, isInitialized: true),
        matchedLocation: '/login',
      );
      expect(merchantLoginRedirect, '/client');

      final dcLoginRedirect = appRouteRedirect(
        authState: const AuthState(user: dcUser, isInitialized: true),
        matchedLocation: '/login',
      );
      expect(dcLoginRedirect, '/dc');

      final closerLoginRedirect = appRouteRedirect(
        authState: const AuthState(user: closerUser, isInitialized: true),
        matchedLocation: '/login',
      );
      expect(closerLoginRedirect, '/closer');

      final riderLoginRedirect = appRouteRedirect(
        authState: const AuthState(user: riderUser, isInitialized: true),
        matchedLocation: '/login',
      );
      expect(riderLoginRedirect, '/');
    });
  });
}
