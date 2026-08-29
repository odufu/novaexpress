import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Inspect live remittances and orders for Joel in Supabase', () async {
  }, skip: 'Diagnostic script requiring live database');
  /*
  test('Inspect live remittances and orders for Joel in Supabase', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    const agentId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9';

    print('\n================ 1. REMITTANCES FOR JOEL ================');
    final rems = await client
        .from('cash_remittances')
        .select()
        .eq('delivery_agent_id', agentId)
        .order('created_at', ascending: false);

    print('Total remittances for Joel: ${rems.length}');
    for (final r in rems) {
      print('Remittance: ID=${r['id']} | Ref=${r['reference_number']} | Amount=${r['amount']} | Gross=${r['gross_collections']} | Comm=${r['commission_deducted']} | Trans=${r['transport_allowance_deducted']} | Status=${r['status']} | Notes=${r['notes']}');
    }

    print('\n================ 2. ORDERS FOR JOEL ================');
    final orders = await client
        .from('orders')
        .select()
        .eq('delivery_agent_id', agentId)
        .order('created_at', ascending: false);

    print('Total orders for Joel: ${orders.length}');
    for (final o in orders) {
      print('Order: #${o['order_number']} | Status=${o['status']} | Total=${o['total_amount']} | RemitStatus=${o['remittance_status']} | Notes=${o['delivery_notes']}');
    }
  });
  */
}
