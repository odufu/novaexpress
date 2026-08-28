import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';

void main() {
  test('Test StockRemoteDataSource stock creation and assignment to rider', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    final ds = StockRemoteDataSourceImpl(supabaseClient: client);
    final repo = StockRepositoryImpl(remoteDataSource: ds);

    // 1. Test fetching stock for DC
    final dcItems = await repo.getVehicleStockItems();
    print('Fetched ${dcItems.length} products for DC');
    expect(dcItems.isNotEmpty, true);

    // 2. Test createProduct in Supabase
    final testSku = 'TEST-SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final newProduct = await ds.createProduct(
      name: 'Test Herbal Booster',
      sku: testSku,
      category: 'Immunity & Wellness',
      price: 27500.0,
      description: 'Test inventory creation',
      ownerName: 'Novacare Limited',
      stockQuantity: 100,
      lowStockThreshold: 5,
    );
    print('Created Product: ${newProduct.name} (${newProduct.sku}) with ID ${newProduct.id}, available: ${newProduct.availableCount}');
    expect(newProduct.sku, testSku);
    expect(newProduct.availableCount, 100);

    // 3. Test assignStockToRider
    const joelAgentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';
    final assignRes = await ds.assignStockToRider(
      productIdOrSku: newProduct.id,
      riderId: joelAgentId,
      riderName: 'Joel Odufu',
      riderCode: 'DRV-001',
      quantity: 15,
    );
    print('Assign result: $assignRes');
    expect(assignRes['success'], true);
    expect(assignRes['allocatedUnits'], 15);

    // 4. Test receiveStock (Waybill intake)
    final receiveRes = await ds.receiveStock(
      productIdOrSku: newProduct.id,
      quantity: 25,
      waybillNumber: 'WB-TEST-999',
    );
    print('Receive stock result: $receiveRes');
    expect(receiveRes, true);

    // 5. Clean up test product
    try {
      await client.from('products').delete().eq('sku', testSku);
      print('Cleaned up test product');
    } catch (_) {}
  });
}
