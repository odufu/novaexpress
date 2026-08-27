import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_transaction_record.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_riders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_driver_manifest_table.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_rider_detail_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleDriver = DCFleetDriver(
    id: 'rider-001',
    driverCode: 'PDA-7000',
    name: 'Emeka Rider',
    phone: '08012345678',
    avatarUrl: '',
    vehicleModel: 'Bajaj Boxer 150',
    vehiclePlate: 'ABJ-204-XY',
    vehicleType: 'Motorcycle',
    status: 'active',
    assignedZone: 'Wuse II & Abuja Central',
    totalAssignedOrders: 3,
    completedOrders: 2,
    routeProgressPercent: 66.6,
    efficiencyRating: 98.5,
    cashInCustody: 22000.0,
    itemsInCustody: 4,
    personnelType: 'pda',
    compensationType: 'commission',
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    bankName: 'GTBank',
    bankAccountNumber: '0123456789',
    bankAccountName: 'Emeka Rider',
  );

  final List<OrderEntity> mockOrders = [
    OrderEntity(
      id: 'ord-001',
      orderNumber: 'ORD-9001-ABJ',
      customerName: 'Amina Bello',
      customerPhone: '08023456789',
      deliveryAddress: 'Plot 12 Adetokunbo Crescent, Wuse 2',
      deliveryCity: 'Wuse 2',
      deliveryState: 'Abuja',
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
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    OrderEntity(
      id: 'ord-002',
      orderNumber: 'ORD-9002-ABJ',
      customerName: 'Chinedu Eze',
      customerPhone: '08034567890',
      deliveryAddress: 'Suit 4, Banex Plaza, Wuse 2',
      deliveryCity: 'Wuse 2',
      deliveryState: 'Abuja',
      productName: 'Respira Detox Tea',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 22000.0,
      upsellAmount: 0.0,
      totalAmount: 22000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      status: 'delivered',
      deliveryAgentId: 'rider-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    OrderEntity(
      id: 'ord-003',
      orderNumber: 'ORD-9003-ABJ',
      customerName: 'Musa Garba',
      customerPhone: '08045678901',
      deliveryAddress: 'Aminu Kano Way, Wuse 2',
      deliveryCity: 'Wuse 2',
      deliveryState: 'Abuja',
      productName: 'Client Glow Serum',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 18000.0,
      upsellAmount: 0.0,
      totalAmount: 18000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      fulfillmentType: 'client_package',
      status: 'in_transit',
      deliveryAgentId: 'rider-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
  ];

  final List<DCTransactionRecord> mockTransactions = [
    DCTransactionRecord(
      id: 'txn-001',
      transactionCode: 'PSTK-TXN-8821',
      riderId: 'rider-001',
      riderName: 'Emeka Rider',
      riderCode: 'PDA-7000',
      amount: 35000.0,
      category: 'paystack_direct',
      paymentMethod: 'paystack',
      orderNumber: 'ORD-9001-ABJ',
      productName: 'Respira Detox Tea',
      channel: 'Titan Trust / Paystack',
      status: 'verified',
      isCredit: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    DCTransactionRecord(
      id: 'txn-002',
      transactionCode: 'REM-8822',
      riderId: 'rider-001',
      riderName: 'Emeka Rider',
      riderCode: 'PDA-7000',
      amount: 22000.0,
      category: 'remittance',
      paymentMethod: 'bank_transfer',
      orderNumber: 'ORD-9002-ABJ',
      productName: 'Respira Detox Tea',
      channel: 'Bank Transfer Handover',
      status: 'pending',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  final List<StockItemEntity> mockStockItems = [
    const StockItemEntity(
      id: 'stock-001',
      sku: 'RESPIRA-01',
      name: 'Respira Detox Tea',
      description: 'Herbal lung cleanse formula',
      price: 35000.0,
      assignedCount: 10,
      deliveredCount: 5,
      availableCount: 150,
      returnedCount: 0,
      category: 'Health',
    ),
  ];

  group('DC Rider Detail Modal & Manifest Suite', () {
    testWidgets('1. DCDriverManifestTable renders minimalist search bar and filters riders dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DCDriverManifestTable(
              drivers: const [sampleDriver],
              onDriverTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Table Title & Search
      expect(find.text('Delivery Personnel Manifest'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('PDA-7000'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsOneWidget);
      expect(find.text('PDA'), findsOneWidget);

      // Search for non-existent driver
      await tester.enterText(find.byType(TextField), 'NonExistentPerson');
      await tester.pumpAndSettle();

      expect(find.textContaining('No delivery personnel found matching'), findsOneWidget);

      // Clear search
      await tester.enterText(find.byType(TextField), 'Emeka');
      await tester.pumpAndSettle();

      expect(find.text('Emeka Rider'), findsOneWidget);
    });

    testWidgets('2. DCRidersPage opens DCRiderDetailModal upon row tap and renders profile header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(mockOrders)),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(const [sampleDriver], mockTransactions)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRidersPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Emeka Rider row
      final riderRow = find.text('Emeka Rider');
      expect(riderRow, findsOneWidget);
      await tester.tap(riderRow);
      await tester.pumpAndSettle();

      // Verify DCRiderDetailModal opened
      expect(find.byType(DCRiderDetailModal), findsOneWidget);
      expect(find.text('PDA (Personal)'), findsWidgets);
      expect(find.text('08012345678'), findsWidgets);
      expect(find.textContaining('Wuse II & Abuja Central'), findsWidgets);
    });

    testWidgets('3. DCRiderDetailModal Orders tab displays 1-row KPI aggregators and minimalist table', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(mockOrders)),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(const [sampleDriver], mockTransactions)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRiderDetailModal(driver: sampleDriver),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Orders Tab KPIs
      expect(find.text('📦 Total Assigned'), findsOneWidget);
      expect(find.text('3 Orders'), findsOneWidget);
      expect(find.text('✅ Delivered / POD'), findsOneWidget);
      expect(find.text('2 Done'), findsOneWidget);
      expect(find.text('🚚 Active on Route'), findsOneWidget);
      expect(find.text('1 In-Transit'), findsOneWidget);

      // Verify Orders Table Rows
      expect(find.text('ORD-9001-ABJ'), findsOneWidget);
      expect(find.text('ORD-9002-ABJ'), findsOneWidget);
      expect(find.text('ORD-9003-ABJ'), findsOneWidget);
      expect(find.text('Amina Bello'), findsOneWidget);
    });

    testWidgets('4. DCRiderDetailModal Remittance tab displays 1-row KPI aggregators and payment records', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(mockOrders)),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(const [sampleDriver], mockTransactions)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRiderDetailModal(driver: sampleDriver),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Remittance Tab
      final remittanceTab = find.text('Remittance (2)');
      expect(remittanceTab, findsOneWidget);
      await tester.tap(remittanceTab);
      await tester.pumpAndSettle();

      // Verify Remittance 4 Major KPIs & Table records
      expect(find.text('💵 Gross Collected'), findsOneWidget);
      expect(find.text('⏳ To Remit'), findsOneWidget);
      expect(find.text('💼 Commission'), findsOneWidget);
      expect(find.text('🏦 His Balance'), findsOneWidget);
      expect(find.text('PSTK-TXN-8821'), findsOneWidget);
      expect(find.text('REM-8822'), findsOneWidget);
    });

    testWidgets('5. DCRiderDetailModal Stocks in Custody tab displays real custody breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(mockOrders)),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(const [sampleDriver], mockTransactions)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(mockStockItems)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRiderDetailModal(driver: sampleDriver),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Stocks in Custody Tab
      final stocksTab = find.textContaining('Stocks in Custody');
      expect(stocksTab, findsOneWidget);
      await tester.tap(stocksTab);
      await tester.pumpAndSettle();

      // Verify Stocks KPIs & table
      expect(find.text('📦 Units in Custody'), findsOneWidget);
      expect(find.text('🏢 Shelf Stock Items'), findsOneWidget);
      expect(find.text('📦 Client Packages'), findsWidgets);
      expect(find.text('Client Glow Serum'), findsOneWidget);
    });
  });
}

class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier(List<OrderEntity> orders) : super(OrdersState(isLoading: false, orders: orders));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  _MockDCConsoleNotifier(List<DCFleetDriver> drivers, [List<DCTransactionRecord> txns = const []])
      : super(DCConsoleState(drivers: drivers, transactions: txns));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier(List<StockItemEntity> items) : super(StockState(isLoading: false, stockItems: items));

  @override
  Future<void> fetchStockItems([String? agentId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
