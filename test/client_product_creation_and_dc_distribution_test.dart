import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockStockRepository implements StockRepository {
  final List<StockItemEntity> storedProducts = [];
  final List<DistributionCenter> dcs = [
    const DistributionCenter(
      id: 'dc-wuse-abuja',
      name: 'Wuse Central Distribution Hub',
      code: 'DC-WUSE-01',
      state: 'Federal Capital Territory',
      city: 'Wuse 2',
      address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
    ),
    const DistributionCenter(
      id: 'dc-otukpo-benue',
      name: 'Otukpo DC',
      code: 'DC-OTUKPO-01',
      state: 'Benue',
      city: 'Otukpo',
      address: 'Enugu Road, Otukpo',
    ),
    const DistributionCenter(
      id: 'dc-ikere-ekiti',
      name: 'Ekiti State DC',
      code: 'DC-EKITI-01',
      state: 'Ekiti',
      city: 'Ikere',
      address: 'Ado-Ikere Way, Ikere Ekiti',
    ),
  ];

  static bool _stateMatches(String dcState, String targetState) {
    final cleanDc = dcState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanTarget = targetState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanDc.isEmpty || cleanTarget.isEmpty) return false;
    if (cleanDc == cleanTarget) return true;
    if (cleanDc.contains(cleanTarget) || cleanTarget.contains(cleanDc)) return true;
    if ((cleanDc.contains('abuja') || cleanDc.contains('fct')) &&
        (cleanTarget.contains('abuja') || cleanTarget.contains('fct'))) {
      return true;
    }
    return false;
  }

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId, String? dcId]) async {
    if (dcId == null || dcId.isEmpty) {
      return storedProducts;
    }

    final targetDc = dcs.firstWhere((d) => d.id == dcId, orElse: () => dcs.first);
    final List<StockItemEntity> dcInventory = [];

    for (final p in storedProducts) {
      final desc = p.description;
      // Parse covering states and dcStocks from description
      final statesMatch = RegExp(r'\[COVERING_STATES:\s*(\[.*?\])\]').firstMatch(desc);
      final dcStocksMatch = RegExp(r'\[DC_STOCKS:\s*(\{.*?\})\]').firstMatch(desc);

      List<String> coveringStates = [];
      if (statesMatch != null) {
        coveringStates = statesMatch.group(1)!
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      Map<String, int> dcStocks = {};
      if (dcStocksMatch != null) {
        final content = dcStocksMatch.group(1)!.replaceAll('{', '').replaceAll('}', '');
        if (content.trim().isNotEmpty) {
          final pairs = content.split(',');
          for (final pair in pairs) {
            final kv = pair.split(':');
            if (kv.length == 2) {
              final k = kv[0].replaceAll('"', '').trim();
              final v = int.tryParse(kv[1].trim()) ?? 0;
              dcStocks[k] = v;
            }
          }
        }
      }

      if (coveringStates.isNotEmpty || dcStocks.isNotEmpty) {
        final matchesState = coveringStates.any((st) => _stateMatches(targetDc.state, st));
        final matchesDc = dcStocks.containsKey(dcId);

        if (matchesState || matchesDc) {
          final scopedQty = dcStocks[dcId] ?? 0;
          dcInventory.add(p.copyWith(
            availableCount: scopedQty,
            totalInCustody: scopedQty,
          ));
        }
      } else {
        // Global legacy product
        dcInventory.add(p);
      }
    }

    return dcInventory;
  }

  @override
  Future<StockItemEntity> createProduct({
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
    String? clientId,
    String? imageAsset,
    String? originDcId,
    List<String>? coveringStates,
    Map<String, int>? dcStocks,
  }) async {
    var desc = description ?? '$name - Distributed Inventory';
    if (coveringStates != null && coveringStates.isNotEmpty) {
      desc = '$desc [COVERING_STATES: ${coveringStates.map((s) => '"$s"').toList()}]';
    }
    if (dcStocks != null && dcStocks.isNotEmpty) {
      final entries = dcStocks.entries.map((e) => '"${e.key}": ${e.value}').join(', ');
      desc = '$desc [DC_STOCKS: {$entries}]';
    }

    final newItem = StockItemModel(
      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
      sku: sku,
      name: name,
      description: desc,
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
      lastAuditDate: '2026-09-09',
    );
    storedProducts.add(newItem);
    return newItem;
  }

  @override
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
    String? distributionCenterId,
  }) async {
    for (var i = 0; i < storedProducts.length; i++) {
      final p = storedProducts[i];
      if (p.sku == productIdOrSku || p.name == productIdOrSku) {
        var desc = p.description;
        Map<String, int> dcStocks = {};
        final dcStocksMatch = RegExp(r'\[DC_STOCKS:\s*(\{.*?\})\]').firstMatch(desc);
        if (dcStocksMatch != null) {
          final content = dcStocksMatch.group(1)!.replaceAll('{', '').replaceAll('}', '');
          if (content.trim().isNotEmpty) {
            final pairs = content.split(',');
            for (final pair in pairs) {
              final kv = pair.split(':');
              if (kv.length == 2) {
                final k = kv[0].replaceAll('"', '').trim();
                final v = int.tryParse(kv[1].trim()) ?? 0;
                dcStocks[k] = v;
              }
            }
          }
        }

        if (distributionCenterId != null) {
          dcStocks[distributionCenterId] = (dcStocks[distributionCenterId] ?? 0) + quantity;
          final entries = dcStocks.entries.map((e) => '"${e.key}": ${e.value}').join(', ');
          if (desc.contains('[DC_STOCKS:')) {
            desc = desc.replaceAll(RegExp(r'\[DC_STOCKS:\s*\{.*?\}\]'), '[DC_STOCKS: {$entries}]');
          } else {
            desc = '$desc [DC_STOCKS: {$entries}]';
          }
        }

        storedProducts[i] = p.copyWith(
          description: desc,
          availableCount: p.availableCount + quantity,
          totalInCustody: p.totalInCustody + quantity,
        );
        return true;
      }
    }
    return true;
  }

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]) async => [];

  @override
  Future<void> updateRiderStockCustody({
    required String riderId,
    required String productId,
    int deliveredDelta = 0,
    int returnedDelta = 0,
    int inCustodyDelta = 0,
  }) async {}

  @override
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> transferStockBetweenDCs({
    required String productIdOrSku,
    required String sourceDcId,
    required String sourceDcName,
    required String destinationDcId,
    required String destinationDcName,
    required int quantity,
    String? notes,
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async => {'status': 'success'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client Product Creation & DC State Distribution Suite', () {
    late LocalStorageService storage;
    late _MockStockRepository stockRepo;
    late StockNotifier stockNotifier;
    late ProductCatalogNotifier catalogNotifier;

    const testClient = ClientProfile(
      id: 'client-novacare-001',
      companyName: 'Novacare Pharmaceuticals',
      contactPerson: 'Dr. Kalu',
      email: 'orders@novacare.ng',
      phone: '+2348039998877',
      address: 'Plot 102 CBD, Abuja',
      city: 'Abuja',
      state: 'Federal Capital Territory',
      tier: 'enterprise',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageServiceImpl();
      stockRepo = _MockStockRepository();
      stockNotifier = StockNotifier(repository: stockRepo, storageService: storage);
      catalogNotifier = ProductCatalogNotifier(storageService: storage);
    });

    test('1. Product created with covering states (Abuja & Benue) initializes at 0 units in matching DCs only', () async {
      const productName = 'Respira Herbal Cleanse';
      const productSku = 'SKU-RESP-CLN';
      const coveringStates = ['Federal Capital Territory', 'Benue'];

      // Resolve matching DCs
      final matchingDcs = stockRepo.dcs.where((dc) {
        return coveringStates.any((st) => _MockStockRepository._stateMatches(dc.state, st));
      }).toList();

      expect(matchingDcs.length, equals(2));
      expect(matchingDcs.any((d) => d.name == 'Wuse Central Distribution Hub'), isTrue);
      expect(matchingDcs.any((d) => d.name == 'Otukpo DC'), isTrue);
      expect(matchingDcs.any((d) => d.name == 'Ekiti State DC'), isFalse);

      // Create product in Stock inventory with dcStocks = { dcId: 0 }
      final dcStocks = <String, int>{ for (final dc in matchingDcs) dc.id: 0 };
      await stockNotifier.addNewProduct(
        name: productName,
        sku: productSku,
        category: 'Health & Wellness',
        price: 28000.0,
        ownerName: testClient.companyName,
        clientId: testClient.id,
        initialQuantity: 0,
        coveringStates: coveringStates,
        dcStocks: dcStocks,
      );

      // Register into catalog
      final catalogProd = await catalogNotifier.registerNewProduct(
        name: productName,
        sku: productSku,
        baseUnitPrice: 28000.0,
        category: 'Health & Wellness',
        clientName: testClient.companyName,
        clientId: testClient.id,
        coveringStates: coveringStates,
      );

      expect(catalogProd.name, equals(productName));
      expect(catalogProd.coveringStates, equals(coveringStates));
      expect(catalogProd.packages.length, equals(4)); // Auto-built package bundles

      // Check Wuse Hub (Abuja - Covered): Product appears in inventory with 0 units
      final wuseStock = await stockRepo.getVehicleStockItems(null, 'dc-wuse-abuja');
      expect(wuseStock.any((i) => i.sku == productSku), isTrue);
      final wuseItem = wuseStock.firstWhere((i) => i.sku == productSku);
      expect(wuseItem.availableCount, equals(0));
      expect(wuseItem.status, equals(StockStatus.outOfStock));

      // Check Otukpo Hub (Benue - Covered): Product appears in inventory with 0 units
      final otukpoStock = await stockRepo.getVehicleStockItems(null, 'dc-otukpo-benue');
      expect(otukpoStock.any((i) => i.sku == productSku), isTrue);
      final otukpoItem = otukpoStock.firstWhere((i) => i.sku == productSku);
      expect(otukpoItem.availableCount, equals(0));

      // Check Ekiti State DC (Ekiti - NOT Covered): Product MUST NOT appear in inventory!
      final ekitiStock = await stockRepo.getVehicleStockItems(null, 'dc-ikere-ekiti');
      expect(ekitiStock.any((i) => i.sku == productSku), isFalse);
    });

    test('2. Client supplies physical stock quantities to NovaExpress covering DCs', () async {
      const productName = 'Respira Herbal Cleanse';
      const productSku = 'SKU-RESP-CLN';
      const coveringStates = ['Federal Capital Territory', 'Benue'];

      // Initial product registration with covering states and 0 initial units
      final matchingDcs = stockRepo.dcs.where((dc) {
        return coveringStates.any((st) => _MockStockRepository._stateMatches(dc.state, st));
      }).toList();
      final dcStocks = <String, int>{ for (final dc in matchingDcs) dc.id: 0 };

      await stockNotifier.addNewProduct(
        name: productName,
        sku: productSku,
        category: 'Health & Wellness',
        price: 28000.0,
        ownerName: testClient.companyName,
        clientId: testClient.id,
        initialQuantity: 0,
        coveringStates: coveringStates,
        dcStocks: dcStocks,
      );

      // Supply 300 units to Wuse Central Hub (Abuja) and 200 units to Otukpo DC (Benue)
      await stockNotifier.receiveStock(
        productIdOrSku: productSku,
        quantity: 300,
        waybillNumber: 'WAYBILL-CLN-001',
        distributionCenterId: 'dc-wuse-abuja',
        supplierName: testClient.companyName,
      );

      await stockNotifier.receiveStock(
        productIdOrSku: productSku,
        quantity: 200,
        waybillNumber: 'WAYBILL-CLN-001',
        distributionCenterId: 'dc-otukpo-benue',
        supplierName: testClient.companyName,
      );

      // Verify Wuse DC now has 300 units available
      final wuseStock = await stockRepo.getVehicleStockItems(null, 'dc-wuse-abuja');
      final wuseItem = wuseStock.firstWhere((i) => i.sku == productSku);
      expect(wuseItem.availableCount, equals(300));
      expect(wuseItem.status, equals(StockStatus.available));

      // Verify Otukpo DC now has 200 units available
      final otukpoStock = await stockRepo.getVehicleStockItems(null, 'dc-otukpo-benue');
      final otukpoItem = otukpoStock.firstWhere((i) => i.sku == productSku);
      expect(otukpoItem.availableCount, equals(200));
      expect(otukpoItem.status, equals(StockStatus.available));

      // Verify Ekiti State DC is STILL completely excluded from having this product
      final ekitiStock = await stockRepo.getVehicleStockItems(null, 'dc-ikere-ekiti');
      expect(ekitiStock.any((i) => i.sku == productSku), isFalse);
    });
  });
}
