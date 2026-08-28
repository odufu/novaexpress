import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Inspect Remittances, Stock, and Products in Supabase', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseAnonKey,
    );

    print('\n================ 1. RECENT CASH REMITTANCES ================');
    final rems = await client
        .from('cash_remittances')
        .select()
        .order('created_at', ascending: false)
        .limit(10);

    for (final r in rems) {
      print('ID: ${r['id']} | Ref: ${r['reference_number']} | Amount: ${r['amount']} | Status: ${r['status']} | VerifiedAt: ${r['verified_at']} | Agent: ${r['delivery_agent_id']} | Method: ${r['payment_method']}');
    }

    print('\n================ 2. JOEL ODUFU ORDERS ================');
    const joelAgentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';
    final orders = await client
        .from('orders')
        .select()
        .eq('delivery_agent_id', joelAgentId);
    print('Total Orders for Joel: ${orders.length}');
    final deliveredOrders = orders.where((o) => o['status'] == 'delivered').toList();
    print('Delivered Orders for Joel: ${deliveredOrders.length}');
    for (final o in orders.take(5)) {
      print('Order #${o['order_number']} | Status: ${o['status']} | Amount: ${o['total_amount']} | Product: ${o['product_name']} | Qty: ${o['quantity']} | Remitted: ${o['is_remitted']}');
    }

    print('\n================ 3. STOCK ALLOCATIONS IN SUPABASE ================');
    try {
      final stockAllocations = await client
          .from('product_stock_custody')
          .select()
          .limit(15);
      print('Total product_stock_custody rows: ${stockAllocations.length}');
      for (final s in stockAllocations) {
        print('Stock Row: $s');
      }
    } catch (e) {
      print('Product stock custody notice: $e');
    }

    print('\n================ 4. PRODUCTS IN SUPABASE ================');
    final products = await client.from('products').select();
    print('Total products in catalog: ${products.length}');
    for (final p in products) {
      print('Product ID: ${p['id']} | Name: ${p['name']} | Price: ${p['base_price']}');
    }
  });
}
