import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_transaction_record.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_stock_page.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_rider_detail_modal.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

class MockStockRepository implements StockRepository {
  List<StockItemEntity> items = [
    const StockItemEntity(
      id: 'prod_tea_1',
      sku: 'SKU-RESP-01',
      name: 'Respira Detox Tea',
      description: 'Respira Herbal Detox Tea 20 Sachets',
      price: 25000,
      ownerName: 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 60,
      assignedCount: 10,
      deliveredCount: 0,
      availableCount: 50,
      returnedCount: 0,
      lowStockThreshold: 5,
      category: 'Health & Wellness',
    ),
    const StockItemEntity(
      id: 'prod_tea_2',
      sku: 'SKU-GRAZ-02',
      name: 'Grazer Herbal Tea',
      description: 'Grazer Weight Loss Herbal Tea',
      price: 30000,
      ownerName: 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 20,
      assignedCount: 0,
      deliveredCount: 0,
      availableCount: 20,
      returnedCount: 0,
      lowStockThreshold: 5,
      category: 'Health & Wellness',
    ),
  ];

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async {
    return items;
  }

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return {'status': 'success', 'transfer_id': 'TRF-12345'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalStorageService implements LocalStorageService {
  List<StockItemEntity>? cachedItems;
  List<RiderStockAllocation>? cachedAllocations;

  @override
  Future<void> cacheStockItems(List<StockItemEntity> items) async {
    cachedItems = items;
  }

  @override
  Future<List<StockItemEntity>?> getCachedStockItems() async {
    return cachedItems;
  }

  @override
  Future<void> cacheRiderStockAllocations(List<RiderStockAllocation> allocations) async {
    cachedAllocations = allocations;
  }

  @override
  Future<List<RiderStockAllocation>?> getCachedRiderStockAllocations() async {
    return cachedAllocations;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

void main() {
  group('Connected DC Stock Management & Rider Allocation Tests', () {
    late MockStockRepository mockRepo;
    late MockLocalStorageService mockStorage;
    late StockNotifier stockNotifier;

    setUp(() {
      mockRepo = MockStockRepository();
      mockStorage = MockLocalStorageService();
      mockStorage.cachedAllocations = [];
      mockStorage.cachedItems = mockRepo.items;
      stockNotifier = StockNotifier(
        repository: mockRepo,
        storageService: mockStorage,
      );
      stockNotifier.state = StockState(
        isLoading: false,
        stockItems: mockRepo.items,
        riderAllocations: [],
      );
    });

    test('Initial stock state calculation matches connected warehouse totals', () async {
      await Future.delayed(const Duration(milliseconds: 10));
      final state = stockNotifier.state;

      expect(state.stockItems.length, 2);
      expect(state.totalWarehouseAvailable, 70); // 50 + 20
      expect(state.totalInRiderCustody, 10); // 10 from prod_tea_1
      expect(state.totalDCStock, 80); // 70 + 10
      expect(state.totalDCStockValuation, (60 * 25000.0) + (20 * 30000.0));
    });

    test('addNewProduct registers product and reflects in warehouse available stock', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      final newProduct = await stockNotifier.addNewProduct(
        name: 'Omega 3 Fish Oil',
        sku: 'SKU-OMG-03',
        category: 'Supplements',
        price: 15000,
        ownerName: 'Novacare Limited',
        initialQuantity: 100,
        lowStockThreshold: 10,
        binLocation: 'BIN-B1-05',
      );

      expect(newProduct.name, 'Omega 3 Fish Oil');
      final state = stockNotifier.state;
      expect(state.stockItems.length, 3);
      expect(state.stockItems.first.sku, 'SKU-OMG-03');
      expect(state.totalWarehouseAvailable, 170); // 70 + 100
      expect(state.totalDCStock, 180); // 80 + 100
      expect(mockStorage.cachedItems?.length, 3);
    });

    test('receiveStock increments available warehouse units and total DC custody', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      final success = await stockNotifier.receiveStock(
        productIdOrSku: 'SKU-RESP-01',
        quantity: 50,
        waybillNumber: 'WB-2026-9901',
        binLocation: 'BIN-A1-02',
      );

      expect(success, isTrue);
      final state = stockNotifier.state;
      final updatedItem = state.stockItems.firstWhere((i) => i.sku == 'SKU-RESP-01');
      expect(updatedItem.availableCount, 100); // 50 + 50
      expect(updatedItem.totalInCustody, 110); // 60 + 50
      expect(state.totalWarehouseAvailable, 120); // 100 + 20
    });

    test('assignStockToRider deducts from warehouse, creates allocation, and maintains equilibrium', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      final res = await stockNotifier.assignStockToRider(
        productIdOrSku: 'SKU-RESP-01',
        riderId: 'driver_1',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        quantity: 15,
      );

      expect(res['success'], isTrue);
      final state = stockNotifier.state;
      final updatedItem = state.stockItems.firstWhere((i) => i.sku == 'SKU-RESP-01');

      // Warehouse available was 50 -> 35
      expect(updatedItem.availableCount, 35);
      expect(updatedItem.assignedCount, 25); // 10 + 15

      // Rider allocations list
      expect(state.riderAllocations.length, 1);
      final alloc = state.riderAllocations.first;
      expect(alloc.riderId, 'driver_1');
      expect(alloc.sku, 'SKU-RESP-01');
      expect(alloc.inCustodyUnits, 15);

      // Connected Accounting
      expect(state.totalWarehouseAvailable, 55); // 35 + 20
      expect(state.totalInRiderCustody, 25); // 25
      expect(state.totalDCStock, 80); // Total is invariant under allocation
    });

    test('increaseRiderStock tops up existing rider custody from warehouse stock', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      // Initial assignment
      await stockNotifier.assignStockToRider(
        productIdOrSku: 'SKU-GRAZ-02',
        riderId: 'driver_1',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        quantity: 5,
      );

      // Top up
      final topUpRes = await stockNotifier.increaseRiderStock(
        skuOrName: 'SKU-GRAZ-02',
        riderId: 'driver_1',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        additionalUnits: 5,
      );

      expect(topUpRes['success'], isTrue);
      final state = stockNotifier.state;
      final updatedItem = state.stockItems.firstWhere((i) => i.sku == 'SKU-GRAZ-02');
      expect(updatedItem.availableCount, 10); // 20 - 10

      final riderAllocations = state.getAllocationsForRider('driver_1');
      final alloc = riderAllocations.firstWhere((a) => a.sku == 'SKU-GRAZ-02');
      expect(alloc.inCustodyUnits, 10); // 5 + 5
    });

    test('returnStockFromRider restores units back to warehouse available count', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      // 1. Assign 10 units
      await stockNotifier.assignStockToRider(
        productIdOrSku: 'SKU-RESP-01',
        riderId: 'driver_1',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        quantity: 10,
      );

      // 2. Return 4 units
      final returnRes = await stockNotifier.returnStockFromRider(
        skuOrName: 'SKU-RESP-01',
        riderId: 'driver_1',
        quantity: 4,
      );

      expect(returnRes['success'], isTrue);
      final state = stockNotifier.state;
      final updatedItem = state.stockItems.firstWhere((i) => i.sku == 'SKU-RESP-01');
      expect(updatedItem.availableCount, 44); // 50 - 10 + 4
      expect(updatedItem.returnedCount, 4);

      final riderAllocations = state.getAllocationsForRider('driver_1');
      final alloc = riderAllocations.firstWhere((a) => a.sku == 'SKU-RESP-01');
      expect(alloc.inCustodyUnits, 6); // 10 - 4
    });

    test('recordComplaintOrDamage increments complaint count and decrements rider custody', () async {
      await Future.delayed(const Duration(milliseconds: 10));

      // 1. Assign 10 units
      await stockNotifier.assignStockToRider(
        productIdOrSku: 'SKU-RESP-01',
        riderId: 'driver_1',
        riderName: 'Musa Ibrahim',
        riderCode: 'DRV-001',
        quantity: 10,
      );

      // 2. Report 2 damaged units
      final complaintRes = await stockNotifier.recordComplaintOrDamage(
        productIdOrSku: 'SKU-RESP-01',
        riderId: 'driver_1',
        quantity: 2,
        reason: 'Crushed packaging during transit',
      );

      expect(complaintRes['success'], isTrue);
      final state = stockNotifier.state;
      final updatedItem = state.stockItems.firstWhere((i) => i.sku == 'SKU-RESP-01');
      expect(updatedItem.complaintCount, 2);

      final riderAllocations = state.getAllocationsForRider('driver_1');
      final alloc = riderAllocations.firstWhere((a) => a.sku == 'SKU-RESP-01');
      expect(alloc.inCustodyUnits, 8); // 10 - 2
    });
  });

  group('DC Stock Page & Rider Detail Modal UI Widget Tests', () {
    testWidgets('DCStockPage displays Master Products tab, KPI cards, and Add Product button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final mockRepo = MockStockRepository();
      final container = ProviderContainer(
        overrides: [
          stockProvider.overrideWith((ref) => StockNotifier(repository: mockRepo, storageService: MockLocalStorageService())
            ..state = StockState(
              stockItems: mockRepo.items,
              riderAllocations: StockNotifier.defaultAllocations,
              isLoading: false,
            )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DCStockPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Master Products Tab header
      expect(find.textContaining('Master Products & Inventory'), findsOneWidget);
      expect(find.text('📦 Total DC Stock'), findsOneWidget);
      expect(find.text('🏢 Warehouse Shelf Stock'), findsOneWidget);
      expect(find.text('🛵 In Rider Custody'), findsOneWidget);
      expect(find.text('⚠️ Low Stock Alerts'), findsOneWidget);

      // Verify CTA buttons
      expect(find.text('Receive Stock'), findsWidgets);
      expect(find.text('Add New Product'), findsOneWidget);

      // Verify products rendered
      expect(find.text('Respira Detox Tea'), findsOneWidget);
      expect(find.text('Grazer Herbal Tea'), findsOneWidget);

      // Verify tapping product row opens details modal
      await tester.tap(find.text('Respira Detox Tea'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Merchant / Company:'), findsOneWidget);
      expect(find.textContaining('Novacare Limited'), findsWidgets);
      expect(find.text('🏢 In DC Possession'), findsOneWidget);
      expect(find.text('🛵 In Rider Custody'), findsWidgets);
    });

    testWidgets('DCRiderDetailModal Stock tab shows vehicle custody and Assign New Product CTA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      const testDriver = DCFleetDriver(
        id: 'driver_1',
        name: 'Musa Ibrahim',
        phone: '+234 801 234 5678',
        driverCode: 'DRV-001',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer BM150',
        vehiclePlate: 'ABJ-123-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse 2 Zone',
        totalAssignedOrders: 154,
        completedOrders: 148,
        routeProgressPercent: 96.1,
        efficiencyRating: 4.8,
        cashInCustody: 50000,
        itemsInCustody: 4,
      );

      final mockRepo = MockStockRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(const [])),
            dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(const [testDriver])),
            stockProvider.overrideWith((ref) => StockNotifier(repository: mockRepo, storageService: MockLocalStorageService())
              ..state = StockState(
                stockItems: mockRepo.items,
                riderAllocations: StockNotifier.defaultAllocations,
                isLoading: false,
              )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCRiderDetailModal(driver: testDriver),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stock tab (Tab index 3: Profile, Orders, Remittances, Stock)
      final stockTab = find.text('Stock (2)');
      expect(stockTab, findsOneWidget);
      await tester.tap(stockTab);
      await tester.pumpAndSettle();

      // Verify Assign New Product button in Rider Stock Tab
      expect(find.text('Assign New Product'), findsOneWidget);
      expect(find.text('Vehicle Stock Inventory'), findsOneWidget);
    });
  });
}
