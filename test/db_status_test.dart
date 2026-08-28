import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Inspect stock_transfers and stock_transfer_requests columns via insert error hint', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    try {
      await client.from('stock_transfers').insert({'test_col_xyz': 'val'}).select();
    } catch (e) {
      print('stock_transfers insert: $e');
    }

    try {
      await client.from('stock_transfer_requests').insert({'test_col_xyz': 'val'}).select();
    } catch (e) {
      print('stock_transfer_requests insert: $e');
    }

    try {
      await client.from('stock_returns').insert({'test_col_xyz': 'val'}).select();
    } catch (e) {
      print('stock_returns insert: $e');
    }

    try {
      await client.from('inventory_audits').insert({'test_col_xyz': 'val'}).select();
    } catch (e) {
      print('inventory_audits insert: $e');
    }
  });
}
