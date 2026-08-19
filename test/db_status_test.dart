import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Check Supabase instance tables & connection', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    print('URL: ${SupabaseConstants.supabaseUrl}');
    try {
      final orders = await client.from('orders').select().limit(5);
      print('Orders table count/sample: ${orders.length}');
      final agents = await client.from('delivery_agents').select().limit(5);
      print('Delivery Agents count/sample: ${agents.length}');
    } catch (e) {
      print('Remote check note: $e');
    }
  });
}
