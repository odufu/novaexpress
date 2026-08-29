import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  test('Order creation and DC order pool synchronization', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    final dataSource = OrdersRemoteDataSourceImpl(client);
    final repo = OrdersRepositoryImpl(dataSource);
    final storage = LocalStorageServiceImpl();
    final notifier = OrdersNotifier(repo, null, storage);

    // 1. Fetch DC orders
    final initialOrders = await repo.getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
    print('Initial DC orders in database: ${initialOrders.length}');
    expect(initialOrders.isNotEmpty, isTrue, reason: 'DC orders pool should not be empty');

    // 2. Create a new order via notifier (modal simulation)
    final testOrderNum = 'TRK-VERIF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final payload = {
      'order_number': testOrderNum,
      'customer_name': 'Hauwa Ibrahim',
      'customer_phone': '08033445566',
      'delivery_state': 'FCT - Abuja',
      'delivery_city': 'Maitama',
      'delivery_address': '14 Gana Street, Maitama',
      'landmark': 'Near Transcorp Hilton',
      'product_name': 'Grazer Herbal Detox Tea',
      'quantity': 2,
      'paid_quantity': 2,
      'free_quantity': 0,
      'base_price': 25000.0,
      'upsell_amount': 0.0,
      'total_amount': 50000.0,
      'payment_type': 'pay_on_delivery',
      'payment_status': 'pending',
      'fulfillment_type': 'distributed_inventory',
      'client_name': 'Novacare Limited',
      'client_delivery_fee': 5000.0,
      'agent_entitlement': 2500.0,
      'delivery_notes': 'Please ring gate bell upon arrival',
      'status': 'pending',
      'distribution_center_id': '22222222-2222-4222-8222-222222222222',
      'created_at': DateTime.now().toIso8601String(),
    };

    final createSuccess = await notifier.createOrder(payload);
    expect(createSuccess, isTrue, reason: 'Order creation should succeed');

    // 3. Verify state was updated
    expect(notifier.state.orders.any((o) => o.orderNumber == testOrderNum), isTrue);
    final createdOrder = notifier.state.orders.firstWhere((o) => o.orderNumber == testOrderNum);
    print('Created order in state: #${createdOrder.orderNumber} | ID: ${createdOrder.id} | City: ${createdOrder.deliveryCity} | Total: ₦${createdOrder.totalAmount}');

    // 4. Verify order exists in live Supabase DB
    final dbCheck = await client.from('orders').select('id, order_number').eq('order_number', testOrderNum).maybeSingle();
    expect(dbCheck, isNotNull, reason: 'Created order must exist in live Supabase database');
    print('Verified order in Supabase DB: ${dbCheck!['id']}');

    // 5. Clean up created order from database
    await client.from('orders').delete().eq('id', dbCheck['id']);
    print('Cleaned up test order.');
  }, skip: 'Live DB test - mock seeds wiped from database');
}
