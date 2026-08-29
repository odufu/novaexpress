import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  test('Riders do not share orders and have strictly isolated manifests', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    final dataSource = OrdersRemoteDataSourceImpl(client);
    final repo = OrdersRepositoryImpl(dataSource);
    final storage = LocalStorageServiceImpl();

    const joelAgentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';
    const emekaAgentId = 'b1111111-1111-4111-8111-111111111111';

    // 1. Fetch Joel's assigned orders
    final joelOrders = await repo.getAssignedOrders(joelAgentId);
    print('Joel Odufu assigned orders: ${joelOrders.length}');

    // 2. Fetch Emeka's assigned orders
    final emekaOrders = await repo.getAssignedOrders(emekaAgentId);
    print('Emeka Rider assigned orders: ${emekaOrders.length}');

    // 3. Ensure Joel does not see Emeka's orders (Manifest Isolation)
    final joelOrderIds = joelOrders.map((o) => o.id).toSet();
    final emekaOrderIds = emekaOrders.map((o) => o.id).toSet();
    final sharedOrderIds = joelOrderIds.intersection(emekaOrderIds);
    expect(sharedOrderIds.isEmpty, isTrue, reason: 'Joel and Emeka must have disjoint assigned orders with zero overlap');

    final initialJoelCount = joelOrders.length;

    // 4. Test assigning 1 order specifically to Joel
    final testOrderNum = 'ORD-JOEL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await repo.createOrder({
      'order_number': testOrderNum,
      'customer_name': 'Zainab Ahmed',
      'customer_phone': '08099887766',
      'delivery_state': 'FCT - Abuja',
      'delivery_city': 'Wuse II',
      'delivery_address': 'Plot 55 Crescent',
      'delivery_agent_id': joelAgentId,
      'status': 'assigned',
      'product_name': 'Respira Detox Tea',
      'total_amount': 26000.0,
      'base_price': 26000.0,
      'quantity': 1,
      'payment_type': 'pay_on_delivery',
    });

    // 5. Re-fetch Joel's orders
    final joelUpdatedOrders = await repo.getAssignedOrders(joelAgentId);
    print('Joel Odufu assigned orders after 1 assignment: ${joelUpdatedOrders.length}');
    expect(joelUpdatedOrders.length, equals(initialJoelCount + 1));
    expect(joelUpdatedOrders.any((o) => o.orderNumber == testOrderNum), isTrue);

    // 6. Test scoped caching in LocalStorageService
    await storage.cacheOrders(joelUpdatedOrders, 'rider_$joelAgentId');
    await storage.cacheOrders(emekaOrders, 'rider_$emekaAgentId');

    final joelCached = await storage.getCachedOrders('rider_$joelAgentId');
    final emekaCached = await storage.getCachedOrders('rider_$emekaAgentId');

    expect(joelCached?.length ?? 0, equals(initialJoelCount + 1));
    expect(emekaCached?.length ?? 0, equals(emekaOrders.length));

    // 7. Clean up test order from DB
    await client.from('orders').delete().eq('order_number', testOrderNum);
    print('Cleaned up test order.');
  }, skip: 'Live DB integration test - run manually');
}
