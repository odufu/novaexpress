import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_edit_order_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testOrder = OrderEntity(
    id: 'test-order-uuid-101',
    orderNumber: 'NOV-2026-9876543',
    customerName: 'Chief Dan Hans Okon',
    customerPhone: '08085057563',
    customerAltPhone: '08123456789',
    deliveryState: 'Federal Capital Territory',
    deliveryCity: 'Abuja Municipal (AMAC)',
    deliveryAddress: 'Plot 402, Constitution Avenue, Central Business District',
    landmark: 'Near Total Filling Station',
    lga: 'Abuja Municipal (AMAC)',
    productName: 'Grazer Herbal Detox Tea',
    status: 'assigned',
    quantity: 5,
    paidQuantity: 4,
    freeQuantity: 1,
    basePrice: 57000.0,
    upsellAmount: 0.0,
    totalAmount: 57000.0,
    paymentType: 'Pay on Delivery (Cash/POS)',
    paymentStatus: 'pending',
    fulfillmentType: 'distributed_inventory',
    clientName: 'Novacare Limited',
    clientCompany: 'Novacare Limited',
    clientDeliveryFee: 4500.0,
    agentEntitlement: 2000.0,
    packageDealName: '4 Boxes + 1 Free (4 + 1 Free)',
    remittanceStatus: 'unremitted',
    financialSettlementStatus: 'pending_remittance',
    transportFee: 0.0,
    createdAt: DateTime(2026, 10, 19),
  );

  Widget createTestWidget({required Size screenSize, required OrderEntity order}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            padding: EdgeInsets.zero,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: ClientEditOrderModal(order: order),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ClientEditOrderModal Responsive Layout & No Overflows', () {
    testWidgets('1. Compact mobile viewport (360x740) renders cleanly with 0 overflow exceptions', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(360, 740),
        order: testOrder,
      ));
      await tester.pumpAndSettle();

      // Check for layout overflow exceptions
      expect(tester.takeException(), isNull, reason: 'Must not throw any layout overflow exception on 360px mobile');

      // Verify Header Elements
      expect(find.text('Edit Order & Packages'), findsOneWidget);
      expect(find.text('NOV-2026-9876543'), findsOneWidget);

      // Verify Customer Inputs
      expect(find.text('Chief Dan Hans Okon'), findsOneWidget);
      expect(find.text('08085057563'), findsOneWidget);

      // Verify Delivery Destination Fields
      expect(find.text('Federal Capital Territory'), findsWidgets);
      expect(find.text('Abuja Municipal (AMAC)'), findsWidgets);

      // Verify Quantity Accounting Fields
      expect(find.text('Quantity & Units Accounting'), findsOneWidget);
      expect(find.text('Total Qty'), findsOneWidget);
      expect(find.text('Paid Qty'), findsOneWidget);
      expect(find.text('Free Bonus'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('2. Wide desktop viewport (800x900) renders cleanly with 0 overflow exceptions', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(800, 900),
        order: testOrder,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must not throw any layout overflow on desktop');
      expect(find.text('Save Changes & Deal'), findsOneWidget);
    });

    testWidgets('3. Quantity calculations live-sync correctly in modal', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(500, 800),
        order: testOrder,
      ));
      await tester.pumpAndSettle();

      // Total quantity controller text field should initially have "5"
      final totalFinder = find.widgetWithText(TextFormField, 'Total Qty');
      expect(totalFinder, findsOneWidget);

      // Paid quantity field
      final paidFinder = find.widgetWithText(TextFormField, 'Paid Qty');
      expect(paidFinder, findsOneWidget);

      // Enter '3' into Paid Units
      await tester.enterText(paidFinder, '3');
      await tester.pumpAndSettle();

      // Free Units is 1, so total should automatically recalculate to 3 + 1 = 4
      final totalField = tester.widget<TextFormField>(totalFinder);
      expect(totalField.controller?.text, equals('4'));
    });
  });
}
