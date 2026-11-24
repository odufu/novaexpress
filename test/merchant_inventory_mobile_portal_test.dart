import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/merchant_inventory_models.dart';
import 'package:novexps/features/client_portal/presentation/pages/merchant_inventory_mobile_portal_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_inventory_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_create_inbound_request_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_log_agent_sales_modal.dart';

void main() {
  group('Merchant Stock Keeper / Inventory Officer Console Tests', () {
    test('1. UserEntity correctly resolves role, home console route and appRouteRedirect', () {
      const officerUser = UserEntity(
        id: 'stk-user-01',
        email: 'inventory@novacare.com',
        firstName: 'Amaka',
        lastName: 'Obi',
        phone: '08033221100',
        role: 'merchant_inventory_officer',
        clientId: 'client-novacare-01',
        clientCompanyName: 'Novacare Limited',
      );

      expect(officerUser.isMerchantInventoryOfficer, isTrue);
      expect(officerUser.isClient, isTrue);
      expect(officerUser.roleDescription, equals('Merchant Inventory Officer'));
      expect(officerUser.homeConsoleRoute, equals('/merchant-inventory'));

      // Test route redirect for unauthenticated vs authenticated
      final redirectLogin = appRouteRedirect(
        authState: const AuthState(user: null),
        matchedLocation: '/merchant-inventory',
      );
      expect(redirectLogin, equals('/login'));

      final redirectAuthed = appRouteRedirect(
        authState: const AuthState(
          user: officerUser,
        ),
        matchedLocation: '/login',
      );
      expect(redirectAuthed, equals('/merchant-inventory'));

      final allowedOnInventory = appRouteRedirect(
        authState: const AuthState(
          user: officerUser,
        ),
        matchedLocation: '/merchant-inventory',
      );
      expect(allowedOnInventory, isNull);
    });

    test('2. MerchantInventoryNotifier initial state has products, multi-DC breakdown and partner agents', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(merchantInventoryProvider);

      expect(state.products, isNotEmpty);
      expect(state.products.length, greaterThanOrEqualTo(4));
      expect(state.agents, isNotEmpty);
      expect(state.inboundShipments, isNotEmpty);
      expect(state.salesRecords, isNotEmpty);

      // Verify Novacare products
      final grazer = state.products.firstWhere((p) => p.sku == 'NOVA-GRAZER-01');
      expect(grazer.name, contains('Grazer Herbal Tea'));
      expect(grazer.dcShelves.containsKey('Abuja Central DC'), isTrue);
      expect(grazer.dcShelves.containsKey('Lagos Central DC'), isTrue);
      expect(grazer.dcShelves['Abuja Central DC'], equals(1428));
      expect(grazer.dcShelves['Lagos Central DC'], equals(7467));

      // Verify agents include internal fleet and real 3PLs
      expect(state.agents.any((a) => a.agentType.contains('Fleet')), isTrue);
      expect(state.agents.any((a) => a.name.contains('ADICHA LOGISTICS')), isTrue);
      expect(state.agents.any((a) => a.name.contains('Victor Ogbenyi Logistics')), isTrue);
    });

    test('3. Create Inbound Stock Request dispatches consignment with carrier & driver metadata', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(merchantInventoryProvider.notifier);
      final initialCount = container.read(merchantInventoryProvider).inboundShipments.length;

      final shipment = await notifier.createInboundShipment(
        productId: 'prod-grazer-01',
        targetDcId: 'dc-abuja-central',
        targetDcName: 'Abuja Central DC',
        expectedQuantity: 600,
        waybillNumber: 'WB-TEST-2026-999',
        carrierDriverName: 'Garba Shehu',
        carrierPhone: '08039988776',
        carrierPlate: 'KAD-101-AA',
        notes: 'Handled with care, factory fresh',
      );

      expect(shipment.waybillNumber, equals('WB-TEST-2026-999'));
      expect(shipment.expectedQuantity, equals(600));
      expect(shipment.isInTransit, isTrue);
      expect(shipment.carrierDriverName, equals('Garba Shehu'));

      final state = container.read(merchantInventoryProvider);
      expect(state.inboundShipments.length, equals(initialCount + 1));
      expect(state.inboundShipments.first.waybillNumber, equals('WB-TEST-2026-999'));
    });

    test('4. DC Stock Officer reception logs good units to shelves and isolates defect categories to quarantine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(merchantInventoryProvider.notifier);

      // Verify product initial stock
      var product = container.read(merchantInventoryProvider).products.firstWhere((p) => p.sku == 'NOVA-GRAZER-01');
      final initialAbujaShelves = product.dcShelves['Abuja Central DC']!;
      final initialAbujaQuarantine = product.dcDefectQuarantine['Abuja Central DC'] ?? 0;

      // Create new consignment
      final shipmentId = 'inbound-test-defect';
      notifier.state = notifier.state.copyWith(
        inboundShipments: [
          MerchantInboundShipment(
            id: shipmentId,
            waybillNumber: 'WB-DEFECT-TEST',
            merchantId: '00000000-0000-4000-8000-791731264594',
            merchantName: 'Novacare Limited',
            productId: 'prod-grazer-01',
            productName: 'Grazer Herbal Tea (Weight lose and Leaver Detox tea)',
            sku: 'NOVA-GRAZER-01',
            targetDcId: 'dc-abuja-central',
            targetDcName: 'Abuja Central DC',
            expectedQuantity: 500,
            status: 'in_transit',
            dispatchedAt: DateTime.now(),
          ),
          ...notifier.state.inboundShipments,
        ],
      );

      // Simulate DC Officer physical reception: 480 good accepted, 20 spoilt with defect breakdown
      notifier.processDcConsignmentReception(
        shipmentId: shipmentId,
        acceptedQuantity: 480,
        spoiltQuantity: 20,
        defectBreakdown: const {
          DefectCategory.brokenSeal: 12,
          DefectCategory.puncturedPackaging: 8,
        },
        dcInspectorName: 'Ahmed Bello (DC Stock Admin)',
        stagingBay: 'Bay B-04',
        notes: 'Tamper seals broken on 12 units, bottle puncture on 8 units',
      );

      final state = container.read(merchantInventoryProvider);
      final receivedShipment = state.inboundShipments.firstWhere((s) => s.id == shipmentId);

      expect(receivedShipment.status, equals('received_with_defects'));
      expect(receivedShipment.acceptedQuantity, equals(480));
      expect(receivedShipment.spoiltQuantity, equals(20));
      expect(receivedShipment.defectBreakdown[DefectCategory.brokenSeal], equals(12));
      expect(receivedShipment.defectBreakdown[DefectCategory.puncturedPackaging], equals(8));

      // Verify ONLY the 480 accepted units enter the physical DC shelves
      product = state.products.firstWhere((p) => p.sku == 'NOVA-GRAZER-01');
      expect(product.dcShelves['Abuja Central DC'], equals(initialAbujaShelves + 480));
      // And defective units enter quarantine
      expect(product.dcDefectQuarantine['Abuja Central DC'], equals(initialAbujaQuarantine + 20));
    });

    test('5. Agent Daily Sales Logging balances stock and executes ambush audit calculation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(merchantInventoryProvider.notifier);

      // Starting custody for an agent with NOVA-GRAZER-01
      final agent = container.read(merchantInventoryProvider).agents.firstWhere((a) => (a.productCustody['NOVA-GRAZER-01'] ?? 0) > 0);
      final opening = agent.productCustody['NOVA-GRAZER-01']!;
      expect(opening, greaterThan(0));

      // Case A: Normal Sales Log: 10 sold, 2 returned, 0 replenished -> Closing = opening - 10 - 2
      final recordA = notifier.recordDailySalesAndBalance(
        agentId: agent.id,
        sku: 'NOVA-GRAZER-01',
        unitsSold: 10,
        unitsReturned: 2,
        replenishedUnits: 0,
        notes: 'Maitama and Wuse zone deliveries',
        loggedBy: 'Amaka Obi',
      );

      final expectedClosingA = opening - 10 - 2;
      expect(recordA.closingCustody, equals(expectedClosingA));
      var updatedAgent = container.read(merchantInventoryProvider).agents.firstWhere((a) => a.id == agent.id);
      expect(updatedAgent.productCustody['NOVA-GRAZER-01'], equals(expectedClosingA));

      // Case B: Ambush Stock Take within ±5% margin:
      final recordB = notifier.recordDailySalesAndBalance(
        agentId: agent.id,
        sku: 'NOVA-GRAZER-01',
        unitsSold: 0,
        unitsReturned: 0,
        physicalAuditCount: expectedClosingA,
        loggedBy: 'Amaka Obi',
      );

      expect(recordB.closingCustody, equals(expectedClosingA));
      expect(recordB.physicalAuditCount, equals(expectedClosingA));
      expect(recordB.discrepancyFlagged, isFalse);

      // Case C: Ambush Stock Take EXCEEDING ±5% margin:
      final auditBadCount = (expectedClosingA * 0.75).round();
      final recordC = notifier.recordDailySalesAndBalance(
        agentId: agent.id,
        sku: 'NOVA-GRAZER-01',
        unitsSold: 0,
        unitsReturned: 0,
        physicalAuditCount: auditBadCount,
        loggedBy: 'Amaka Obi',
      );

      expect(recordC.discrepancyFlagged, isTrue);
      expect(recordC.discrepancyNotes, contains('exceeds the ±5% investigation threshold'));
    });

    testWidgets('6. MerchantInventoryMobilePortalPage renders on mobile viewport with tabs & bottom nav', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MerchantInventoryMobilePortalPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Novacare Limited'), findsOneWidget);
      expect(find.text('STOCK OPS'), findsOneWidget);

      // KPI banner chips
      expect(find.textContaining('DC Shelves:'), findsOneWidget);
      expect(find.textContaining('In Agent Custody:'), findsOneWidget);

      // Bottom Navigation items
      expect(find.text('DC Shelves'), findsOneWidget);
      expect(find.text('Inbound DC'), findsOneWidget);
      expect(find.text('Agent Sales'), findsOneWidget);

      // Products visible on Tab 0
      expect(find.textContaining('Grazer Herbal Tea'), findsOneWidget);

      // Switch to Tab 1: Inbound DC
      await tester.tap(find.text('Inbound DC'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Inbound Consignments'), findsOneWidget);
      expect(find.text('New Consignment'), findsOneWidget);

      // Switch to Tab 2: Agent Sales
      await tester.tap(find.text('Agent Sales'));
      await tester.pumpAndSettle();

      expect(find.text('Partner Agent Custody'), findsOneWidget);
      expect(find.text('Log Sales'), findsOneWidget);
      expect(find.textContaining('NovaXpress Logistics (Internal Fleet)'), findsWidgets);
      expect(find.textContaining('ADICHA LOGISTICS'), findsWidgets);
    });

    testWidgets('7. Create Inbound Request modal displays form and validates inputs', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MerchantCreateInboundRequestModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Inbound Stock Request'), findsOneWidget);
      expect(find.text('Select Product SKU *'), findsOneWidget);
      expect(find.text('Destination Distribution Center (DC) *'), findsOneWidget);
      expect(find.text('Units Shipped *'), findsOneWidget);
      expect(find.text('Waybill / Ref Number *'), findsOneWidget);
      expect(find.text('Dispatch Inbound Consignment'), findsOneWidget);
    });

    testWidgets('8. Log Agent Sales modal displays balancing equation and ambush audit', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MerchantLogAgentSalesModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log Daily Sales & Balance Stock'), findsOneWidget);
      expect(find.text('Select Delivery Agent / Partner *'), findsOneWidget);
      expect(find.text('Starting Agent Custody'), findsOneWidget);
      expect(find.text('= Balanced Closing Custody'), findsOneWidget);
      expect(find.text('Random Ambush Stock-Taking (Audit Mode)'), findsOneWidget);
      expect(find.text('Post Daily Sales & Balance Custody'), findsOneWidget);
    });
  });
}
