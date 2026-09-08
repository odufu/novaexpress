import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';

class _FakeLocalStorageService extends Fake implements LocalStorageService {
  @override
  Future<List<StockItemEntity>?> getCachedStockItems() async => [];

  @override
  Future<List<RiderStockAllocation>?> getCachedRiderStockAllocations() async => [];

  @override
  Future<void> cacheStockItems(List<StockItemEntity> items) async {}

  @override
  Future<void> cacheRiderStockAllocations(List<RiderStockAllocation> allocs) async {}
}

class _FakeStockRepository extends Fake implements StockRepository {
  @override
  Future<Map<String, dynamic>> transferStockBetweenDCs({
    required String productIdOrSku,
    required String sourceDcId,
    required String sourceDcName,
    required String destinationDcId,
    required String destinationDcName,
    required int quantity,
    String? notes,
  }) async {
    return {
      'success': true,
      'waybillNumber': 'WB-DC-TEST-001',
      'message': 'Successfully dispatched $quantity units to $destinationDcName',
    };
  }
}

void main() {
  group('Inter-DC Stock Transfer Architecture & State Management Suite', () {
    late ProviderContainer container;
    late _FakeStockRepository fakeRepo;
    late _FakeLocalStorageService fakeStorage;

    setUp(() {
      fakeRepo = _FakeStockRepository();
      fakeStorage = _FakeLocalStorageService();
      container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(fakeRepo),
          localStorageServiceProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('1. transferStockBetweenDCs successfully deducts shelf stock and generates waybill', () async {
      final notifier = container.read(stockProvider.notifier);

      // Seed initial stock
      const initialItem = StockItemEntity(
        id: 'prod-detox-001',
        name: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        category: 'Health',
        description: 'Herbal detox tea product',
        price: 25000,
        availableCount: 50,
        assignedCount: 0,
        deliveredCount: 0,
        returnedCount: 0,
        totalInCustody: 50,
      );

      notifier.state = notifier.state.copyWith(stockItems: [initialItem]);

      // Transfer 15 units to another DC
      final result = await notifier.transferStockBetweenDCs(
        productIdOrSku: 'prod-detox-001',
        sourceDcId: '22222222-2222-4222-8222-222222222222',
        sourceDcName: 'Wuse Central Distribution Hub',
        destinationDcId: '33333333-3333-4333-8333-333333333333',
        destinationDcName: 'Ikeja Commercial Hub DC',
        quantity: 15,
        notes: 'Replenishing Ikeja DC due to high regional demand',
      );

      expect(result['success'], isTrue);
      expect(result['transferredUnits'], equals(15));
      expect(result['remainingWarehouseStock'], equals(35));
      expect(result['waybillNumber'], equals('WB-DC-TEST-001'));

      // Check in-memory state deduction
      final updatedItem = container.read(stockProvider).stockItems.first;
      expect(updatedItem.availableCount, equals(35));
      expect(updatedItem.totalInCustody, equals(35));
    });

    test('2. transferStockBetweenDCs rejects transfer when requested quantity exceeds available balance', () async {
      final notifier = container.read(stockProvider.notifier);

      const initialItem = StockItemEntity(
        id: 'prod-detox-001',
        name: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        category: 'Health',
        description: 'Herbal detox tea product',
        price: 25000,
        availableCount: 10,
        assignedCount: 0,
        deliveredCount: 0,
        returnedCount: 0,
        totalInCustody: 10,
      );

      notifier.state = notifier.state.copyWith(stockItems: [initialItem]);

      // Attempt transferring 25 units when only 10 are available
      final result = await notifier.transferStockBetweenDCs(
        productIdOrSku: 'prod-detox-001',
        sourceDcId: '22222222-2222-4222-8222-222222222222',
        sourceDcName: 'Wuse Central Distribution Hub',
        destinationDcId: '33333333-3333-4333-8333-333333333333',
        destinationDcName: 'Ikeja Commercial Hub DC',
        quantity: 25,
      );

      expect(result['success'], isFalse);
      expect(result['message'], contains('Insufficient warehouse stock'));

      // Inventory remains untouched
      final unchangedItem = container.read(stockProvider).stockItems.first;
      expect(unchangedItem.availableCount, equals(10));
    });
  });
}
