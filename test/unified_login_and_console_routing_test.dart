import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';

void main() {
  group('Unified Login & Strict Role-Driven Console Routing Tests', () {
    test('1. DC Manager strictly resolves to /dc console route', () {
      const dcUser = UserEntity(
        id: 'u-dc-01',
        email: 'dc.supervisor@novaxpress.ng',
        firstName: 'Adekunle',
        lastName: 'Supervisor',
        phone: '08012345678',
        role: 'dc_manager',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
      );

      expect(dcUser.isDcManager, isTrue);
      expect(dcUser.isCloser, isFalse);
      expect(dcUser.isClientAdmin, isFalse);
      expect(dcUser.isRider, isFalse);
      expect(dcUser.homeConsoleRoute, equals('/dc'));
    });

    test('2. Client Merchant strictly resolves to /client console route', () {
      const clientUser = UserEntity(
        id: 'u-cli-01',
        email: 'client.novacale@novaxpress.ng',
        firstName: 'Novacale',
        lastName: 'Admin',
        phone: '08023456789',
        role: 'client',
        clientId: '33333333-3333-4333-8333-333333333333',
        clientCompanyName: 'Novacale Limited',
      );

      expect(clientUser.isClientAdmin, isTrue);
      expect(clientUser.isDcManager, isFalse);
      expect(clientUser.isCloser, isFalse);
      expect(clientUser.isRider, isFalse);
      expect(clientUser.homeConsoleRoute, equals('/client'));
    });

    test('3. Sales Closer strictly resolves to /closer console route', () {
      const closerUser = UserEntity(
        id: 'u-cls-01',
        email: 'closer.amaka@novacale.ng',
        firstName: 'Amaka',
        lastName: 'Chioma',
        phone: '08034567890',
        role: 'closer',
        clientId: '33333333-3333-4333-8333-333333333333',
        closerId: '44444444-4444-4444-8444-444444444444',
        closerCode: 'CLS-NOVA-001',
      );

      expect(closerUser.isCloser, isTrue);
      expect(closerUser.isClientAdmin, isFalse);
      expect(closerUser.isDcManager, isFalse);
      expect(closerUser.isRider, isFalse);
      expect(closerUser.homeConsoleRoute, equals('/closer'));
    });

    test('4. Field Delivery Agent (Rider) strictly resolves to / root dashboard', () {
      const riderUser = UserEntity(
        id: 'u-rdr-01',
        email: 'emeka.rider@novaxpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08045678901',
        role: 'delivery_agent',
        deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
        deliveryAgentCode: 'PDA-7000',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
      );

      expect(riderUser.isRider, isTrue);
      expect(riderUser.isDcManager, isFalse);
      expect(riderUser.isCloser, isFalse);
      expect(riderUser.isClientAdmin, isFalse);
      expect(riderUser.homeConsoleRoute, equals('/'));
    });

    test('5. Strict Route Guard logic blocks cross-system access', () {
      // Simulating router guard evaluation
      String? evaluateRedirect(UserEntity user, String matchedLocation) {
        final isDc = user.isDcManager;
        final isCloser = user.isCloser;
        final isClientAdmin = user.isClientAdmin;
        final isRider = user.isRider || (!isDc && !isCloser && !isClientAdmin);
        final homePath = user.homeConsoleRoute;

        if (matchedLocation.startsWith('/dc') && !isDc) return homePath;
        if (matchedLocation.startsWith('/client') && !isClientAdmin) return homePath;
        if (matchedLocation.startsWith('/closer') && !isCloser) return homePath;

        final isRiderOnlyPath = matchedLocation == '/' ||
            matchedLocation == '/orders' ||
            matchedLocation.startsWith('/orders/scan') ||
            matchedLocation.endsWith('/deliver-pod') ||
            matchedLocation.endsWith('/log-failure') ||
            matchedLocation.startsWith('/stock') ||
            matchedLocation.startsWith('/cash') ||
            matchedLocation.startsWith('/finance');

        if (isRiderOnlyPath && !isRider) return homePath;
        return null; // Allowed
      }

      const dcUser = UserEntity(id: '1', email: 'dc@nova.ng', firstName: 'DC', lastName: 'Mgr', phone: '080', role: 'dc_manager');
      const clientUser = UserEntity(id: '2', email: 'client@nova.ng', firstName: 'Cli', lastName: 'Admin', phone: '080', role: 'client');
      const closerUser = UserEntity(id: '3', email: 'closer@nova.ng', firstName: 'Cls', lastName: 'Chioma', phone: '080', role: 'closer');
      const riderUser = UserEntity(id: '4', email: 'rider@nova.ng', firstName: 'Rdr', lastName: 'Emeka', phone: '080', role: 'delivery_agent');

      // DC Manager attempts
      expect(evaluateRedirect(dcUser, '/dc'), isNull); // Allowed
      expect(evaluateRedirect(dcUser, '/dc/orders'), isNull); // Allowed
      expect(evaluateRedirect(dcUser, '/client'), equals('/dc')); // Blocked
      expect(evaluateRedirect(dcUser, '/closer'), equals('/dc')); // Blocked
      expect(evaluateRedirect(dcUser, '/'), equals('/dc')); // Blocked
      expect(evaluateRedirect(dcUser, '/orders'), equals('/dc')); // Blocked
      expect(evaluateRedirect(dcUser, '/stock/request'), equals('/dc')); // Blocked
      expect(evaluateRedirect(dcUser, '/cash/remit'), equals('/dc')); // Blocked

      // Client Merchant attempts
      expect(evaluateRedirect(clientUser, '/client'), isNull); // Allowed
      expect(evaluateRedirect(clientUser, '/client/orders'), isNull); // Allowed
      expect(evaluateRedirect(clientUser, '/dc'), equals('/client')); // Blocked
      expect(evaluateRedirect(clientUser, '/closer'), equals('/client')); // Blocked
      expect(evaluateRedirect(clientUser, '/'), equals('/client')); // Blocked
      expect(evaluateRedirect(clientUser, '/orders'), equals('/client')); // Blocked
      expect(evaluateRedirect(clientUser, '/stock/audit'), equals('/client')); // Blocked

      // Telesales Closer attempts
      expect(evaluateRedirect(closerUser, '/closer'), isNull); // Allowed
      expect(evaluateRedirect(closerUser, '/dc'), equals('/closer')); // Blocked
      expect(evaluateRedirect(closerUser, '/client'), equals('/closer')); // Blocked
      expect(evaluateRedirect(closerUser, '/'), equals('/closer')); // Blocked
      expect(evaluateRedirect(closerUser, '/orders'), equals('/closer')); // Blocked

      // Rider attempts
      expect(evaluateRedirect(riderUser, '/'), isNull); // Allowed
      expect(evaluateRedirect(riderUser, '/orders'), isNull); // Allowed
      expect(evaluateRedirect(riderUser, '/stock/request'), isNull); // Allowed
      expect(evaluateRedirect(riderUser, '/cash/remit'), isNull); // Allowed
      expect(evaluateRedirect(riderUser, '/dc'), equals('/')); // Blocked
      expect(evaluateRedirect(riderUser, '/client'), equals('/')); // Blocked
      expect(evaluateRedirect(riderUser, '/closer'), equals('/')); // Blocked

      // Shared routes accessible by all
      expect(evaluateRedirect(dcUser, '/profile'), isNull);
      expect(evaluateRedirect(clientUser, '/profile'), isNull);
      expect(evaluateRedirect(closerUser, '/profile'), isNull);
      expect(evaluateRedirect(riderUser, '/profile'), isNull);

      expect(evaluateRedirect(dcUser, '/notifications'), isNull);
      expect(evaluateRedirect(clientUser, '/notifications'), isNull);
      expect(evaluateRedirect(closerUser, '/notifications'), isNull);
      expect(evaluateRedirect(riderUser, '/notifications'), isNull);

      expect(evaluateRedirect(dcUser, '/orders/NX-8821'), isNull);
      expect(evaluateRedirect(clientUser, '/orders/NX-8821'), isNull);
      expect(evaluateRedirect(closerUser, '/orders/NX-8821'), isNull);
      expect(evaluateRedirect(riderUser, '/orders/NX-8821'), isNull);
    });
  });
}
