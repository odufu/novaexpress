import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier([List<OrderEntity> orders = const []])
      : super(OrdersState(orders: orders, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier([List<StockItemEntity> items = const []])
      : super(StockState(stockItems: items, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  _MockDCConsoleNotifier()
      : super(const DCConsoleState(
          drivers: [
            DCFleetDriver(
              id: 'drv-1',
              driverCode: 'PDA-7000',
              name: 'Emeka Okafor',
              phone: '+234 803 111 2222',
              avatarUrl: '',
              vehicleModel: 'Bajaj Boxer 150',
              vehiclePlate: 'ABJ-452-XY',
              vehicleType: 'Motorcycle',
              status: 'active',
              assignedZone: 'Wuse 2 / Maitama',
              totalAssignedOrders: 15,
              completedOrders: 12,
              routeProgressPercent: 80.0,
              efficiencyRating: 4.9,
              cashInCustody: 45000,
              itemsInCustody: 3,
            ),
          ],
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Order Entity & Remittance Computation Tests', () {
    test('Correctly computes netMerchantSettlement from totalAmount, agentEntitlement, and transportFee', () {
      final order = OrderEntity(
        id: 'ord-1',
        orderNumber: 'TRK-9001',
        customerName: 'Amina Yusuf',
        customerPhone: '+2348011112222',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '14 Adetokunbo Ademola Crescent',
        productName: 'Respira Detox Tea',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        basePrice: 50000,
        upsellAmount: 5000,
        totalAmount: 55000,
        agentEntitlement: 2500,
        transportFee: 1500,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'standard_delivery',
        status: 'in_transit',
        createdAt: DateTime(2026, 8, 27, 8, 0),
      );

      expect(order.totalAmount, 55000.0);
      expect(order.agentEntitlement, 2500.0);
      expect(order.transportFee, 1500.0);
      // Net = 55,000 - 2,500 - 1,500 = 51,000
      expect(order.netMerchantSettlement, 51000.0);
      expect(order.isCashPod, isTrue);
      expect(order.isDirectTransfer, isFalse);
    });

    test('Correctly determines remittance status: cleared vs unremitted vs direct_transfer', () {
      final now = DateTime.now();

      // Case 1: Unremitted POD Cash Order in Rider Custody
      final unremittedOrder = OrderEntity(
        id: 'ord-101',
        orderNumber: 'TRK-101',
        customerName: 'Musa Bello',
        customerPhone: '+2348022223333',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Area 11 Garki',
        productName: 'Bio-Gold Pro Capsules',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 35000,
        upsellAmount: 0,
        totalAmount: 35000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        remittanceStatus: 'pending',
        fulfillmentType: 'standard_delivery',
        status: 'delivered',
        deliveredAt: now,
        createdAt: DateTime(2026, 8, 27, 8, 0),
      );

      expect(unremittedOrder.isDelivered, isTrue);
      expect(unremittedOrder.isCashPod, isTrue);
      expect(unremittedOrder.isRemitted, isFalse);
      expect(unremittedOrder.isUnremitted, isTrue);

      // Case 2: Cleared & Reconciled Order
      final clearedOrder = unremittedOrder.copyWith(
        remittanceStatus: 'cleared',
        remittanceReference: 'RMT-REC-8902',
        remittedAt: now,
      );

      expect(clearedOrder.isRemitted, isTrue);
      expect(clearedOrder.isUnremitted, isFalse);
      expect(clearedOrder.remittanceReference, 'RMT-REC-8902');

      // Case 3: Direct Bank / Paystack settled order
      final directOrder = unremittedOrder.copyWith(
        paymentType: 'direct_transfer',
        remittanceStatus: 'direct_transfer',
      );

      expect(directOrder.isDirectTransfer, isTrue);
      expect(directOrder.isCashPod, isFalse);
      expect(directOrder.isRemitted, isTrue);
      expect(directOrder.isUnremitted, isFalse);
    });

    test('Correctly serializes and deserializes OrderModel with full database linkage fields', () {
      final json = {
        'id': 'ord-model-1',
        'order_number': 'TRK-5544',
        'customer_name': 'Chukwuma Eze',
        'customer_phone': '+2348033334444',
        'customer_alt_phone': '+2348099998888',
        'delivery_state': 'FCT - Abuja',
        'delivery_city': 'Maitama',
        'delivery_address': 'Plot 402 Gana Street',
        'landmark': 'Near Transcorp Hilton',
        'lga': 'Abuja Municipal',
        'product_name': 'Respira Detox Tea',
        'product_sku': 'SKU-RESP-01',
        'bin_location': 'BIN-B2-04',
        'batch_number': 'LOT-2026-08',
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'base_price': 50000.0,
        'upsell_amount': 15000.0,
        'total_amount': 65000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'paid',
        'fulfillment_type': 'standard_delivery',
        'delivery_agent_id': 'drv-10',
        'delivery_agent_name': 'Ibrahim Sanni',
        'delivery_agent_code': 'PDA-7001',
        'delivery_agent_phone': '+2348055556666',
        'client_name': 'NovaCare Pharmaceuticals',
        'client_delivery_fee': 4000.0,
        'agent_entitlement': 2500.0,
        'transport_fee': 1500.0,
        'remittance_status': 'cleared',
        'remittance_reference': 'RMT-00402',
        'status': 'delivered',
        'is_location_verified': true,
        'location_confidence': 'high',
        'failure_reason': null,
        'created_at': '2026-08-27T10:00:00.000Z',
        'assigned_at': '2026-08-27T11:00:00.000Z',
        'delivered_at': '2026-08-27T14:30:00.000Z',
        'remitted_at': '2026-08-27T15:00:00.000Z',
      };

      final orderModel = OrderModel.fromJson(json);

      expect(orderModel.orderNumber, 'TRK-5544');
      expect(orderModel.customerName, 'Chukwuma Eze');
      expect(orderModel.productSku, 'SKU-RESP-01');
      expect(orderModel.binLocation, 'BIN-B2-04');
      expect(orderModel.batchNumber, 'LOT-2026-08');
      expect(orderModel.deliveryAgentName, 'Ibrahim Sanni');
      expect(orderModel.deliveryAgentCode, 'PDA-7001');
      expect(orderModel.totalAmount, 65000.0);
      expect(orderModel.agentEntitlement, 2500.0);
      expect(orderModel.transportFee, 1500.0);
      expect(orderModel.netMerchantSettlement, 61000.0);
      expect(orderModel.remittanceStatus, 'cleared');
      expect(orderModel.remittanceReference, 'RMT-00402');
      expect(orderModel.isLocationVerified, isTrue);

      final backToJson = orderModel.toJson();
      expect(backToJson['order_number'], 'TRK-5544');
      expect(backToJson['product_sku'], 'SKU-RESP-01');
      expect(backToJson['bin_location'], 'BIN-B2-04');
      expect(backToJson['batch_number'], 'LOT-2026-08');
      expect(backToJson['remittance_reference'], 'RMT-00402');
    });
  });

  group('DCOrderDetailModal Widget UI Tests', () {
    testWidgets('Renders all comprehensive order details, product custody, rider, and financial breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final sampleOrder = OrderEntity(
        id: 'ord-test-1',
        orderNumber: 'TRK-8924',
        customerName: 'Fatima Abdullahi',
        customerPhone: '+234 812 345 6789',
        customerAltPhone: '+234 809 988 7766',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '24 Adetokunbo Ademola Crescent, Wuse 2, Abuja',
        landmark: 'Opposite AP Plaza',
        productName: 'Respira Detox Tea',
        productSku: 'SKU-RESP-01',
        binLocation: 'BIN-A1-01',
        batchNumber: 'LOT-2026-08',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        basePrice: 50000,
        upsellAmount: 5000,
        totalAmount: 55000,
        agentEntitlement: 2500,
        transportFee: 1500,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        remittanceStatus: 'cleared',
        remittanceReference: 'RMT-00402',
        fulfillmentType: 'standard_delivery',
        deliveryAgentId: 'drv-1',
        deliveryAgentName: 'Emeka Okafor',
        deliveryAgentCode: 'PDA-7000',
        deliveryAgentPhone: '+234 803 111 2222',
        clientName: 'NovaCare Limited',
        status: 'delivered',
        isLocationVerified: true,
        locationConfidence: 'high',
        createdAt: DateTime(2026, 8, 27, 9, 30),
        assignedAt: DateTime(2026, 8, 27, 10, 0),
        deliveredAt: DateTime(2026, 8, 27, 14, 15),
        remittedAt: DateTime(2026, 8, 27, 15, 0),
        customerSignatureUrl: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );

      final container = ProviderContainer(
        overrides: [
          ordersProvider.overrideWith((ref) => _MockOrdersNotifier([sampleOrder])),
          stockProvider.overrideWith((ref) => _MockStockNotifier([
                const StockItemEntity(
                  id: 'prod-1',
                  sku: 'SKU-RESP-01',
                  name: 'Respira Detox Tea',
                  description: 'Detox tea',
                  price: 25000,
                  ownerName: 'NovaCare Limited',
                  inventoryType: InventoryType.distributedInventory,
                  totalInCustody: 60,
                  assignedCount: 10,
                  deliveredCount: 20,
                  availableCount: 30,
                  returnedCount: 0,
                  lowStockThreshold: 5,
                  category: 'Health',
                  binLocation: 'BIN-A1-01',
                  batchNumber: 'LOT-2026-08',
                ),
              ])),
          dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: sampleOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header & ID
      expect(find.text('Order TRK-8924'), findsOneWidget);
      expect(find.text('DELIVERED'), findsOneWidget);

      // 2. Customer details & Quick Actions
      expect(find.text('Fatima Abdullahi'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp Pin'), findsOneWidget);
      expect(find.text('GPS Nav'), findsOneWidget);

      // 3. Product & Inventory Stock Bin
      expect(find.text('Respira Detox Tea'), findsOneWidget);
      expect(find.text('BIN-A1-01'), findsOneWidget);
      expect(find.text('LOT-2026-08'), findsOneWidget);

      // 4. Custody & Assigned Rider
      expect(find.text('Emeka Okafor'), findsOneWidget);
      expect(find.text('PDA-7000'), findsOneWidget);

      // 5. Financial & Remittance Accounting
      expect(find.text('💰 Total Order Amount Collected:'), findsOneWidget);
      expect(find.text('🛵 Less Rider Commission (Entitlement):'), findsOneWidget);
      expect(find.text('🚚 Less Logistics & Transport Allowance:'), findsOneWidget);
      expect(find.text('🏢 Net Merchant Settlement Payable:'), findsOneWidget);

      // 6. Proof of Delivery
      expect(find.textContaining('Recipient: Fatima Abdullahi'), findsOneWidget);
    });

    testWidgets('Renders failed delivery ticket with prominent failure alert and logged reason', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final failedOrder = OrderEntity(
        id: 'ord-failed-1',
        orderNumber: 'TRK-4411',
        customerName: 'Chidi Obi',
        customerPhone: '+234 809 111 2233',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Area 3 Garki',
        productName: 'Bio-Gold Pro Capsules',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 35000,
        upsellAmount: 0,
        totalAmount: 35000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'standard_delivery',
        deliveryAgentId: 'drv-2',
        deliveryAgentName: 'Ibrahim Sanni',
        deliveryAgentCode: 'PDA-7001',
        clientName: 'NovaCare Limited',
        status: 'failed',
        failureReason: 'Customer phone switched off after 4 attempts. Rescheduled to tomorrow.',
        createdAt: DateTime(2026, 8, 27, 11, 0),
      );

      final container = ProviderContainer(
        overrides: [
          ordersProvider.overrideWith((ref) => _MockOrdersNotifier([failedOrder])),
          stockProvider.overrideWith((ref) => _MockStockNotifier([])),
          dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: failedOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order TRK-4411'), findsOneWidget);
      expect(find.text('FAILED / CALLBACK'), findsOneWidget);
      expect(find.text('Delivery Failed / Rescheduled Ticket'), findsOneWidget);
      expect(find.text('Logged Reason: Customer phone switched off after 4 attempts. Rescheduled to tomorrow.'), findsOneWidget);
    });
  });
}
