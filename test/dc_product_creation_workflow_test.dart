import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_transaction_record.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_stock_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockStockRepository implements StockRepository {
  final List<StockItemModel> mockItems = [
    const StockItemModel(
      id: 'prod_existing_1',
      sku: 'SKU-EXISTING',
      name: 'Existing Product',
      description: 'Existing description',
      price: 15000.0,
      ownerName: 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 100,
      assignedCount: 0,
      deliveredCount: 0,
      availableCount: 100,
      returnedCount: 0,
      lowStockThreshold: 5,
      category: 'Health & Wellness',
    ),
  ];

  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId]) async {
    return List.from(mockItems);
  }

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId]) async {
    return [];
  }

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
    if (sku.toUpperCase() == 'SKU-FAIL') {
      throw Exception('Simulated database write timeout error.');
    }
    final newItem = StockItemModel(
      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
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
    );
    mockItems.add(newItem);
    return newItem;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLocalStorageService implements LocalStorageService {
  List<StockItemEntity>? cachedItems;
  List<RiderStockAllocation>? cachedAllocations;
  Map<String, dynamic>? cachedUser;
  List<CatalogProduct>? cachedCatalog;
  List<DCWarehouseBatch>? cachedBatches;

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
    return cachedAllocations ?? [];
  }

  @override
  Future<void> cacheUserProfile(Map<String, dynamic> user) async {
    cachedUser = user;
  }

  @override
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    return cachedUser;
  }

  @override
  Future<void> cacheProductCatalog(List<CatalogProduct> products) async {
    cachedCatalog = products;
  }

  @override
  Future<List<CatalogProduct>?> getCachedProductCatalog() async {
    return cachedCatalog ?? [];
  }

  @override
  Future<void> cacheWarehouseBatches(List<DCWarehouseBatch> batches) async {
    cachedBatches = batches;
  }

  @override
  Future<List<DCWarehouseBatch>?> getCachedWarehouseBatches() async {
    return cachedBatches ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DC Product Registration Modal & Feedback Flow Tests', () {
    testWidgets('1. Successfully registers product and renders Product Registered Successfully modal', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRepo = _MockStockRepository();
      final storage = _MockLocalStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockRepositoryProvider.overrideWithValue(mockRepo),
            localStorageServiceProvider.overrideWithValue(storage),
            productCatalogProvider.overrideWith((ref) => ProductCatalogNotifier(storageService: storage)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCStockPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Add New Product modal
      final addBtn = find.text('Add New Product');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Register New Product'), findsOneWidget);

      // Enter Product Name
      final nameField = find.widgetWithText(TextField, 'Product Name *');
      await tester.enterText(nameField, 'Compression Vest');

      // Enter unique SKU
      final skuField = find.widgetWithText(TextField, 'SKU / Barcode Code *');
      await tester.enterText(skuField, 'SKU-78303');

      // Save & Register
      final saveBtn = find.text('Save & Register Product');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Expect Success Modal
      expect(find.text('Product Registered Successfully!'), findsOneWidget);
      expect(find.text('The product has been enrolled in the master catalogue and assigned warehouse shelf inventory.'), findsOneWidget);
      expect(find.text('Back to Product List'), findsOneWidget);

      // Tap Back to Product List
      await tester.tap(find.text('Back to Product List'));
      await tester.pumpAndSettle();

      // Ensure success modal dismissed and we are back on the catalogue
      expect(find.text('Product Registered Successfully!'), findsNothing);
      expect(find.text('Register New Product'), findsNothing);
      expect(find.text('Master Products & Inventory (2)'), findsOneWidget);
    });

    testWidgets('2. Displays failure modal when duplicate SKU is entered and preserves form fields', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRepo = _MockStockRepository();
      final storage = _MockLocalStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockRepositoryProvider.overrideWithValue(mockRepo),
            localStorageServiceProvider.overrideWithValue(storage),
            productCatalogProvider.overrideWith((ref) => ProductCatalogNotifier(storageService: storage)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCStockPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Add New Product modal
      await tester.tap(find.text('Add New Product'));
      await tester.pumpAndSettle();

      // Enter Name
      await tester.enterText(find.widgetWithText(TextField, 'Product Name *'), 'Duplicate Vest');
      // Enter already registered SKU
      await tester.enterText(find.widgetWithText(TextField, 'SKU / Barcode Code *'), 'SKU-EXISTING');

      // Tap Save
      await tester.tap(find.text('Save & Register Product'));
      await tester.pumpAndSettle();

      // Expect Failure Modal with reason
      expect(find.text('Product Registration Failed'), findsOneWidget);
      expect(find.textContaining('already exists'), findsOneWidget);
      expect(find.text('Back to Product Details'), findsOneWidget);

      // Tap Back to Product Details
      await tester.tap(find.text('Back to Product Details'));
      await tester.pumpAndSettle();

      // Verify that the form is still open and input is preserved
      expect(find.text('Register New Product'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Duplicate Vest'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'SKU-EXISTING'), findsOneWidget);
    });
  });
}
