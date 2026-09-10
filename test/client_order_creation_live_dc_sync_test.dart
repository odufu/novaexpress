import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_create_order_modal.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client Order Creation & Live DC Console Dispatch Workflow', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer();
      container.read(authProvider);
      container.read(ordersProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      container.dispose();
    });

    test('1. System Auto-Assign Live: Client order matches DC & Rider, appears live in ordersProvider as assigned', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Create order with autoAssignRider = true (default) targeting Abuja / AMAC
      final createdOrder = await clientNotifier.createOrder(
        customerName: 'Chief Kenneth Okonkwo',
        customerPhone: '08031234567',
        customerAltPhone: '08129876543',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        deliveryAddress: 'Plot 72, Adetokunbo Ademola Crescent, Wuse 2, Abuja',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea',
        quantity: 2,
        totalAmount: 32000.0,
        packageName: '2 Packs Value Pack',
        paymentType: 'Pay on Delivery (Cash/POS)',
        autoAssignRider: true,
        closerName: 'Zainab Closer',
        closerCode: 'CLS-001',
      );

      // Verify created order properties
      expect(createdOrder.customerName, 'Chief Kenneth Okonkwo');
      expect(createdOrder.status, 'assigned');
      expect(createdOrder.deliveryAgentId, isNotNull);
      expect(createdOrder.deliveryAgentName, 'Emeka Rider');
      expect(createdOrder.deliveryAgentCode, 'PDA-7000');
      expect(createdOrder.distributionCenterId, '22222222-2222-4222-8222-222222222222');
      expect(createdOrder.closerName, 'Zainab Closer');
      expect(createdOrder.fulfillmentType, 'client_package');

      // Verify order immediately appears in ordersProvider (live DC Console data source)
      final ordersState = container.read(ordersProvider);
      final matchInDc = ordersState.orders.where((o) => o.id == createdOrder.id || o.orderNumber == createdOrder.orderNumber);
      expect(matchInDc.isNotEmpty, isTrue, reason: 'Order must immediately appear live in OrdersProvider');
      
      final dcOrder = matchInDc.first;
      expect(dcOrder.customerName, 'Chief Kenneth Okonkwo');
      expect(dcOrder.deliveryAgentName, 'Emeka Rider');
      expect(dcOrder.deliveryAgentCode, 'PDA-7000');
      expect(dcOrder.status, anyOf('assigned', 'in_transit'));
    });

    test('2. DC Hub Pool: Client order routes unassigned, DC manager assigns rider live, client portal updates', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Create order with autoAssignRider = false (DC Pool mode)
      final poolOrder = await clientNotifier.createOrder(
        customerName: 'Hajiya Fatima Aliyu',
        customerPhone: '08098765432',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        deliveryAddress: 'House 14, 4th Avenue, Gwarinpa, Abuja',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea',
        quantity: 3,
        totalAmount: 45000.0,
        packageName: '3 Packs Family Bundle',
        paymentType: 'Pay on Delivery (Cash/POS)',
        autoAssignRider: false, // Directed to DC unassigned pool
        closerName: 'Ibrahim Closer',
        closerCode: 'CLS-002',
      );

      // 1. Order should be in pending_dispatch and have NO rider assigned
      expect(poolOrder.customerName, 'Hajiya Fatima Aliyu');
      expect(poolOrder.status, 'pending_dispatch');
      expect(poolOrder.deliveryAgentId, isNull);
      expect(poolOrder.deliveryAgentName, isNull);

      // 2. Verify order appears in ordersProvider as unassigned
      final ordersNotifier = container.read(ordersProvider.notifier);
      final ordersState = container.read(ordersProvider);
      final liveDcOrder = ordersState.orders.firstWhere(
        (o) => o.id == poolOrder.id || o.orderNumber == poolOrder.orderNumber,
      );
      expect(liveDcOrder.isUnassigned, isTrue);

      // 3. DC Supervisor assigns rider in DC Console
      final assignSuccess = await ordersNotifier.assignOrderToRider(
        orderId: liveDcOrder.id,
        riderId: 'b1111111-1111-4111-8111-111111111111',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
      );
      expect(assignSuccess, isTrue);

      // 4. Verify order in ordersProvider is now in_transit with Emeka Rider
      final updatedDcOrders = container.read(ordersProvider).orders;
      final dispatchedOrder = updatedDcOrders.firstWhere((o) => o.id == poolOrder.id);
      expect(dispatchedOrder.status, 'in_transit');
      expect(dispatchedOrder.deliveryAgentId, 'b1111111-1111-4111-8111-111111111111');
      expect(dispatchedOrder.deliveryAgentName, 'Emeka Rider');
      expect(dispatchedOrder.deliveryAgentCode, 'PDA-7000');

      // 5. Verify bi-directional sync: ClientPortalProvider automatically receives the assignment update
      final clientOrders = container.read(clientPortalProvider).orders;
      final synchedClientOrder = clientOrders.firstWhere((o) => o.id == poolOrder.id);
      expect(synchedClientOrder.status, 'in_transit');
      expect(synchedClientOrder.deliveryAgentName, 'Emeka Rider');
    });

    testWidgets('3. ClientCreateOrderModal renders dispatch mode selectors and toggles state correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: ClientCreateOrderModal(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Section 3 title exists
      expect(find.text('3. Destination & Multi-Zone Dispatch'), findsOneWidget);

      // Verify the two dispatch mode options are rendered
      expect(find.text('⚡ System Auto-Assign'), findsOneWidget);
      expect(find.text('🏢 DC Hub Pool'), findsOneWidget);

      // Tap on DC Hub Pool
      final dcPoolTile = find.text('🏢 DC Hub Pool');
      await tester.ensureVisible(dcPoolTile);
      await tester.tap(dcPoolTile);
      await tester.pumpAndSettle();

      // Scroll slightly to reveal preview banner
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Verify the dynamic dispatch preview reflects DC Hub Pool
      expect(find.textContaining('Order will appear live in the DC Unassigned Pool'), findsOneWidget);

      // Tap back on Auto-Assign Live
      final autoAssignTile = find.text('⚡ System Auto-Assign');
      await tester.ensureVisible(autoAssignTile);
      await tester.tap(autoAssignTile);
      await tester.pumpAndSettle();

      // Scroll slightly to reveal preview banner
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Verify dynamic preview switches back to live rider routing
      expect(find.textContaining('Assigned Rider:'), findsOneWidget);
    });
  });
}
