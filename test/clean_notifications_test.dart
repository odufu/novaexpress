import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Inspect and clean dummy notifications in Supabase database', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    try {
      final res = await client.from('notifications').select('*');
      print('Total notifications in DB before cleanup: ${res.length}');

      // Delete repetitive test notifications (e.g. RMT-PENDING test loops)
      await client
          .from('notifications')
          .delete()
          .ilike('message', '%RMT-PENDING%');
      
      await client
          .from('notifications')
          .delete()
          .ilike('message', '%20202020-2020-4020-8020-505050505050%');

      final remaining = await client.from('notifications').select('*');
      print('Remaining notifications in DB after cleanup: ${remaining.length}');
      for (final n in remaining) {
        print(' - [${n["delivery_agent_id"]}] ${n["title"]}: ${n["message"]}');
      }
    } catch (e) {
      print('Error cleaning notifications: $e');
    }
  });
}
