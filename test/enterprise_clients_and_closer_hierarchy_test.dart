import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise Client Architecture & Grand DC Onboarding Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Grand DC can register an Enterprise Client with 250 closer cap & a Standard Merchant', () async {
      final dcNotifier = container.read(dcConsoleProvider.notifier);

      // A. Grand DC registers Enterprise Client: Novacale Limited
      final enterpriseClient = await dcNotifier.createClient(
        companyName: 'Novacale Healthcare Global',
        contactPerson: 'Dr. Chuka Okafor',
        email: 'chuka@novacale.ng',
        phone: '08034455667',
        address: 'Plot 12, Commercial Avenue, CBD, Abuja',
        city: 'Abuja',
        stateName: 'Federal Capital Territory',
        tier: 'enterprise',
        closerLimit: 200,
      );

      expect(enterpriseClient.isEnterprise, isTrue);
      expect(enterpriseClient.closerLimit, equals(200));
      expect(enterpriseClient.tier, equals('enterprise'));
      expect(enterpriseClient.code, contains('CLI-'));

      // B. Grand DC registers Standard Single Merchant: Mama Organic Foods
      final standardClient = await dcNotifier.createClient(
        companyName: 'Mama Organic Foods',
        contactPerson: 'Mrs. Stella Balogun',
        email: 'stella@mamaorganic.ng',
        phone: '08023344556',
        address: '14 Allen Avenue, Ikeja, Lagos',
        city: 'Ikeja',
        stateName: 'Lagos State',
        tier: 'standard_merchant',
        closerLimit: 0,
      );

      expect(standardClient.isEnterprise, isFalse);
      expect(standardClient.closerLimit, equals(0));
      expect(standardClient.tier, equals('standard_merchant'));

      // Check DC Console State
      final dcState = container.read(dcConsoleProvider);
      expect(dcState.clients.any((c) => c.companyName == 'Novacale Healthcare Global'), isTrue);
      expect(dcState.clients.any((c) => c.companyName == 'Mama Organic Foods'), isTrue);
    });

    test('2. Enterprise Client Admin can onboard closers and generate unique closer codes', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Onboard Closer 1: Amaka Chioma
      final closer1 = await clientNotifier.createCloser(
        fullName: 'Amaka Chioma',
        email: 'closer.amaka@novacale.ng',
        phone: '08021122334',
        dailyCallTarget: 50,
        commissionRate: 500.0,
      );

      expect(closer1.fullName, equals('Amaka Chioma'));
      expect(closer1.closerCode, contains('CLS-NOVA-'));
      expect(closer1.dailyCallTarget, equals(50));
      expect(closer1.commissionRate, equals(500.0));
      expect(closer1.isActive, isTrue);

      // Onboard Closer 2: Ibrahim Musa
      final closer2 = await clientNotifier.createCloser(
        fullName: 'Ibrahim Musa',
        email: 'ibrahim.musa@novacale.ng',
        phone: '08035566778',
        dailyCallTarget: 60,
        commissionRate: 500.0,
      );

      expect(closer2.fullName, equals('Ibrahim Musa'));
      expect(closer2.closerCode, contains('CLS-NOVA-'));
      expect(closer1.closerCode, isNot(equals(closer2.closerCode)));

      final clientState = container.read(clientPortalProvider);
      expect(clientState.closers.length, greaterThanOrEqualTo(2));
    });

    test('3. Closer lead management & calling status updates', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Create new customer lead
      final lead = await clientNotifier.createLead(
        customerName: 'Chief Emmanuel Adeleke',
        customerPhone: '08033221144',
        customerAddress: 'Plot 14, Ahmadu Bello Way, Area 11, Garki, Abuja',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        productInterest: 'Grazer Tea',
        packageInterest: '2 Packs Promo Deal',
        callNotes: 'Prefers delivery before 12 PM',
      );

      expect(lead.customerName, equals('Chief Emmanuel Adeleke'));
      expect(lead.status, equals('new_lead'));
      expect(lead.isNew, isTrue);

      // Closer dials lead -> status moves to calling
      await clientNotifier.updateLeadStatus(lead.id, 'calling', notes: 'Spoke with customer, confirming address');
      var updatedLeads = container.read(clientPortalProvider).leads;
      var currentLead = updatedLeads.firstWhere((l) => l.id == lead.id);
      expect(currentLead.status, equals('calling'));
      expect(currentLead.isCalling, isTrue);

      // Customer confirms order -> status moves to confirmed
      await clientNotifier.updateLeadStatus(lead.id, 'confirmed', notes: 'Confirmed! Delivery approved for tomorrow');
      updatedLeads = container.read(clientPortalProvider).leads;
      currentLead = updatedLeads.firstWhere((l) => l.id == lead.id);
      expect(currentLead.status, equals('confirmed'));
      expect(currentLead.isConfirmed, isTrue);
    });

    test('4. 1-Tap Convert Lead to Order auto-routes to matching DC and Rider with Closer attribution', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // 1. Create confirmed lead
      final lead = await clientNotifier.createLead(
        customerName: 'Mrs. Folashade Bakare',
        customerPhone: '08055667788',
        customerAddress: 'Flat 4B, Hillview Estate, Guzape, Abuja',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        productInterest: 'Grazer Tea',
        packageInterest: '3 Packs Family Bundle',
        callNotes: 'Confirmed 3 packs bundle',
      );

      // 2. Closer 1-Taps "Convert to Order"
      final order = await clientNotifier.convertLeadToOrder(
        lead: lead,
        productId: 'prod-grazer-01',
        productName: 'Grazer Tea',
        packageName: '3 Packs Family Bundle',
        quantity: 3,
        totalAmount: 50000.0,
        paymentType: 'Pay on Delivery (Cash/POS)',
      );

      // 3. Verify Order Entity Properties & 2-Tier Automated Dispatch Routing
      expect(order.orderNumber, startsWith('NOV-'));
      expect(order.customerName, equals('Mrs. Folashade Bakare'));
      expect(order.deliveryState, equals('Federal Capital Territory'));
      expect(order.lga, equals('Abuja Municipal (AMAC)'));
      expect(order.totalAmount, equals(50000.0));
      expect(order.packageDealName, equals('3 Packs Family Bundle'));

      // Verify Automated DC Assignment (Wuse Central DC) and Rider Auto-Assignment (Emeka Rider)
      expect(order.distributionCenterId, isNotNull);
      expect(order.deliveryAgentName, contains('Emeka Rider'));
      expect(order.status, equals('assigned'));

      // Verify Closer Attribution Stamped on Order
      expect(order.closerName, isNotNull);
      expect(order.closerCode, isNotNull);
      expect(order.leadId, equals(lead.id));

      // 4. Verify Lead Status Updated to 'order_created' & linked convertedOrderId
      final clientState = container.read(clientPortalProvider);
      final convertedLead = clientState.leads.firstWhere((l) => l.id == lead.id);
      expect(convertedLead.status, equals('order_created'));
      expect(convertedLead.isOrderCreated, isTrue);
      expect(convertedLead.convertedOrderId, equals(order.id));
    });

    test('5. Closer Performance Scoring & Leaderboard Analytics', () {
      const closer = ClientCloser(
        id: 'cls-test-101',
        clientId: '33333333-3333-4333-8333-333333333333',
        closerCode: 'CLS-NOVA-001',
        fullName: 'Amaka Chioma',
        email: 'closer.amaka@novacale.ng',
        phone: '08021122334',
        dailyCallTarget: 50,
        totalLeadsAssigned: 50,
        totalLeadsConfirmed: 40,
        totalOrdersBooked: 35,
        totalOrdersDelivered: 30,
        commissionRate: 500.0,
      );

      // Conversion Rate: (35 / 50) * 100 = 70.0%
      expect(closer.conversionRate, equals(70.0));

      // Delivery Success Rate: (30 / 35) * 100 = 85.71%
      expect(closer.deliverySuccessRate, closeTo(85.71, 0.1));

      // Total Earned Commission: 30 * 500.0 = ₦15,000
      expect(closer.totalEarnedCommission, equals(15000.0));
    });

    test('6. UserEntity Closer Helpers & Role Checks', () {
      const closerUser = UserEntity(
        id: 'user-cls-01',
        email: 'closer.amaka@novacale.ng',
        firstName: 'Amaka',
        lastName: 'Chioma',
        phone: '08021122334',
        role: 'closer',
        closerId: 'cls-test-101',
        closerCode: 'CLS-NOVA-001',
        clientCompanyName: 'Novacale Limited',
      );

      expect(closerUser.isCloser, isTrue);
      expect(closerUser.isClient, isTrue); // Router allows access to client portal
      expect(closerUser.isClientAdmin, isFalse);
      expect(closerUser.closerCode, equals('CLS-NOVA-001'));

      const clientAdmin = UserEntity(
        id: 'user-admin-01',
        email: 'client.novacale@novaexpress.ng',
        firstName: 'Chuka',
        lastName: 'Okafor',
        phone: '08034455667',
        role: 'client',
        clientCompanyName: 'Novacale Limited',
      );

      expect(clientAdmin.isClientAdmin, isTrue);
      expect(clientAdmin.isCloser, isFalse);
      expect(clientAdmin.isClient, isTrue);
    });
  });
}
