import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
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
              id: 'rider-01',
              driverCode: 'NX-R-01',
              name: 'Musa Rider',
              phone: '+234 803 111 2222',
              avatarUrl: '',
              vehicleModel: 'Bajaj Boxer 150',
              vehiclePlate: 'ABJ-452-XY',
              vehicleType: 'Motorcycle',
              status: 'active',
              assignedZone: 'Wuse 2 / Maitama',
              totalAssignedOrders: 5,
              completedOrders: 3,
              routeProgressPercent: 60.0,
              efficiencyRating: 4.9,
              cashInCustody: 12000,
              itemsInCustody: 2,
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
    OrderEntity(
      id: 'ord-table-01',
      orderNumber: 'NX-TBL-1001',
      customerName: 'Amina Yusuf',
      customerPhone: '08012345678',
      deliveryAddress: '14 Ademola Adetokunbo Crescent',
      deliveryCity: 'Wuse 2',
      deliveryState: 'Abuja',
      productName: 'Novacare Whitening Cream',
      quantity: 2,
      paidQuantity: 2,
      freeQuantity: 0,
      basePrice: 18500.0,
      upsellAmount: 0.0,
      totalAmount: 18500.0,
      paymentType: 'pod',
      paymentStatus: 'pending',
      status: 'pending',
      clientName: 'Novacare Global',
      createdAt: DateTime.now(),
    ),
    OrderEntity(
      id: 'ord-table-02',
      orderNumber: 'NX-TBL-1002',
      customerName: 'Emeka Okafor',
      customerPhone: '08098765432',
      deliveryAddress: '42 Gana Street',
      deliveryCity: 'Maitama',
      deliveryState: 'Abuja',
      productName: 'Hydrating Glow Serum',
      quantity: 1,
      paidQuantity: 1,
      freeQuantity: 0,
      basePrice: 12000.0,
      upsellAmount: 0.0,
      totalAmount: 12000.0,
      paymentType: 'prepaid',
      paymentStatus: 'paid',
      status: 'delivered',
      deliveryAgentId: 'rider-01',
      deliveryAgentName: 'Musa Rider',
      deliveryAgentCode: 'NX-R-01',
      clientName: 'Glow Beauty',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
        stockProvider.overrideWith((ref) => _MockStockNotifier()),
        dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DCOrdersPage(),
        ),
      ),
    );
  }

  group('DC Orders Responsive Table, Row Clicks, & Filter Bar Suite', () {
    testWidgets('1. Master Orders table displays rows, and tapping a row opens DCOrderDetailModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify DataTable and order numbers are visible
      expect(find.text('#NX-TBL-1001'), findsWidgets);
      expect(find.text('Amina Yusuf'), findsWidgets);
      expect(find.text('#NX-TBL-1002'), findsWidgets);

      // Tap on row with Amina Yusuf
      await tester.tap(find.text('Amina Yusuf').first);
      await tester.pumpAndSettle();

      // Verify DCOrderDetailModal is displayed with full order details
      expect(find.byType(DCOrderDetailModal), findsOneWidget);
      expect(find.text('Amina Yusuf'), findsWidgets);
      expect(find.text('14 Ademola Adetokunbo Crescent'), findsWidgets);

      // Close modal
      final closeBtn = find.byIcon(Icons.close_rounded);
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('2. Single-row unified filter bar includes Date Filter popup button and dropdowns', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final dateFilterFinder = find.textContaining('Date: All Time');
      expect(dateFilterFinder, findsOneWidget);
      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.text('All Riders'), findsOneWidget);
      expect(find.text('All Products'), findsOneWidget);
      expect(find.text('All Clients'), findsOneWidget);

      // Tap Date Filter popup button
      await tester.ensureVisible(dateFilterFinder);
      await tester.tap(dateFilterFinder);
      await tester.pumpAndSettle();

      // Verify Popup menu items appear
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Single Date (Calendar Pop-up)...'), findsOneWidget);
      expect(find.text('Custom Range (From - To Calendar)...'), findsOneWidget);

      // Select 'Today'
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Verify Date filter label updated to 'Date: Today'
      expect(find.textContaining('Date: Today'), findsOneWidget);
    });

    testWidgets('3. Mobile layout renders without RenderFlex overflow in pagination toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(380, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify no yellow/black striped overflow exceptions occurred
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Showing 1 to 2 of 2 orders'), findsOneWidget);
      expect(find.textContaining('Per page:'), findsOneWidget);
      expect(find.textContaining('Page 1 of 1'), findsOneWidget);
    });

    testWidgets('4. Mobile layout renders icon-only filter buttons in a single row without TabBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify TabBar is removed
      expect(find.byType(TabBar), findsNothing);

      // Verify Action buttons are visible under KPI cards
      expect(find.text('Create New Order'), findsOneWidget);
      expect(find.text('Import CSV'), findsOneWidget);

      // Verify icon-only filter triggers exist
      expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.business_rounded), findsOneWidget);

      // Verify tapping an icon opens status filter popup
      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.text('📦 Unassigned (Pending)'), findsOneWidget);
      expect(find.text('🟢 Delivered (Fulfilled)'), findsOneWidget);
    });
  });
}
