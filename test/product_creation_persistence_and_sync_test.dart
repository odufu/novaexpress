import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockStockRepository implements StockRepository {
  final List<StockItemModel> mockItems = [];
  final List<RiderStockAllocation> mockAllocations = [];

  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId]) async {
    return mockItems;
  }

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId]) async {
    return mockAllocations;
  }

  @override
  Future<void> updateRiderStockCustody({
    required String riderId,
    required String productId,
    int deliveredDelta = 0,
    int returnedDelta = 0,
    int inCustodyDelta = 0,
  }) async {}

  @override
  Future<StockItemModel> createProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    String? description,
    String? ownerName,
    int stockQuantity = 0,
    int lowStockThreshold = 3,
    String? binLocation,
    String? companyId,
    String? imageAsset,
  }) async {
    final newItem = StockItemModel(
      id: 'prod_test_${DateTime.now().millisecondsSinceEpoch}',
      sku: sku,
      name: name,
      description: description ?? '$name - Distributed Inventory',
      price: price,
      ownerName: ownerName ?? 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: stockQuantity,
      assignedCount: 0,
      deliveredCount: 0,
      availableCount: stockQuantity,
      returnedCount: 0,
      lowStockThreshold: lowStockThreshold,
      category: category,
      imageAsset: imageAsset,
      batchNumber: 'LOT-2026-09',
      lastAuditDate: '2026-09-01',
    );
    mockItems.add(newItem);
    return newItem;
  }

  @override
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  }) async {
    return {'success': true};
  }

  @override
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
  }) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async {
    return {'status': 'success'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product Creation, Packaging & Catalog Suite', () {
    late LocalStorageService storage;
    late ProductCatalogNotifier catalogNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageServiceImpl();
      catalogNotifier = ProductCatalogNotifier(storageService: storage);
    });

    test('1. buildDefaultPackagesForProduct generates standard 1-unit, 2-pack, 3-pack, and 5-pack deals', () {
      final packages = ProductCatalogNotifier.buildDefaultPackagesForProduct(
        productId: 'prod-grazer-101',
        productName: 'Respira Detox Tea',
        productSku: 'SKU-RESP-01',
        baseUnitPrice: 25000.0,
      );

      expect(packages.length, equals(4));

      // 1-Pack
      expect(packages[0].quantity, equals(1));
      expect(packages[0].packagePrice, equals(25000.0));

      // 2-Pack
      expect(packages[1].quantity, equals(2));
      expect(packages[1].packagePrice, equals(35000.0));

      // 3-Pack
      expect(packages[2].quantity, equals(3));
      expect(packages[2].packagePrice, equals(50000.0));

      // 5-Pack Mega Deal (4 + 1 Free)
      expect(packages[3].quantity, equals(5));
      expect(packages[3].paidQuantity, equals(4));
      expect(packages[3].freeQuantity, equals(1));
      expect(packages[3].packagePrice, equals(55000.0));
      expect(packages[3].freeQuantity > 0, isTrue);
    });

    test('2. registerNewProduct adds product with rich commercial packages and caches to local storage', () async {
      final newProd = await catalogNotifier.registerNewProduct(
        name: 'Novacare Gluta Glow',
        sku: 'SKU-GLOW-01',
        baseUnitPrice: 30000.0,
        category: 'Skin & Beauty',
      );

      expect(newProd.name, equals('Novacare Gluta Glow'));
      expect(newProd.packages.length, equals(4));

      // Verify Local Storage Cache
      final cachedCatalog = await storage.getCachedProductCatalog();
      expect(cachedCatalog, isNotNull);
      expect(cachedCatalog!.any((p) => p.sku == 'SKU-GLOW-01'), isTrue);
    });

    test('3. Custom Package Creation, Update, and Deletion', () {
      // Add custom VIP package
      final customPkg = catalogNotifier.addPackageToProduct(
        productName: 'Novacare Gluta Glow',
        packageName: 'VIP 10-Pack Distributor Bundle',
        quantity: 10,
        paidQuantity: 8,
        freeQuantity: 2,
        packagePrice: 100000.0,
        description: 'Distributor Wholesale Tier',
      );

      expect(customPkg.packageName, equals('VIP 10-Pack Distributor Bundle'));
      expect(customPkg.quantity, equals(10));
      expect(customPkg.freeQuantity, equals(2));

      final pkgs = catalogNotifier.state.getPackagesForProduct('Novacare Gluta Glow');
      expect(pkgs.any((p) => p.packageName == 'VIP 10-Pack Distributor Bundle'), isTrue);

      // Update package
      final updatedPkg = catalogNotifier.updatePackage(
        productName: 'Novacare Gluta Glow',
        packageId: customPkg.id,
        packageName: 'VIP 10-Pack Super Bundle',
        quantity: 10,
        packagePrice: 95000.0,
      );
      expect(updatedPkg, isNotNull);
      expect(updatedPkg!.packageName, equals('VIP 10-Pack Super Bundle'));
      expect(updatedPkg.packagePrice, equals(95000.0));

      // Delete package
      final deleted = catalogNotifier.deletePackage(
        productName: 'Novacare Gluta Glow',
        packageId: customPkg.id,
      );
      expect(deleted, isTrue);
      final remainingPkgs = catalogNotifier.state.getPackagesForProduct('Novacare Gluta Glow');
      expect(remainingPkgs.any((p) => p.id == customPkg.id), isFalse);
    });
  });

  group('DC to Rider Stock Lifecycle & Custody Accounting Suite', () {
    late LocalStorageService storage;
    late _MockStockRepository repo;
    late StockNotifier stockNotifier;

    setUp(() {
      storage = LocalStorageServiceImpl();
      repo = _MockStockRepository();
      stockNotifier = StockNotifier(repository: repo, storageService: storage);
    });

    test('4. addNewProduct creates product on repository and updates local cache', () async {
      final created = await stockNotifier.addNewProduct(
        name: 'Omega 3 Fish Oil Max',
        sku: 'SKU-OMEGA-01',
        category: 'Supplements',
        price: 18000.0,
        initialQuantity: 100,
        lowStockThreshold: 10,
      );

      expect(created.name, equals('Omega 3 Fish Oil Max'));
      expect(created.availableCount, equals(100));
      expect(stockNotifier.state.stockItems.any((i) => i.sku == 'SKU-OMEGA-01'), isTrue);

      final cachedItems = await storage.getCachedStockItems();
      expect(cachedItems, isNotNull);
      expect(cachedItems!.any((i) => i.sku == 'SKU-OMEGA-01'), isTrue);
    });

    test('5. recordDeliveredOrderStock auto-deducts vehicle custody and increments delivered count', () async {
      // Setup initial stock and allocation
      await stockNotifier.addNewProduct(
        name: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        category: 'Health & Wellness',
        price: 25000.0,
        initialQuantity: 50,
      );

      final allocation = RiderStockAllocation(
        id: 'alloc-1',
        riderId: 'rider-emeka-1',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        productId: 'SKU-RESP-01',
        productName: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        clientName: 'Novacare Limited',
        inCustodyUnits: 10,
        allocatedUnits: 10,
        deliveredUnits: 0,
        returnedUnits: 0,
        unitPrice: 25000.0,
        allocatedAt: DateTime.now(),
      );

      stockNotifier.state = stockNotifier.state.copyWith(
        riderAllocations: [allocation],
      );

      // Rider delivers a 5-Pack Mega Deal (5 physical units delivered)
      await stockNotifier.recordDeliveredOrderStock(
        productNameOrSku: 'Respira Detox Tea',
        riderId: 'rider-emeka-1',
        physicalQuantity: 5,
      );

      final updatedAlloc = stockNotifier.state.riderAllocations.firstWhere((a) => a.riderId == 'rider-emeka-1');
      expect(updatedAlloc.inCustodyUnits, equals(5)); // 10 - 5 = 5
      expect(updatedAlloc.deliveredUnits, equals(5)); // 0 + 5 = 5

      final updatedStockItem = stockNotifier.state.stockItems.firstWhere((i) => i.name == 'Respira Detox Tea');
      expect(updatedStockItem.availableCount, equals(45)); // 50 - 5 = 45
      expect(updatedStockItem.deliveredCount, equals(5));
    });

    test('6. returnStockToDC returns physical custody to DC and decrements vehicle custody', () async {
      final allocation = RiderStockAllocation(
        id: 'alloc-2',
        riderId: 'rider-emeka-1',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        productId: 'SKU-RESP-01',
        productName: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        clientName: 'Novacare Limited',
        inCustodyUnits: 5,
        allocatedUnits: 10,
        deliveredUnits: 5,
        returnedUnits: 0,
        unitPrice: 25000.0,
        allocatedAt: DateTime.now(),
      );

      stockNotifier.state = stockNotifier.state.copyWith(
        riderAllocations: [allocation],
      );

      final result = await stockNotifier.returnStockToDC(
        productIdOrSku: 'SKU-RESP-01',
        riderId: 'rider-emeka-1',
        quantity: 3,
        reason: 'End of shift surplus return',
      );

      expect(result['success'], isTrue);
      final updatedAlloc = stockNotifier.state.riderAllocations.firstWhere((a) => a.riderId == 'rider-emeka-1');
      expect(updatedAlloc.inCustodyUnits, equals(2)); // 5 - 3 = 2
      expect(updatedAlloc.returnedUnits, equals(3));
    });
  });
}
