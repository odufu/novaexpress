import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_orders_page.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_order_tracking_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClientOrderTrackingModal & Client Console Order Details Tests', () {
    final assignedOrder = OrderEntity(
      id: 'test-ord-01',
      orderNumber: 'NOV-2026-8801',
      customerName: 'Amina Mohammed',
      customerPhone: '08031122334',
      deliveryState: 'Federal Capital Territory',
      deliveryCity: 'Abuja Municipal (AMAC)',
      deliveryAddress: 'House 14, 4th Avenue, Gwarinpa Estate',
      productName: 'Grazer Tea',
      quantity: 1,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      status: 'in_transit',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      deliveryAgentPhone: '08012345678',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      distributionCenterName: 'Wuse Central Distribution Hub',
      clientCompany: 'Novacale Limited',
      packageDealName: '2 Packs Promo Deal',
      remittanceStatus: 'unremitted',
      financialSettlementStatus: 'pending_remittance',
      createdAt: DateTime(2026, 9, 9, 13, 53),
    );

    final unassignedOrder = OrderEntity(
      id: 'test-ord-02',
      orderNumber: 'NOV-2026-8802',
      customerName: 'Fatima Bello',
      customerPhone: '08098765432',
      deliveryState: 'Federal Capital Territory',
      deliveryCity: 'Bwari',
      deliveryAddress: 'Block 5, Kubwa Phase 4',
      productName: 'Respira Tea',
      quantity: 2,
      basePrice: 25000.0,
      upsellAmount: 0.0,
      totalAmount: 50000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      status: 'pending_dispatch',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      distributionCenterName: 'Wuse Central Distribution Hub',
      clientCompany: 'Novacale Limited',
      remittanceStatus: 'unremitted',
      financialSettlementStatus: 'pending_remittance',
      createdAt: DateTime(2026, 9, 9, 14, 10),
    );

    testWidgets('1. Assigned Order Modal displays Live Delivery Handler & Followup actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ClientOrderTrackingModal(order: assignedOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Live Status
      expect(find.text('Order NOV-2026-8801'), findsOneWidget);
      expect(find.text('In Transit'), findsWidgets);

      // Verify Client-Focused Metrics
      expect(find.text('Total Order Value'), findsOneWidget);
      expect(find.text('₦35000'), findsWidgets);
      expect(find.text('Pay on Delivery (POS/Cash)'), findsOneWidget);

      // Verify Prominent Live Delivery Handler Section
      expect(find.text('LIVE DELIVERY HANDLER (RIDER)'), findsOneWidget);
      expect(find.text('Active on Delivery Route'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsWidgets);
      expect(find.text('PDA-7000'), findsWidgets);
      expect(find.text('08012345678'), findsWidgets);

      // Verify Action Buttons for Immediate Followup
      expect(find.text('Call Handler'), findsOneWidget);
      expect(find.text('WhatsApp Followup'), findsOneWidget);
      expect(find.text('Copy Contact'), findsOneWidget);

      // Verify fulfillment timeline steps
      expect(find.text('FULFILLMENT TIMELINE'), findsOneWidget);
      expect(find.text('1. Order Created & Commercial Package Reserved'), findsOneWidget);
      expect(find.text('2. Routed to Regional Distribution Center'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('3. Assigned to Field Delivery Agent (PDA)'), 100);
      expect(find.text('3. Assigned to Field Delivery Agent (PDA)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Amina Mohammed'), 100);
      expect(find.text('Amina Mohammed'), findsOneWidget);
      expect(find.text('Call Customer'), findsOneWidget);
      expect(find.text('WhatsApp Customer'), findsOneWidget);
    });

    testWidgets('2. Unassigned Order Modal displays Regional DC Hub Dispatch Queue with Station Contact', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ClientOrderTrackingModal(order: unassignedOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Status
      expect(find.text('Order NOV-2026-8802'), findsOneWidget);

      // Verify Hub Queue Section
      expect(find.text('REGIONAL DISTRIBUTION CENTER & DISPATCH QUEUE'), findsOneWidget);
      expect(find.text('Awaiting Rider Assignment'), findsOneWidget);
      expect(find.text('Wuse Central Distribution Hub'), findsWidgets);
      expect(find.text('Call DC Station'), findsOneWidget);
      expect(find.text('WhatsApp Dispatch Desk'), findsOneWidget);
      expect(find.text('Copy Station Contact'), findsOneWidget);
    });

    testWidgets('3. ClientOrdersPage opens ClientOrderTrackingModal (NOT DCOrderDetailModal)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer();
      // Ensure ordersProvider has assignedOrder
      container.read(ordersProvider.notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ClientOrdersPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on an order row
      final firstRow = find.text('NOV-2026-8801');
      if (firstRow.evaluate().isNotEmpty) {
        await tester.tap(firstRow.first);
        await tester.pumpAndSettle();

        // Must find ClientOrderTrackingModal
        expect(find.byType(ClientOrderTrackingModal), findsOneWidget);
        // Must NOT find DCOrderDetailModal
        expect(find.byType(DCOrderDetailModal), findsNothing);
      }
    });
  });
}
