import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DC Delivered Orders & Breakdown Modals Suite', () {
    final mockDeliveredOrders = [
      OrderEntity(
        id: 'ord_pod_1',
        orderNumber: 'ORD-9284-NIG',
        customerName: 'Chief Aliyu Mohammed',
        customerPhone: '08031234567',
        customerAltPhone: '08099887766',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki',
        deliveryAddress: 'Plot 42, Admiralty Way, Lekki Phase 1',
        landmark: 'Near Ebeano Supermarket',
        productName: 'Respira Detox Tea',
        productSku: 'SKU-RESP-01',
        binLocation: 'BIN-A1-01',
        batchNumber: 'LOT-2026-08',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 5000,
        totalAmount: 30000,
        agentEntitlement: 2500,
        transportFee: 1500,
        paymentType: 'direct_transfer',
        paymentStatus: 'paid',
        remittanceStatus: 'direct_transfer',
        fulfillmentType: 'distributed_inventory',
        deliveryAgentId: 'rider_1',
        deliveryAgentName: 'Emeka Okafor',
        deliveryAgentCode: 'PDA-7000',
        deliveryAgentPhone: '+234 803 111 2222',
        clientName: 'Novacare Limited',
        status: 'delivered',
        isLocationVerified: true,
        locationConfidence: 'high',
        customerSignatureUrl: 'https://example.com/sig.png',
        createdAt: DateTime(2026, 8, 27, 8, 0),
        deliveredAt: DateTime(2026, 8, 27, 14, 30),
      ),
      OrderEntity(
        id: 'ord_pod_2',
        orderNumber: 'ORD-9285-NIG',
        customerName: 'Fatima Garba',
        customerPhone: '08099887766',
        deliveryState: 'Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: '15 Gana Street, Maitama',
        productName: 'Grazer Herbal Tea',
        productSku: 'SKU-GRAZ-02',
        binLocation: 'BIN-B1-03',
        batchNumber: 'LOT-2026-09',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 30000,
        upsellAmount: 0,
        totalAmount: 30000,
        agentEntitlement: 2500,
        transportFee: 1500,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        remittanceStatus: 'cleared',
        remittanceReference: 'RMT-00402',
        fulfillmentType: 'client_package',
        deliveryAgentId: 'rider_2',
        deliveryAgentName: 'Ibrahim Sanni',
        deliveryAgentCode: 'PDA-7001',
        deliveryAgentPhone: '+234 805 555 6666',
        clientName: 'Novacare Limited',
        status: 'delivered',
        isLocationVerified: true,
        locationConfidence: 'high',
        createdAt: DateTime(2026, 8, 27, 8, 30),
        deliveredAt: DateTime(2026, 8, 27, 15, 0),
      ),
    ];

    final mockStockItems = [
      const StockItemEntity(
        id: 'item_1',
        sku: 'SKU-RESP-01',
        name: 'Respira Detox Tea',
        description: 'Herbal tea',
        price: 25000,
        ownerName: 'Novacare Limited',
        inventoryType: InventoryType.distributedInventory,
        totalInCustody: 200,
        assignedCount: 50,
        deliveredCount: 2,
        availableCount: 148,
        returnedCount: 0,
        lowStockThreshold: 10,
        category: 'Herbal',
      ),
    ];

    testWidgets('1. DCOrdersPage renders Delivered/POD tab, metric KPIs, and order cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => OrdersStateNotifierMock(mockDeliveredOrders)),
            stockProvider.overrideWith((ref) => StockStateNotifierMock(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Delivered / POD tab (tab index 2)
      final deliveredTab = find.text('Delivered / POD (2)');
      expect(deliveredTab, findsOneWidget);
      await tester.tap(deliveredTab);
      await tester.pumpAndSettle();

      // Verify Header and Summary KPI Cards
      expect(find.text('Delivered Orders & Fulfillment Audit'), findsOneWidget);
      expect(find.text('Total Delivered Revenue'), findsOneWidget);
      expect(find.text('🟢 Remitted & Cleared'), findsOneWidget);
      expect(find.text('🟡 In Rider Custody'), findsOneWidget);
      expect(find.text('⚡ Direct to Bank'), findsOneWidget);

      // Verify Delivered Order Cards
      expect(find.text('#ORD-9284-NIG'), findsOneWidget);
      expect(find.text('#ORD-9285-NIG'), findsOneWidget);
      expect(find.textContaining('Chief Aliyu Mohammed'), findsOneWidget);
      expect(find.textContaining('Fatima Garba'), findsOneWidget);

      // Verify the 3 action buttons exist on delivered orders
      expect(find.text('💰 Finance & Collections'), findsWidgets);
      expect(find.textContaining('📦 Stock & Inventory'), findsWidgets);
      expect(find.text('📍 Order & POD Signature'), findsWidgets);
    });

    testWidgets('2. Clicking Finance button opens DCOrderDetailModal with financial accounting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => OrdersStateNotifierMock(mockDeliveredOrders)),
            stockProvider.overrideWith((ref) => StockStateNotifierMock(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Delivered tab
      await tester.tap(find.text('Delivered / POD (2)'));
      await tester.pumpAndSettle();

      // Tap first Finance button
      final financeBtn = find.text('💰 Finance & Collections').first;
      await tester.tap(financeBtn);
      await tester.pumpAndSettle();

      // Verify Order Detail Modal
      expect(find.text('Order ORD-9284-NIG'), findsOneWidget);
      expect(find.text('💰 Financial Accounting & Remittance Reconciliation'), findsOneWidget);
      expect(find.text('💰 Total Order Amount Collected:'), findsOneWidget);
      expect(find.text('🛵 Less Rider Commission (Entitlement):'), findsOneWidget);
      expect(find.text('🚚 Less Logistics & Transport Allowance:'), findsOneWidget);
      expect(find.text('🏢 Net Merchant Settlement Payable:'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
    });

    testWidgets('3. Clicking Stock button opens DCOrderDetailModal with warehouse stock custody', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => OrdersStateNotifierMock(mockDeliveredOrders)),
            stockProvider.overrideWith((ref) => StockStateNotifierMock(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Delivered tab
      await tester.tap(find.text('Delivered / POD (2)'));
      await tester.pumpAndSettle();

      // Tap first Stock button
      final stockBtn = find.textContaining('📦 Stock & Inventory').first;
      await tester.tap(stockBtn);
      await tester.pumpAndSettle();

      // Verify Stock info in modal
      expect(find.text('Order ORD-9284-NIG'), findsOneWidget);
      expect(find.text('📦 Product & Warehouse Inventory Linkage'), findsOneWidget);
      expect(find.text('Respira Detox Tea'), findsOneWidget);
      expect(find.text('BIN-A1-01'), findsOneWidget);
      expect(find.text('LOT-2026-08'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
    });

    testWidgets('4. Clicking Order & POD details button opens DCOrderDetailModal with receiver and POD details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => OrdersStateNotifierMock(mockDeliveredOrders)),
            stockProvider.overrideWith((ref) => StockStateNotifierMock(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Delivered tab
      await tester.tap(find.text('Delivered / POD (2)'));
      await tester.pumpAndSettle();

      // Tap first Order & POD details button
      final podBtn = find.text('📍 Order & POD Signature').first;
      await tester.tap(podBtn);
      await tester.pumpAndSettle();

      // Verify Order & POD Details in modal
      expect(find.text('Order ORD-9284-NIG'), findsOneWidget);
      expect(find.text('👤 Customer & Destination Information'), findsOneWidget);
      expect(find.text('Chief Aliyu Mohammed'), findsOneWidget);
      expect(find.text('Phone: 08031234567'), findsOneWidget);
      expect(find.text('Plot 42, Admiralty Way, Lekki Phase 1'), findsOneWidget);
      expect(find.text('📝 Digital Proof of Delivery (POD)'), findsOneWidget);
      expect(find.text('Fulfilled & Signed by Chief Aliyu Mohammed'), findsOneWidget);
    });
  });
}

class OrdersStateNotifierMock extends StateNotifier<OrdersState> implements OrdersNotifier {
  OrdersStateNotifierMock(List<OrderEntity> orders) : super(OrdersState(isLoading: false, orders: orders));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StockStateNotifierMock extends StateNotifier<StockState> implements StockNotifier {
  StockStateNotifierMock(List<StockItemEntity> items) : super(StockState(isLoading: false, stockItems: items));

  @override
  Future<void> fetchStockItems([String? agentId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
