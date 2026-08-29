import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier(List<OrderEntity> initialOrders)
      : super(OrdersState(orders: initialOrders, isLoading: false));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  Future<void> loadOrders([String? agentId]) async {}

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
              id: 'drv-001',
              driverCode: 'PDA-7000',
              name: 'Emeka Rider',
              phone: '08012345678',
              avatarUrl: '',
              vehicleModel: 'Bajaj Boxer',
              vehiclePlate: 'ABJ-204-XY',
              vehicleType: 'Motorcycle',
              status: 'active',
              assignedZone: 'Wuse II & Zone 4',
              totalAssignedOrders: 10,
              completedOrders: 8,
              routeProgressPercent: 80.0,
              efficiencyRating: 98.4,
              cashInCustody: 70000.0,
              itemsInCustody: 5,
              personnelType: 'pda',
              compensationType: 'commission',
            ),
          ],
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testOrders = <OrderEntity>[
    // 1. Delivered POD - Unremitted Cash (Cash in custody: ₦70,000)
    OrderEntity(
      id: 'ord-cash-1',
      orderNumber: 'ORD-CASH-001',
      customerName: 'Alhaji Musa',
      customerPhone: '08031110001',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: 'Plot 4, Wuse 2',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 2,
      paidQuantity: 2,
      freeQuantity: 0,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 70000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      remittanceStatus: 'unremitted',
      deliveryAgentId: 'drv-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      clientName: 'Novacare Limited',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    // 2. Delivered POD - Remitted & Cleared (₦42,000)
    OrderEntity(
      id: 'ord-remitted-2',
      orderNumber: 'ORD-REMIT-002',
      customerName: 'Bolanle Balogun',
      customerPhone: '08032220002',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '12 Maitama Blvd',
      productName: 'Grazer Herbal Detox Tea',
      status: 'delivered',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 42000.0,
      upsellAmount: 0.0,
      totalAmount: 42000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      remittanceStatus: 'remitted',
      deliveryAgentId: 'drv-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      clientName: 'HealthPlus Direct',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    // 3. Delivered Direct Transfer - Monnify Bank Transfer (₦105,000)
    OrderEntity(
      id: 'ord-transfer-3',
      orderNumber: 'ORD-XFER-003',
      customerName: 'Dr. Chika Obi',
      customerPhone: '08033330003',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '8 Garki Area 2',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 3,
      paidQuantity: 3,
      freeQuantity: 0,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 105000.0,
      paymentType: 'direct_transfer',
      paymentStatus: 'paid',
      remittanceStatus: 'cleared',
      deliveryAgentId: 'drv-002',
      deliveryAgentName: 'Joel Odufu',
      deliveryAgentCode: 'PDA-7182',
      clientName: 'Novacare Limited',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    // 4. In Transit (Assigned) - Pending delivery (₦35,000)
    OrderEntity(
      id: 'ord-transit-4',
      orderNumber: 'ORD-TRNS-004',
      customerName: 'Fatima Sanusi',
      customerPhone: '08034440004',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '15 Utako District',
      productName: 'Respira Detox Tea',
      status: 'in_transit',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      remittanceStatus: 'pending',
      deliveryAgentId: 'drv-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      clientName: 'Novacare Limited',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  group('DC Console Cash Holding and Remittance Filtering & Priority Sorting Suite', () {
    testWidgets('1. DCOrdersPage renders 6 summary KPI cards including Cash in Custody', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Filtered Orders'), findsOneWidget);
      expect(find.text('📦 Unassigned Pool'), findsOneWidget);
      expect(find.text('🚴 In-Transit Live'), findsOneWidget);
      expect(find.text('🟢 Fulfilled / POD'), findsOneWidget);
      expect(find.text('🟡 Cash in Custody'), findsOneWidget);
      expect(find.text('⚠️ Failed / Returns'), findsOneWidget);

      // Verify Unremitted cash amount calculation (₦70,000.00)
      expect(find.text('₦70,000.00'), findsWidgets);
      expect(find.text('1 awaiting remittance'), findsWidgets);
    });

    testWidgets('2. Tapping Cash in Custody KPI card filters list directly to awaiting remittance', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alhaji Musa'), findsOneWidget);
      expect(find.text('Bolanle Balogun'), findsOneWidget);
      expect(find.text('Dr. Chika Obi'), findsOneWidget);
      expect(find.text('Fatima Sanusi'), findsOneWidget);

      // Tap on Cash in Custody KPI card
      await tester.tap(find.text('🟡 Cash in Custody').first);
      await tester.pumpAndSettle();

      // Only Alhaji Musa (cash in custody awaiting remittance) should be visible
      expect(find.text('Alhaji Musa'), findsOneWidget);
      expect(find.text('Bolanle Balogun'), findsNothing);
      expect(find.text('Dr. Chika Obi'), findsNothing);
      expect(find.text('Fatima Sanusi'), findsNothing);
    });

    testWidgets('3. Remittance filter dropdown filters by Remitted vs Direct Transfer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
          stockProvider.overrideWith((ref) => _MockStockNotifier()),
          dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
        ],
      );
      addTearDown(() => container.dispose());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter by Remitted only
      container.read(dcMasterRemittanceFilterProvider.notifier).state = 'remitted';
      await tester.pumpAndSettle();

      expect(find.text('Bolanle Balogun'), findsOneWidget);
      expect(find.text('Alhaji Musa'), findsNothing);
      expect(find.text('Dr. Chika Obi'), findsNothing);

      // Filter by Direct Transfer only
      container.read(dcMasterRemittanceFilterProvider.notifier).state = 'direct_transfer';
      await tester.pumpAndSettle();

      expect(find.text('Dr. Chika Obi'), findsOneWidget);
      expect(find.text('Bolanle Balogun'), findsNothing);
      expect(find.text('Alhaji Musa'), findsNothing);

      // Filter by Awaiting Remittance
      container.read(dcMasterRemittanceFilterProvider.notifier).state = 'awaiting_remittance';
      await tester.pumpAndSettle();

      expect(find.text('Alhaji Musa'), findsOneWidget);
      expect(find.text('Dr. Chika Obi'), findsNothing);
      expect(find.text('Bolanle Balogun'), findsNothing);
    });
  });
}
