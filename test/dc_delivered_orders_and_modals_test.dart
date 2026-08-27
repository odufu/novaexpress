import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<OrderEntity> mockDeliveredOrders = [
    OrderEntity(
      id: 'ord-101',
      orderNumber: 'ORD-9284-NIG',
      customerName: 'Chief Aliyu Mohammed',
      customerPhone: '08031234567',
      customerAltPhone: '08098765432',
      deliveryAddress: 'Plot 42, Admiralty Way, Lekki Phase 1',
      deliveryCity: 'Lekki',
      deliveryState: 'Lagos',
      landmark: 'Near Ebeano Supermarket',
      productName: 'Respira Detox Tea',
      quantity: 2,
      paidQuantity: 1,
      freeQuantity: 1,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      paymentType: 'direct_transfer',
      paymentStatus: 'paid',
      status: 'delivered',
      deliveryAgentId: 'rider-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now(),
      customerSignatureUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      deliveryNotes: 'Delivered to customer in person. Condition inspected.',
    ),
    OrderEntity(
      id: 'ord-102',
      orderNumber: 'ORD-9285-NIG',
      customerName: 'Fatima Garba',
      customerPhone: '08123456789',
      deliveryAddress: 'Suite 12, Wuse 2 Commercial Plaza',
      deliveryCity: 'Wuse 2',
      deliveryState: 'Abuja',
      productName: 'Respira Detox Tea',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 20000.0,
      upsellAmount: 0.0,
      totalAmount: 20000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'paid',
      status: 'delivered',
      deliveryAgentId: 'rider-002',
      deliveryAgentName: 'Sanni Field',
      deliveryAgentCode: 'PDA-7001',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      createdAt: DateTime.now(),
    ),
  ];

  final List<StockItemEntity> mockStockItems = [
    const StockItemEntity(
      id: 'stock-001',
      sku: 'RESPIRA-01',
      name: 'Respira Detox Tea',
      description: 'Herbal lung cleanse & respiratory relief formula',
      price: 35000.0,
      assignedCount: 50,
      deliveredCount: 30,
      availableCount: 148,
      returnedCount: 2,
      category: 'Health',
    ),
  ];

  group('DC Delivered Orders & Breakdown Modals Suite', () {
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
      expect(find.text('Direct to Bank (Paystack)'), findsOneWidget);
      expect(find.text('Cash Collected in Hand'), findsOneWidget);
      expect(find.text('Stock Units Dispatched'), findsOneWidget);

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

    testWidgets('2. Clicking Finance button opens Financial Breakdown modal with settlement matrix', (tester) async {
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

      // Verify Finance Modal
      expect(find.text('Financial Settlement Audit'), findsOneWidget);
      expect(find.text('Total Order Value'), findsOneWidget);
      expect(find.text('Settled Directly to Company (Bank)'), findsOneWidget);
      expect(find.text('Rider Commission Credited'), findsOneWidget);
      expect(find.text('Fuel / Transport Allowance'), findsOneWidget);
      expect(find.text('PAYMENT AUDIT TRAIL'), findsOneWidget);
      expect(find.text('Auto-reconciled ✓'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('3. Clicking Stock button opens Stock & Inventory Fulfillment modal with shelf deductions', (tester) async {
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

      // Verify Stock Modal
      expect(find.text('Stock & Inventory Fulfillment'), findsOneWidget);
      expect(find.text('Wuse DC Distribution Hub Warehouse'), findsOneWidget);
      expect(find.text('Units Dispatched & Delivered'), findsOneWidget);
      expect(find.text('Warehouse Deduction'), findsOneWidget);
      expect(find.text('-2 Units Deducted at Dispatch'), findsOneWidget);
      expect(find.text('Current Available Hub Stock'), findsOneWidget);
      expect(find.text('148 Units on Shelf'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('4. Clicking Order & POD details button opens Order details, receiver contacts, and signature', (tester) async {
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

      // Verify Order & POD Details Modal
      expect(find.text('Order & POD Audit Details'), findsOneWidget);
      expect(find.text('RECEIVER & DESTINATION'), findsOneWidget);
      expect(find.text('08031234567'), findsOneWidget);
      expect(find.text('Plot 42, Admiralty Way, Lekki Phase 1'), findsOneWidget);
      expect(find.text('Near Ebeano Supermarket'), findsOneWidget);
      expect(find.text('RECEIVER DIGITAL SIGNATURE (POD)'), findsOneWidget);
      expect(find.text('VERIFIED ✓'), findsOneWidget);
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
