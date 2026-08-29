import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Test end-to-end live stock transfer creation with valid source warehouse ID', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    const riderId = 'c32c038f-ff3d-4a4f-867d-a749092fb2a9'; // Joel Odufu / PDA-7182
    const riderName = 'Joel Odufu';
    const riderCode = 'PDA-7182';
    const prodId = '1f6ed952-0f47-413e-b5a8-e10ca0621d76'; // Grazer Herbal Detox Tea
    const dcId = 'c2222222-2222-4222-8222-222222222222'; // Abuja Regional Hub
    const adminUserId = '00000000-0000-4000-8000-000000000000';

    // 1. Resolve or create rider warehouse
    String? riderWarehouseId;
    final wRes = await client.from('warehouses').select('id').eq('rider_id', riderId).limit(1);
    if ((wRes as List).isNotEmpty) {
      riderWarehouseId = wRes.first['id'].toString();
    } else {
      final newW = await client.from('warehouses').insert({
        'company_id': '11111111-1111-4111-8111-111111111111',
        'rider_id': riderId,
        'name': '$riderName ($riderCode) Vehicle Stock',
        'type': 'rider_mini_hub',
        'location_state': 'Abuja (FCT)',
        'address': 'Vehicle Mobile Custody',
        'is_active': true,
      }).select().single();
      riderWarehouseId = newW['id'].toString();
    }

    print('Rider warehouse ID: $riderWarehouseId');

    // 2. Insert stock_transfer with waybill_number and initiated_by_user_id
    final wbNumber = 'WB-TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trf = await client.from('stock_transfers').insert({
      'waybill_number': wbNumber,
      'company_id': '11111111-1111-4111-8111-111111111111',
      'source_warehouse_id': dcId,
      'destination_warehouse_id': riderWarehouseId,
      'initiated_by_user_id': adminUserId,
      'status': 'completed',
      'notes': 'DC Handover to $riderName ($riderCode)',
    }).select().single();

    final trfId = trf['id'].toString();
    print('✅ Created transfer ID: $trfId | Waybill: $wbNumber');

    // 3. Insert stock_transfer_items
    final trfItem = await client.from('stock_transfer_items').insert({
      'transfer_id': trfId,
      'product_id': prodId,
      'count': 10,
    }).select().single();

    print('✅ Created transfer item: $trfItem');

    // 4. Query stock transfers and items for rider
    final riderWarehouses = await client.from('warehouses').select('id').eq('rider_id', riderId);
    final wIds = (riderWarehouses as List).map((w) => w['id'].toString()).toList();

    final transfers = await client
        .from('stock_transfers')
        .select('id, waybill_number, destination_warehouse_id, status, created_at, stock_transfer_items(id, product_id, count)')
        .filter('destination_warehouse_id', 'in', wIds);

    print('✅ Fetched live transfers with items: $transfers');
  });
}
