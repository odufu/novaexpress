import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Inspect live remittances and orders in Supabase', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    print('\n================ 1. CASH REMITTANCES ================');
    final rems = await client
        .from('cash_remittances')
        .select()
        .order('created_at', ascending: false);

    print('Total cash_remittances: ${rems.length}');
    for (final r in rems) {
      print('Remittance: ID=${r['id']} | Ref=${r['reference_number']} | Agent=${r['delivery_agent_id']} | DC=${r['distribution_center_id']} | Amount=${r['amount']} | Gross=${r['gross_collections']} | Status=${r['status']} | Method=${r['payment_method']} | Notes=${r['notes']}');
    }

    print('\n================ 2. DELIVERY AGENTS ================');
    final agents = await client
        .from('delivery_agents')
        .select('id, name, driver_code, distribution_center_id')
        .limit(10);
    print('Total delivery_agents: ${agents.length}');
    for (final a in agents) {
      print('Agent: ID=${a['id']} | Code=${a['driver_code']} | Name=${a['name']} | DC=${a['distribution_center_id']}');
    }

    print('\n================ 3. DISTRIBUTION CENTERS ================');
    final dcs = await client
        .from('distribution_centers')
        .select('id, name, code')
        .limit(10);
    print('Total distribution_centers: ${dcs.length}');
    for (final d in dcs) {
      print('DC: ID=${d['id']} | Code=${d['code']} | Name=${d['name']}');
    }
  });
}
