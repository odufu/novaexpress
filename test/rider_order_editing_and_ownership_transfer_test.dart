import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Rider Order Product Editing & Ownership Transfer Integration Suite (Live Remote DB)', () {
    late SupabaseClient client;
    late PipelineChatRemoteDataSourceImpl chatDataSource;

    setUp(() {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      chatDataSource = PipelineChatRemoteDataSourceImpl(client);
    });

    tearDown(() {
      client.dispose();
    });

    test('1. Verify RPC transfer_order_product_and_ownership exists and functions', () async {
      // Fetch an active order to perform test transfer
      final orders = await client
          .from(SupabaseConstants.ordersTable)
          .select('id, order_number, product_id, product_name, package_deal_name, total_amount, client_id, client_name')
          .limit(1);

      expect((orders as List).isNotEmpty, isTrue, reason: 'Must have at least one test order');
      final targetOrder = orders.first;
      final orderId = targetOrder['id'].toString();

      // Fetch a valid product from database
      final products = await client
          .from('products')
          .select('id, name, client_id, base_price')
          .limit(2);

      expect((products as List).isNotEmpty, isTrue, reason: 'Must have products in remote catalog');
      final selectedProduct = products.first;
      final newProductId = selectedProduct['id'].toString();
      final newBasePrice = (selectedProduct['base_price'] as num?)?.toDouble() ?? 25000.0;
      final newTotal = newBasePrice * 2;

      // 1a. Verify that direct rider modification is strictly REJECTED by Postgres security guard
      expect(
        () => chatDataSource.transferOrderProductAndOwnership(
          orderId: orderId,
          newProductId: newProductId,
          newPackageDealId: 'pkg_test_2pack',
          newPackageName: '2 Packs Test Deal',
          newQuantity: 2,
          newPaidQuantity: 2,
          newFreeQuantity: 0,
          newBasePrice: newBasePrice,
          newTotalAmount: newTotal,
          actorName: 'Emeka Rider (PDA-7000)',
          actorRole: 'rider',
          transferReason: 'Rider attempting direct product modification.',
        ),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('Riders are restricted from directly modifying order products or package deals'),
        )),
      );

      // 1b. Verify that Handling DC Operations is AUTHORIZED and successfully executes the modification
      final rpcResult = await chatDataSource.transferOrderProductAndOwnership(
        orderId: orderId,
        newProductId: newProductId,
        newPackageDealId: 'pkg_test_2pack',
        newPackageName: '2 Packs Test Deal',
        newQuantity: 2,
        newPaidQuantity: 2,
        newFreeQuantity: 0,
        newBasePrice: newBasePrice,
        newTotalAmount: newTotal,
        actorName: 'Abuja Central DC Operations',
        actorRole: 'dc_manager',
        transferReason: 'Customer requested 2-pack deal upgrade via rider chat tag.',
      );

      expect(rpcResult['success'], isTrue);
      expect(rpcResult['order_id'], equals(orderId));

      // Verify that the order record in database was updated
      final updatedOrder = await client
          .from(SupabaseConstants.ordersTable)
          .select('id, product_id, package_deal_name, total_amount, quantity')
          .eq('id', orderId)
          .single();

      expect(updatedOrder['product_id'], equals(newProductId));
      expect(updatedOrder['package_deal_name'], equals('2 Packs Test Deal'));
      expect((updatedOrder['total_amount'] as num).toDouble(), equals(newTotal));
      expect(updatedOrder['quantity'], equals(2));
    });

    test('2. Verify Cross-Merchant Ownership Transfer and Audit Trail in Database', () async {
      // Find two products with different client_ids
      final allProducts = await client
          .from('products')
          .select('id, name, client_id, base_price')
          .limit(10);

      final prodList = (allProducts as List).cast<Map<String, dynamic>>();
      if (prodList.length < 2) return;

      final firstProduct = prodList.first;
      final secondProduct = prodList.firstWhere(
        (p) => p['client_id'] != firstProduct['client_id'],
        orElse: () => prodList.last,
      );

      // Fetch target order
      final orders = await client
          .from(SupabaseConstants.ordersTable)
          .select('id, order_number, product_id, client_id, client_name')
          .limit(1);

      final orderId = orders.first['id'].toString();
      final originalClientId = orders.first['client_id']?.toString();

      // Switch to secondProduct via Handling DC Operations
      final rpcResult = await chatDataSource.transferOrderProductAndOwnership(
        orderId: orderId,
        newProductId: secondProduct['id'].toString(),
        newPackageDealId: 'pkg_cross_transfer',
        newPackageName: 'Cross-Merchant Promo Deal',
        newQuantity: 1,
        newPaidQuantity: 1,
        newFreeQuantity: 0,
        newBasePrice: (secondProduct['base_price'] as num?)?.toDouble() ?? 20000.0,
        newTotalAmount: (secondProduct['base_price'] as num?)?.toDouble() ?? 20000.0,
        actorName: 'Abuja Central DC Operations',
        actorRole: 'dc_manager',
        transferReason: 'Customer switched brands upon inspection; approved by Handling DC.',
      );

      expect(rpcResult['success'], isTrue);

      // Verify order table reflects the change
      final refreshedOrder = await client
          .from(SupabaseConstants.ordersTable)
          .select('id, client_id, original_client_id, ownership_transferred_at, ownership_transfer_reason')
          .eq('id', orderId)
          .single();

      if (secondProduct['client_id'] != originalClientId) {
        expect(refreshedOrder['original_client_id'], isNotNull);
        expect(refreshedOrder['client_id'], equals(secondProduct['client_id']));
        expect(refreshedOrder['ownership_transferred_at'], isNotNull);
        expect(refreshedOrder['ownership_transfer_reason'], contains('switched brands'));
      }

      // Verify automated audit message was logged in order_conversation_messages
      final messages = await client
          .from('order_conversation_messages')
          .select()
          .eq('order_id', orderId)
          .or('message_type.eq.ownership_transferred,message_type.eq.product_changed')
          .order('created_at', ascending: false)
          .limit(1);

      expect((messages as List).isNotEmpty, isTrue);
      final latestMsg = messages.first;
      expect(latestMsg['message_type'], anyOf(equals('ownership_transferred'), equals('product_changed')));
      expect(latestMsg['metadata'], isNotNull);
      expect(latestMsg['metadata']['reason'], contains('switched brands'));
    });

    test('3. Verify Strict Package Deal Price Locking from public.product_packages', () async {
      // Fetch an authentic package from product_packages
      final dbPackages = await client
          .from('product_packages')
          .select()
          .limit(1);

      expect((dbPackages as List).isNotEmpty, isTrue, reason: 'Must have seeded product_packages in database');
      final authenticPkg = (dbPackages as List).first as Map<String, dynamic>;
      final pkgId = authenticPkg['id'].toString();
      final expectedPrice = (authenticPkg['package_price'] as num).toDouble();
      final pkgUnits = (authenticPkg['quantity'] as num).toInt();
      final targetProductId = authenticPkg['product_id'].toString();

      // Fetch target order
      final orders = await client
          .from(SupabaseConstants.ordersTable)
          .select('id')
          .limit(1);

      final orderId = orders.first['id'].toString();

      // Attempt transfer passing a bogus price of 999,999.00
      // Stored procedure must authoritatively lock the order total to authenticPkg.packagePrice
      final rpcResult = await chatDataSource.transferOrderProductAndOwnership(
        orderId: orderId,
        newProductId: targetProductId,
        newPackageDealId: pkgId,
        newPackageName: authenticPkg['package_name'].toString(),
        newQuantity: pkgUnits,
        newPaidQuantity: (authenticPkg['paid_quantity'] as num?)?.toInt() ?? pkgUnits,
        newFreeQuantity: (authenticPkg['free_quantity'] as num?)?.toInt() ?? 0,
        newBasePrice: 999999.0, // Bogus price should be overridden
        newTotalAmount: 999999.0, // Bogus price should be overridden
        actorName: 'DC Operations Pricing Guard',
        actorRole: 'dc_manager',
        transferReason: 'Testing strict package deal price locking by DC Operations',
      );

      expect(rpcResult['success'], isTrue);

      // Verify in DB that total_amount matches expectedPrice, NOT 999999.0
      final refreshedOrder = await client
          .from(SupabaseConstants.ordersTable)
          .select('total_amount, quantity, package_deal_name')
          .eq('id', orderId)
          .single();

      expect((refreshedOrder['total_amount'] as num).toDouble(), equals(expectedPrice));
      expect(refreshedOrder['quantity'], equals(pkgUnits));
      expect(refreshedOrder['package_deal_name'], equals(authenticPkg['package_name']));
    });
  });
}
