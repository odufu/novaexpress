import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_assign_order_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_csv_order_import_modal.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockNotificationsRepo implements NotificationsRepository {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationsRemoteDS implements NotificationsRemoteDataSource {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthRemoteDS implements AuthRemoteDataSource {
  static const testUser = UserModel(
    id: 'admin-001',
    email: 'dc.supervisor@novaexpress.ng',
    firstName: 'Adekunle',
    lastName: 'Supervisor',
    phone: '08099887766',
    role: 'dc_manager',
    distributionCenterName: 'Wuse Distribution Center',
  );

  @override
  Future<UserModel> login(String email, String password) async => testUser;
  @override
  Future<void> logout() async {}
  @override
  Future<UserModel?> getCurrentUser() async => testUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFinanceRemoteDS implements FinanceRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockRemoteDS implements StockRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  final List<OrderModel> mockOrders;
  _MockOrdersRemoteDS(this.mockOrders);

  @override
  Future<List<OrderModel>> getAssignedOrders([String? agentId]) async =>
      mockOrders.where((o) => o.deliveryAgentId == agentId).toList();

  @override
  Future<List<OrderModel>> getDistributionCenterOrders([String? distributionCenterId]) async =>
      mockOrders;

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    return OrderModel(
      id: 'ord-new',
      orderNumber: orderData['order_number'] ?? 'ORD-NEW',
      customerName: orderData['customer_name'] ?? 'New Customer',
      customerPhone: orderData['customer_phone'] ?? '08000000000',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: orderData['delivery_address'] ?? 'Abuja',
      productName: orderData['product_name'] ?? 'Respira Detox Tea',
      status: 'pending',
      quantity: (orderData['quantity'] ?? 1) as int,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: (orderData['total_amount'] ?? 35000.0).toDouble(),
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      distributionCenterId: 'dc-001',
      clientName: orderData['client_name'] ?? 'Novacare Limited',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<OrderModel> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    final idx = mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = OrderModel(
        id: mockOrders[idx].id,
        orderNumber: mockOrders[idx].orderNumber,
        customerName: mockOrders[idx].customerName,
        customerPhone: mockOrders[idx].customerPhone,
        deliveryAddress: mockOrders[idx].deliveryAddress,
        deliveryCity: mockOrders[idx].deliveryCity,
        deliveryState: mockOrders[idx].deliveryState,
        productName: mockOrders[idx].productName,
        quantity: mockOrders[idx].quantity,
        basePrice: mockOrders[idx].basePrice,
        upsellAmount: mockOrders[idx].upsellAmount,
        totalAmount: mockOrders[idx].totalAmount,
        paymentType: mockOrders[idx].paymentType,
        paymentStatus: mockOrders[idx].paymentStatus,
        status: 'in_transit',
        deliveryAgentId: riderId,
        deliveryAgentName: riderName,
        deliveryAgentCode: riderCode,
        distributionCenterId: mockOrders[idx].distributionCenterId,
        clientName: mockOrders[idx].clientName,
        createdAt: mockOrders[idx].createdAt,
      );
      mockOrders[idx] = updated;
      return updated;
    }
    return mockOrders.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialOrders = [
    OrderModel(
      id: 'ord-101',
      orderNumber: 'ORD-101',
      customerName: 'Aisha Bello',
      customerPhone: '08031110001',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '14 Aminu Kano Crescent, Wuse 2',
      productName: 'Respira Detox Tea',
      status: 'pending',
      quantity: 2,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 70000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      distributionCenterId: 'dc-001',
      clientName: 'Novacare Limited',
      createdAt: DateTime.now(),
    ),
    OrderModel(
      id: 'ord-102',
      orderNumber: 'ORD-102',
      customerName: 'Chidi Okafor',
      customerPhone: '08032220002',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '22 Gana Street, Maitama',
      productName: 'Grazer Herbal Detox Tea',
      status: 'in_transit',
      quantity: 1,
      basePrice: 42000.0,
      upsellAmount: 0.0,
      totalAmount: 42000.0,
      paymentType: 'prepaid',
      paymentStatus: 'paid',
      deliveryAgentId: 'drv-001',
      deliveryAgentName: 'Emeka Rider',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterId: 'dc-001',
      clientName: 'HealthPlus Direct',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    OrderModel(
      id: 'ord-103',
      orderNumber: 'ORD-103',
      customerName: 'Fatima Sanusi',
      customerPhone: '08033330003',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Abuja',
      deliveryAddress: '5 Ademola Adetokunbo Crescent, Wuse 2',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 3,
      basePrice: 35000.0,
      upsellAmount: 0.0,
      totalAmount: 105000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'paid',
      deliveryAgentId: 'drv-002',
      deliveryAgentName: 'Joel Odufu',
      deliveryAgentCode: 'PDA-7182',
      distributionCenterId: 'dc-001',
      clientName: 'Novacare Limited',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  const initialDrivers = [
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
    DCFleetDriver(
      id: 'drv-002',
      driverCode: 'PDA-7182',
      name: 'Joel Odufu',
      phone: '08098765432',
      avatarUrl: '',
      vehicleModel: 'Honda Ace 125',
      vehiclePlate: 'ABJ-315-ZZ',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Maitama',
      totalAssignedOrders: 15,
      completedOrders: 14,
      routeProgressPercent: 93.3,
      efficiencyRating: 99.1,
      cashInCustody: 145000.0,
      itemsInCustody: 8,
      personnelType: 'pda',
      compensationType: 'salary',
    ),
  ];

  List<Override> createOverrides() {
    final mockOrdersDS = _MockOrdersRemoteDS(List.from(initialOrders));

    return [
      authRemoteDataSourceProvider.overrideWithValue(_MockAuthRemoteDS()),
      authRepositoryProvider.overrideWith((ref) => AuthRepositoryImpl(_MockAuthRemoteDS())),
      ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersDS),
      ordersProvider.overrideWith((ref) {
        final notifier = OrdersNotifier(OrdersRepositoryImpl(mockOrdersDS));
        notifier.state = OrdersState(orders: initialOrders, isLoading: false);
        return notifier;
      }),
      financeRemoteDataSourceProvider.overrideWithValue(_MockFinanceRemoteDS()),
      financeProvider.overrideWith((ref) {
        final notifier = FinanceNotifier(FinanceRepositoryImpl(_MockFinanceRemoteDS()));
        notifier.state = FinanceState(remittances: const []);
        return notifier;
      }),
      stockRemoteDataSourceProvider.overrideWithValue(_MockStockRemoteDS()),
      stockProvider.overrideWith((ref) {
        final notifier = StockNotifier(repository: StockRepositoryImpl(remoteDataSource: _MockStockRemoteDS()));
        notifier.state = StockState(
          stockItems: const [],
          riderAllocations: [
            RiderStockAllocation(
              id: 'alloc_emeka',
              riderId: 'drv-001',
              riderName: 'Emeka Rider',
              riderCode: 'PDA-7000',
              productId: 'prod-1',
              productName: 'Respira Detox Tea',
              sku: 'SKU-RESP-01',
              clientName: 'Novacare Limited',
              allocatedUnits: 10,
              deliveredUnits: 0,
              inCustodyUnits: 10,
              unitPrice: 25000,
              allocatedAt: DateTime.now(),
            ),
          ],
          isLoading: false,
        );
        return notifier;
      }),
      notificationsRemoteDataSourceProvider.overrideWithValue(_MockNotificationsRemoteDS()),
      notificationsRepositoryProvider.overrideWithValue(_MockNotificationsRepo()),
      dcConsoleProvider.overrideWith((ref) {
        final notifier = DCConsoleNotifier();
        notifier.state = notifier.state.copyWith(
          drivers: initialDrivers,
          isLoading: false,
        );
        return notifier;
      }),
    ];
  }

  group('DC Console CSV Order Import & Master Orders Directory Suite', () {
    testWidgets('1. DCCsvOrderImportModal parses CSV text, validates rows, and displays statistics', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(
              body: DCCsvOrderImportModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Import Orders via CSV'), findsOneWidget);
      expect(find.text('Sample Template'), findsOneWidget);

      // Switch to Paste CSV Text tab
      await tester.tap(find.text('Paste CSV Text'));
      await tester.pumpAndSettle();

      const rawCsv = '''
Order No,Customer Name,Phone,Alt Phone,Delivery Address,City,State,Product,Qty,Amount,Payment Method,Client,Notes,Rider Code
ORD-9001,Senator Akpabio,08091234567,08030001111,"Plot 10, Maitama",Abuja,FCT,Respira Detox Tea,2,70000,COD,Novacare Limited,Call before delivery,PDA-7000
ORD-9002,Hon. Maryam Ali,08097654321,,5 Ahmadu Bello Way,Abuja,FCT,Grazer Herbal Detox Tea,1,42000,Prepaid,HealthPlus Direct,,
''';

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, rawCsv);
      await tester.pumpAndSettle();

      final parseButton = find.text('Parse Text');
      expect(parseButton, findsOneWidget);
      await tester.tap(parseButton);
      await tester.pumpAndSettle();

      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('Valid Orders'), findsWidgets);
      expect(find.text('Total Valuation'), findsOneWidget);
      expect(find.text('Senator Akpabio'), findsOneWidget);
      expect(find.text('Hon. Maryam Ali'), findsOneWidget);
    });

    testWidgets('2. DCOrdersPage renders Master Orders Directory with all orders and tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: DCOrdersPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Master Orders Directory'), findsOneWidget);
      expect(find.textContaining('All Orders (3)'), findsOneWidget);
      expect(find.textContaining('Unassigned Pool (1)'), findsOneWidget);
      expect(find.textContaining('In-Transit Routes (1)'), findsOneWidget);
      expect(find.textContaining('Delivered / POD (1)'), findsOneWidget);

      expect(find.text('Import CSV'), findsOneWidget);

      expect(find.text('Aisha Bello'), findsOneWidget);
      expect(find.text('Chidi Okafor'), findsOneWidget);
      expect(find.text('Fatima Sanusi'), findsOneWidget);
    });

    testWidgets('3. Master Orders filter toolbar filters by Search, Status, and View Mode', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: DCOrdersPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search Query Filter
      final searchInput = find.byKey(const Key('dc_master_search_input'));
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'Aisha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Aisha Bello'), findsOneWidget);
      expect(find.text('Chidi Okafor'), findsNothing);
      expect(find.text('Fatima Sanusi'), findsNothing);

      // Clear search
      await tester.enterText(searchInput, '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Chidi Okafor'), findsOneWidget);

      // View Mode Toggle (Table <-> Grid)
      final gridToggle = find.byTooltip('Cards Grid View');
      expect(gridToggle, findsOneWidget);
      await tester.tap(gridToggle);
      await tester.pumpAndSettle();

      expect(find.text('#ORD-101'), findsOneWidget);
      expect(find.text('#ORD-102'), findsOneWidget);
      expect(find.text('#ORD-103'), findsOneWidget);
    });

    testWidgets('4. DCAssignOrderModal allows assigning unassigned order to fleet rider', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final unassignedOrder = initialOrders.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: DCAssignOrderModal(order: unassignedOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('ORD-101'), findsWidgets);
      expect(find.textContaining('Dispatch Order'), findsWidgets);
      expect(find.textContaining('Aisha Bello'), findsWidgets);
      expect(find.textContaining('Respira Detox Tea'), findsWidgets);

      expect(find.textContaining('Emeka Rider'), findsWidgets);
      expect(find.textContaining('Joel Odufu'), findsWidgets);

      await tester.tap(find.textContaining('Emeka Rider').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected: Emeka Rider'), findsOneWidget);
      expect(find.text('Dispatch & Assign Order'), findsOneWidget);
    });
  });
}
