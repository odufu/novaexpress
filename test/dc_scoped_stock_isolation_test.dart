import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';

void main() {
  const otukpoDcId = '00000000-0000-4000-8000-788825051520';
  const dutseDcId = 'dutse-dc-uuid-999';

  late SupabaseClient client;
  late StockRemoteDataSource dataSource;

  setUpAll(() {
    client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );
    dataSource = StockRemoteDataSourceImpl(supabaseClient: client);
  });

  test('DC Scoped Stock Isolation: Otukpo has Grazer Herbal Detox Tea stock, Dutse has 0 in possession', () async {
    // 1. Fetch for Otukpo DC
    final otukpoItems = await dataSource.getVehicleStockItems(null, otukpoDcId);
    expect(otukpoItems.isNotEmpty, isTrue);

    final otukpoGrazer = otukpoItems.firstWhere(
      (item) => item.sku == 'SKU-02900' || item.name.toLowerCase().contains('grazer'),
      orElse: () => throw Exception('Grazer Herbal Detox Tea not found in Otukpo DC stock'),
    );

    print('Otukpo Grazer Stock: ${otukpoGrazer.availableCount} (In DC Possession)');
    expect(otukpoGrazer.availableCount, greaterThan(0));
    expect(otukpoGrazer.availableCount, equals(230));

    // 2. Fetch for Dutse DC
    final dutseItems = await dataSource.getVehicleStockItems(null, dutseDcId);
    expect(dutseItems.isNotEmpty, isTrue);

    final dutseGrazer = dutseItems.firstWhere(
      (item) => item.sku == 'SKU-02900' || item.name.toLowerCase().contains('grazer'),
      orElse: () => throw Exception('Grazer Herbal Detox Tea not found in Dutse DC catalogue'),
    );

    print('Dutse Grazer Stock: ${dutseGrazer.availableCount} (In DC Possession)');
    // Crucial requirement: Product IS visible in Dutse, BUT quantity in Dutse custody is 0!
    expect(dutseGrazer.availableCount, equals(0));
    expect(dutseGrazer.deliveredCount, equals(0));
    expect(dutseGrazer.returnedCount, equals(0));
  });

  test('DC Scoped Product Creation: Product created in Dutse has stock in Dutse, but 0 in Otukpo', () async {
    final testSku = 'SKU-TEST-DUTSE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final created = await dataSource.createProduct(
      name: 'Dutse Organic Moringa Oil',
      sku: testSku,
      category: 'Health & Wellness',
      price: 18500.0,
      stockQuantity: 120,
      ownerName: 'Novacare Limited',
      originDcId: dutseDcId,
    );

    expect(created.sku, equals(testSku));

    // 1. Fetch from Dutse DC
    final dutseList = await dataSource.getVehicleStockItems(null, dutseDcId);
    final dutseItem = dutseList.firstWhere((i) => i.sku == testSku);
    expect(dutseItem.availableCount, equals(120));

    // 2. Fetch from Otukpo DC
    final otukpoList = await dataSource.getVehicleStockItems(null, otukpoDcId);
    final otukpoItem = otukpoList.firstWhere((i) => i.sku == testSku);
    // Product IS visible, but stock in Otukpo possession is 0!
    expect(otukpoItem.availableCount, equals(0));

    // Cleanup test product
    try {
      await client.from('products').delete().eq('sku', testSku);
    } catch (_) {}
  });
}
