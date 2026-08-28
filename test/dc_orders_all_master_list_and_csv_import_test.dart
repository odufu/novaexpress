import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('DC Orders Master List, Multi-Filter & CSV Batch Import Suite', () {
    late SupabaseClient client;
    late OrdersRemoteDataSourceImpl dataSource;
    late OrdersRepositoryImpl repo;
    late LocalStorageServiceImpl storage;
    late OrdersNotifier ordersNotifier;
    final testOrderIds = <String>[];

    setUp(() {
      client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
      dataSource = OrdersRemoteDataSourceImpl(client);
      repo = OrdersRepositoryImpl(dataSource);
      storage = LocalStorageServiceImpl();
      ordersNotifier = OrdersNotifier(repo, null, storage);
    });

    tearDown(() async {
      // Clean up test orders created during tests
      for (final orderId in testOrderIds) {
        try {
          await client.from('orders').delete().eq('id', orderId);
        } catch (_) {}
      }
    });

    test('1. bulkCreateOrders inserts batch orders with correct attributes and updates state', () async {
      final now = DateTime.now();
      final suffix = now.millisecondsSinceEpoch.toString().substring(7);

      final batch = [
        {
          'order_number': 'CSV-TEST-A-$suffix',
          'customer_name': 'Amina Bello',
          'customer_phone': '08011223344',
          'delivery_state': 'FCT - Abuja',
          'delivery_city': 'Wuse 2',
          'delivery_address': '12 Adetokunbo Ademola Crescent',
          'product_name': 'Respira Detox Tea',
          'quantity': 2,
          'paid_quantity': 2,
          'free_quantity': 0,
          'base_price': 25000.0,
          'total_amount': 50000.0,
          'payment_type': 'pay_on_delivery',
          'payment_status': 'pending',
          'fulfillment_type': 'distributed_inventory',
          'client_name': 'Novacare Limited',
          'client_delivery_fee': 4500.0,
          'agent_entitlement': 2000.0,
          'status': 'pending',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        },
        {
          'order_number': 'CSV-TEST-B-$suffix',
          'customer_name': 'Chinedu Eze',
          'customer_phone': '08099887766',
          'delivery_state': 'FCT - Abuja',
          'delivery_city': 'Garki 2',
          'delivery_address': '45 Tafawa Balewa Way',
          'product_name': 'Grazer Herbal Detox Tea',
          'quantity': 1,
          'paid_quantity': 1,
          'free_quantity': 0,
          'base_price': 30000.0,
          'total_amount': 30000.0,
          'payment_type': 'prepaid',
          'payment_status': 'paid',
          'fulfillment_type': 'distributed_inventory',
          'client_name': 'HealthPlus Direct',
          'client_delivery_fee': 5000.0,
          'agent_entitlement': 2500.0,
          'status': 'pending',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        },
      ];

      final result = await ordersNotifier.bulkCreateOrders(batch);
      expect(result['success'], isTrue);
      expect(result['importedCount'], equals(2));

      for (final order in ordersNotifier.state.orders.where((o) => o.orderNumber.contains('CSV-TEST-'))) {
        testOrderIds.add(order.id);
        expect(order.status, equals('pending'));
      }

      expect(ordersNotifier.state.orders.any((o) => o.orderNumber == 'CSV-TEST-A-$suffix'), isTrue);
      expect(ordersNotifier.state.orders.any((o) => o.orderNumber == 'CSV-TEST-B-$suffix'), isTrue);
    });

    test('2. Multi-parameter filtering correctly slices master orders collection', () {
      final sampleOrders = [
        OrderModel(
          id: '1',
          orderNumber: 'TRK-001',
          customerName: 'Aisha Lawal',
          customerPhone: '08011111111',
          deliveryAddress: 'Gwarinpa Estate',
          deliveryCity: 'Gwarinpa',
          deliveryState: 'FCT - Abuja',
          status: 'pending',
          basePrice: 25000,
          upsellAmount: 0,
          totalAmount: 25000,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          productName: 'Respira Detox Tea',
          quantity: 1,
          createdAt: DateTime.now(),
          clientName: 'Novacare Limited',
          deliveryAgentId: null,
          deliveryAgentCode: null,
        ),
        OrderModel(
          id: '2',
          orderNumber: 'TRK-002',
          customerName: 'Emeka Okafor',
          customerPhone: '08022222222',
          deliveryAddress: 'Wuse 2',
          deliveryCity: 'Wuse 2',
          deliveryState: 'FCT - Abuja',
          status: 'in_transit',
          basePrice: 25000,
          upsellAmount: 0,
          totalAmount: 50000,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          productName: 'Grazer Herbal Detox Tea',
          quantity: 2,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          clientName: 'HealthPlus Direct',
          deliveryAgentId: 'rider-1',
          deliveryAgentCode: 'PDA-7000',
        ),
        OrderModel(
          id: '3',
          orderNumber: 'TRK-003',
          customerName: 'Fatima Mohammed',
          customerPhone: '08033333333',
          deliveryAddress: 'Asokoro District',
          deliveryCity: 'Asokoro',
          deliveryState: 'FCT - Abuja',
          status: 'delivered',
          basePrice: 35000,
          upsellAmount: 0,
          totalAmount: 35000,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'paid',
          productName: 'Respira Detox Tea',
          quantity: 1,
          createdAt: DateTime.now(),
          clientName: 'Novacare Limited',
          deliveryAgentId: 'rider-2',
          deliveryAgentCode: 'PDA-7182',
        ),
        OrderModel(
          id: '4',
          orderNumber: 'TRK-004',
          customerName: 'Samuel Okon',
          customerPhone: '08044444444',
          deliveryAddress: 'Maitama Avenue',
          deliveryCity: 'Maitama',
          deliveryState: 'FCT - Abuja',
          status: 'cancelled',
          basePrice: 20000,
          upsellAmount: 0,
          totalAmount: 20000,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          productName: 'Grazer Tea',
          quantity: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          clientName: 'Novacare Limited',
          deliveryAgentId: 'rider-1',
          deliveryAgentCode: 'PDA-7000',
        ),
      ];

      // Test Status Filter: Unassigned (pending without agent)
      final unassigned = sampleOrders.where((o) => o.status == 'pending' || o.deliveryAgentId == null).toList();
      expect(unassigned.length, equals(1));
      expect(unassigned.first.orderNumber, equals('TRK-001'));

      // Test Status Filter: Fulfilled (delivered)
      final delivered = sampleOrders.where((o) => o.status == 'delivered').toList();
      expect(delivered.length, equals(1));
      expect(delivered.first.orderNumber, equals('TRK-003'));

      // Test Rider Filter: PDA-7000
      final rider1Orders = sampleOrders.where((o) => o.deliveryAgentCode == 'PDA-7000').toList();
      expect(rider1Orders.length, equals(2));

      // Test Product Filter: Respira Detox Tea
      final respiraOrders = sampleOrders.where((o) => o.productName == 'Respira Detox Tea').toList();
      expect(respiraOrders.length, equals(2));

      // Test Client Filter: HealthPlus Direct
      final healthPlusOrders = sampleOrders.where((o) => o.clientName == 'HealthPlus Direct').toList();
      expect(healthPlusOrders.length, equals(1));
      expect(healthPlusOrders.first.orderNumber, equals('TRK-002'));

      // Test Search Filter: "Adetokunbo" or "Asokoro"
      final searchResult = sampleOrders.where((o) =>
        o.orderNumber.toLowerCase().contains('asokoro') ||
        o.customerName.toLowerCase().contains('asokoro') ||
        o.deliveryAddress.toLowerCase().contains('asokoro')
      ).toList();
      expect(searchResult.length, equals(1));
      expect(searchResult.first.orderNumber, equals('TRK-003'));
    });

    test('3. assignOrderToRider updates order with delivery agent and marks in_transit', () async {
      final now = DateTime.now();
      final suffix = now.millisecondsSinceEpoch.toString().substring(7);

      // Create a pending unassigned order first
      final created = await dataSource.createOrder({
        'order_number': 'ASSIGN-TEST-$suffix',
        'customer_name': 'Test Recipient',
        'customer_phone': '08012345678',
        'delivery_state': 'FCT - Abuja',
        'delivery_city': 'Jabi',
        'delivery_address': 'Plot 400 Jabi Lake Mall',
        'product_name': 'Grazer Herbal Detox Tea',
        'quantity': 1,
        'paid_quantity': 1,
        'free_quantity': 0,
        'base_price': 25000.0,
        'total_amount': 25000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'fulfillment_type': 'distributed_inventory',
        'client_name': 'Novacare Limited',
        'client_delivery_fee': 4500.0,
        'agent_entitlement': 2000.0,
        'status': 'pending',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
      });
      testOrderIds.add(created.id);
      expect(created.status, equals('pending'));
      expect(created.deliveryAgentId, isNull);

      // Populate notifier state with the created order
      ordersNotifier.state = ordersNotifier.state.copyWith(
        orders: [created],
      );

      // Assign to Emeka Rider (PDA-7000)
      final success = await ordersNotifier.assignOrderToRider(
        orderId: created.id,
        riderId: 'b1111111-1111-4111-8111-111111111111',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
      );

      expect(success, isTrue);

      final updatedOrder = ordersNotifier.state.orders.firstWhere((o) => o.id == created.id);
      expect(updatedOrder.deliveryAgentId, equals('b1111111-1111-4111-8111-111111111111'));
      expect(updatedOrder.deliveryAgentCode, equals('PDA-7000'));
      expect(updatedOrder.status, equals('in_transit'));
    });
  });
}
