import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/widgets/product_image_widget.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_product_detail_modal.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockStockImageRepository implements StockRepository {
  final List<StockItemEntity> items = [];

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async {
    return items;
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
    String? imageAsset,
  }) async {
    final newItem = StockItemEntity(
      id: 'prod_${sku.toLowerCase()}',
      sku: sku,
      name: name,
      description: description ?? name,
      price: price,
      ownerName: ownerName ?? 'Novacare Limited',
      category: category,
      availableCount: stockQuantity,
      totalInCustody: stockQuantity,
      assignedCount: 0,
      deliveredCount: 0,
      returnedCount: 0,
      lowStockThreshold: lowStockThreshold,
      imageAsset: imageAsset,
      binLocation: binLocation ?? 'BIN-A1-01',
    );
    items.add(newItem);
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
  }) async => {'success': true};

  @override
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
    String? binLocation,
  }) async => true;

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async => {'success': true};

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent GIF base64
  const sampleBase64Image = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

  group('Product Image Upload & Stocks Display Test Suite', () {
    testWidgets('ProductImageWidget renders base64 data URI without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProductImageWidget(
                imageUrl: sampleBase64Image,
                width: 64,
                height: 64,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductImageWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ProductImageWidget renders graceful fallback icon when imageUrl is null/empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProductImageWidget(
                imageUrl: null,
                width: 48,
                height: 48,
                fallbackIcon: Icons.inventory_2_outlined,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    test('StockNotifier.addNewProduct persists imageAsset into state', () async {
      final mockRepo = MockStockImageRepository();
      final container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(stockProvider.notifier);

      final created = await notifier.addNewProduct(
        name: 'ImmunoShield Premium',
        sku: 'SKU-IMM-01',
        category: 'Health',
        price: 35000,
        initialQuantity: 100,
        imageAsset: sampleBase64Image,
      );

      expect(created.name, 'ImmunoShield Premium');
      expect(created.sku, 'SKU-IMM-01');
      expect(created.imageAsset, sampleBase64Image);

      final state = container.read(stockProvider);
      expect(state.stockItems.any((i) => i.sku == 'SKU-IMM-01' && i.imageAsset == sampleBase64Image), isTrue);
    });

    testWidgets('DCProductDetailModal renders ProductImageWidget in header with attached image', (tester) async {
      final item = StockItemEntity(
        id: 'prod-001',
        sku: 'SKU-RESP-01',
        name: 'Respira Herbal Blend',
        description: 'Herbal respiratory remedy',
        price: 25000,
        ownerName: 'Novacare Labs',
        category: 'Wellness',
        availableCount: 45,
        totalInCustody: 50,
        assignedCount: 5,
        deliveredCount: 0,
        returnedCount: 0,
        imageAsset: sampleBase64Image,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCProductDetailModal(
                item: item,
                drivers: const [],
                allocations: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Respira Herbal Blend'), findsOneWidget);
      expect(find.byType(ProductImageWidget), findsOneWidget);
    });
  });
}
