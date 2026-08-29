import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_assign_order_modal.dart';

class MockStockRepo implements StockRepository {
  List<StockItemEntity> items = [
    const StockItemEntity(
      id: 'prod_respira_01',
      sku: 'SKU-RESP-01',
      name: 'Respira Detox Tea',
      description: 'Respira Detox Tea Description',
      price: 25000,
      ownerName: 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 100,
      assignedCount: 20,
      deliveredCount: 0,
      availableCount: 80,
      returnedCount: 0,
      lowStockThreshold: 5,
      category: 'Health & Wellness',
    ),
  ];

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async => items;

  @override
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId]) async => [];

  @override
  Future<void> updateRiderStockCustody({
    required String riderId,
    required String productId,
    int deliveredDelta = 0,
    int returnedDelta = 0,
    int inCustodyDelta = 0,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOrdersRepo implements OrdersRepository {
  List<OrderEntity> mockOrders = [];

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => mockOrders;

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => mockOrders;

  @override
  Future<Map<String, dynamic>> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    return {'status': 'success'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorage implements LocalStorageService {
  @override
  Future<void> cacheStockItems(List<StockItemEntity> items) async {}
  @override
  Future<List<StockItemEntity>?> getCachedStockItems() async => null;
  @override
  Future<void> cacheRiderStockAllocations(List<RiderStockAllocation> allocations) async {}
  @override
  Future<List<RiderStockAllocation>?> getCachedRiderStockAllocations() async => null;
  @override
  Future<void> cacheOrders(List<OrderEntity> orders, [String? scope]) async {}
  @override
  Future<List<OrderEntity>?> getCachedOrders([String? scope]) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier({
    required super.loginUseCase,
    required super.logoutUseCase,
    required super.getCurrentUserUseCase,
  });

  @override
  Future<void> checkCurrentUser() async {
    state = const AuthState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Strict Stock Custody Enforcement & Order Assignment Suite', () {
    late MockStockRepo mockStockRepo;
    late MockOrdersRepo mockOrdersRepo;
    late MockStorage mockStorage;

    setUp(() {
      mockStockRepo = MockStockRepo();
      mockOrdersRepo = MockOrdersRepo();
      mockStorage = MockStorage();
    });

    List<Override> createTestOverrides({List<DCFleetDriver>? drivers}) {
      return [
        authProvider.overrideWith((ref) => MockAuthNotifier(
          loginUseCase: ref.read(loginUseCaseProvider),
          logoutUseCase: ref.read(logoutUseCaseProvider),
          getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
        )),
        stockRepositoryProvider.overrideWithValue(mockStockRepo),
        ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
        localStorageServiceProvider.overrideWithValue(mockStorage),
        if (drivers != null)
          dcConsoleProvider.overrideWith((ref) {
            final notifier = DCConsoleNotifier();
            notifier.state = notifier.state.copyWith(drivers: drivers, isLoading: false);
            return notifier;
          }),
      ];
    }

    test('1. Assigning stock to rider decreases warehouse available stock and updates rider custody', () async {
      final container = ProviderContainer(
        overrides: createTestOverrides(),
      );

      final stockNotifier = container.read(stockProvider.notifier);
      await stockNotifier.fetchStockItems();

      // Verify initial warehouse stock
      final initialWarehouseItem = container.read(stockProvider).stockItems.firstWhere((i) => i.id == 'prod_respira_01');
      expect(initialWarehouseItem.availableCount, 80);

      // Allocate 15 units to Rider Musa (DRV-001)
      final result = await stockNotifier.assignStockToRider(
        productIdOrSku: 'prod_respira_01',
        riderId: 'driver_musa',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        quantity: 15,
      );

      expect(result['success'], isTrue);

      final updatedWarehouseItem = container.read(stockProvider).stockItems.firstWhere((i) => i.id == 'prod_respira_01');
      expect(updatedWarehouseItem.availableCount, 65); // 80 - 15 = 65

      final riderAllocations = container.read(stockProvider).getAllocationsForRider('driver_musa', 'DRV-001');
      final musaAlloc = riderAllocations.firstWhere((a) => a.productId == 'prod_respira_01');
      expect(musaAlloc.inCustodyUnits, 15);
    });

    test('2. Order assignment is REJECTED if rider does not hold the product in vehicle custody', () async {
      final testOrder = OrderModel(
        id: 'ord_test_001',
        orderNumber: 'ORD-99901',
        customerName: 'Amina Bello',
        customerPhone: '08011223344',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Plot 10 Area 1',
        productName: 'Respira Detox Tea',
        status: 'pending',
        quantity: 2,
        basePrice: 50000,
        upsellAmount: 0,
        totalAmount: 50000,
        paymentType: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      mockOrdersRepo.mockOrders = [testOrder];

      final container = ProviderContainer(
        overrides: createTestOverrides(),
      );

      final stockNotifier = container.read(stockProvider.notifier);
      await stockNotifier.fetchStockItems();

      final ordersNotifier = container.read(ordersProvider.notifier);
      await ordersNotifier.loadOrders();

      // Rider "driver_no_stock" has 0 allocations for Respira Detox Tea
      final assigned = await ordersNotifier.assignOrderToRider(
        orderId: 'ord_test_001',
        riderId: 'driver_no_stock',
        riderName: 'John Zero',
        riderCode: 'DRV-ZERO',
      );

      expect(assigned, isFalse);
      expect(container.read(ordersProvider).errorMessage, contains('does not have "Respira Detox Tea" in vehicle custody'));
      expect(container.read(ordersProvider).orders.first.status, 'pending');
    });

    test('3. Order assignment is REJECTED if rider available stock is less than order quantity', () async {
      // Create an existing active in-transit order consuming 4 units
      final activeOrder = OrderModel(
        id: 'ord_active_1',
        orderNumber: 'ORD-88801',
        customerName: 'Chioma Okeke',
        customerPhone: '08055667788',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Adetokunbo Ademola',
        productName: 'Respira Detox Tea',
        status: 'in_transit',
        quantity: 4,
        basePrice: 100000,
        upsellAmount: 0,
        totalAmount: 100000,
        paymentType: 'cod',
        paymentStatus: 'pending',
        deliveryAgentId: 'driver_ahmed',
        deliveryAgentCode: 'DRV-AHMED',
        createdAt: DateTime.now(),
      );

      // Target unassigned order requiring 2 units
      final targetOrder = OrderModel(
        id: 'ord_target_2',
        orderNumber: 'ORD-88802',
        customerName: 'Fatima Sanusi',
        customerPhone: '08099887766',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: 'Gana Street',
        productName: 'Respira Detox Tea',
        status: 'pending',
        quantity: 2,
        basePrice: 50000,
        upsellAmount: 0,
        totalAmount: 50000,
        paymentType: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      mockOrdersRepo.mockOrders = [activeOrder, targetOrder];

      final container = ProviderContainer(
        overrides: createTestOverrides(),
      );

      final stockNotifier = container.read(stockProvider.notifier);
      await stockNotifier.fetchStockItems();

      // Allocate 5 units to Rider Ahmed
      await stockNotifier.assignStockToRider(
        productIdOrSku: 'prod_respira_01',
        riderId: 'driver_ahmed',
        riderName: 'Ahmed Ali',
        riderCode: 'DRV-AHMED',
        quantity: 5,
      );

      final ordersNotifier = container.read(ordersProvider.notifier);
      await ordersNotifier.loadOrders();

      // Total custody = 5, active reserved = 4 -> Available = 1 unit. Order requires 2 units.
      final assigned = await ordersNotifier.assignOrderToRider(
        orderId: 'ord_target_2',
        riderId: 'driver_ahmed',
        riderName: 'Ahmed Ali',
        riderCode: 'DRV-AHMED',
      );

      expect(assigned, isFalse);
      expect(container.read(ordersProvider).errorMessage, contains('insufficient stock (1 available, 2 required)'));
      expect(container.read(ordersProvider).orders.firstWhere((o) => o.id == 'ord_target_2').status, 'pending');
    });

    test('4. Order assignment SUCCEEDS when rider has sufficient available vehicle stock', () async {
      final newOrder = OrderModel(
        id: 'ord_success_1',
        orderNumber: 'ORD-SUCCESS-01',
        customerName: 'Dr. Kabir Usman',
        customerPhone: '08022334455',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Asokoro',
        deliveryAddress: 'Yakubu Gowon Crescent',
        productName: 'Respira Detox Tea',
        status: 'pending',
        quantity: 3,
        basePrice: 75000,
        upsellAmount: 0,
        totalAmount: 75000,
        paymentType: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      mockOrdersRepo.mockOrders = [newOrder];

      final container = ProviderContainer(
        overrides: createTestOverrides(),
      );

      final stockNotifier = container.read(stockProvider.notifier);
      await stockNotifier.fetchStockItems();

      // Allocate 10 units to Rider Emeka
      await stockNotifier.assignStockToRider(
        productIdOrSku: 'prod_respira_01',
        riderId: 'driver_emeka',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        quantity: 10,
      );

      final ordersNotifier = container.read(ordersProvider.notifier);
      await ordersNotifier.loadOrders();

      final assigned = await ordersNotifier.assignOrderToRider(
        orderId: 'ord_success_1',
        riderId: 'driver_emeka',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
      );

      expect(assigned, isTrue);
      final updatedOrder = container.read(ordersProvider).orders.firstWhere((o) => o.id == 'ord_success_1');
      expect(updatedOrder.status, 'in_transit');
      expect(updatedOrder.deliveryAgentId, 'driver_emeka');
    });

    testWidgets('5. DCAssignOrderModal shows stock readiness badges and disables dispatch for low stock riders', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testOrder = OrderModel(
        id: 'ord_modal_1',
        orderNumber: 'ORD-MODAL-01',
        customerName: 'Grace Danjuma',
        customerPhone: '08033445566',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Gwarinpa',
        deliveryAddress: '3rd Avenue',
        productName: 'Respira Detox Tea',
        status: 'pending',
        quantity: 5,
        basePrice: 125000,
        upsellAmount: 0,
        totalAmount: 125000,
        paymentType: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final List<DCFleetDriver> drivers = [
        const DCFleetDriver(
          id: 'driver_ready',
          driverCode: 'DRV-READY',
          name: 'Ready Rider',
          phone: '08011111111',
          avatarUrl: '',
          vehicleModel: 'Bajaj Boxer',
          vehiclePlate: 'ABJ-111-XY',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: 'Abuja Central',
          totalAssignedOrders: 0,
          completedOrders: 0,
          routeProgressPercent: 0,
          efficiencyRating: 100,
          cashInCustody: 0,
          itemsInCustody: 10,
        ),
        const DCFleetDriver(
          id: 'driver_empty',
          driverCode: 'DRV-EMPTY',
          name: 'Empty Rider',
          phone: '08022222222',
          avatarUrl: '',
          vehicleModel: 'Honda Ace',
          vehiclePlate: 'ABJ-222-XY',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: 'Abuja North',
          totalAssignedOrders: 0,
          completedOrders: 0,
          routeProgressPercent: 0,
          efficiencyRating: 100,
          cashInCustody: 0,
          itemsInCustody: 0,
        ),
      ];

      final container = ProviderContainer(
        overrides: createTestOverrides(drivers: drivers),
      );

      await container.read(stockProvider.notifier).fetchStockItems();

      // Allocate 10 units to Ready Rider, 0 to Empty Rider
      await container.read(stockProvider.notifier).assignStockToRider(
        productIdOrSku: 'prod_respira_01',
        riderId: 'driver_ready',
        riderName: 'Ready Rider',
        riderCode: 'DRV-READY',
        quantity: 10,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCAssignOrderModal(order: testOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      // Check that Ready Rider has "Stock Ready (10 in vehicle)" and active Dispatch button
      expect(find.textContaining('Ready Rider'), findsOneWidget);
      expect(find.textContaining('Stock Ready'), findsOneWidget);
      expect(find.text('Dispatch'), findsWidgets);

      // Check that Empty Rider has "No Stock in Vehicle" and "Low Stock" button
      expect(find.textContaining('Empty Rider'), findsOneWidget);
      expect(find.textContaining('No Stock in Vehicle'), findsOneWidget);
      expect(find.text('Low Stock'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 350));
    });
  });
}
