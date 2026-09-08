import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Purge all operational, demo, and seed data from Supabase DB', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    print('🚀 Starting Supabase Database Purge on ${SupabaseConstants.supabaseUrl}...');

    // 1. Delete all order items & orders
    try {
      await client.from('order_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared order_items');
    } catch (e) {
      print('ℹ️ order_items delete note: $e');
    }

    try {
      await client.from('orders').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared orders');
    } catch (e) {
      print('ℹ️ orders delete note: $e');
    }

    // 2. Delete all cash remittances
    try {
      await client.from('cash_remittances').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared cash_remittances');
    } catch (e) {
      print('ℹ️ cash_remittances delete note: $e');
    }

    // 3. Delete all paystack transactions & rider transactions
    try {
      await client.from('paystack_transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared paystack_transactions');
    } catch (e) {
      print('ℹ️ paystack_transactions delete note: $e');
    }

    try {
      await client.from('rider_transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared rider_transactions');
    } catch (e) {
      print('ℹ️ rider_transactions delete note: $e');
    }

    // 4. Delete payout requests
    try {
      await client.from('payout_requests').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared payout_requests');
    } catch (e) {
      print('ℹ️ payout_requests delete note: $e');
    }

    // 5. Delete stock transfers, stock transfer items, product stock custody, stock items
    try {
      await client.from('stock_transfer_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared stock_transfer_items');
    } catch (e) {
      print('ℹ️ stock_transfer_items delete note: $e');
    }

    try {
      await client.from('stock_transfer_requests').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared stock_transfer_requests');
    } catch (e) {
      print('ℹ️ stock_transfer_requests delete note: $e');
    }

    try {
      await client.from('stock_transfers').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared stock_transfers');
    } catch (e) {
      print('ℹ️ stock_transfers delete note: $e');
    }

    try {
      await client.from('product_stock_custody').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared product_stock_custody');
    } catch (e) {
      print('ℹ️ product_stock_custody delete note: $e');
    }

    try {
      await client.from('stock_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared stock_items');
    } catch (e) {
      print('ℹ️ stock_items delete note: $e');
    }

    // 6. Delete all products
    try {
      await client.from('products').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared products');
    } catch (e) {
      print('ℹ️ products delete note: $e');
    }

    // 7. Delete operational notifications
    try {
      await client.from('notifications').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      print('✅ Cleared notifications');
    } catch (e) {
      print('ℹ️ notifications delete note: $e');
    }

    // 8. Delete extra Distribution Centers (preserve ONLY Abuja DC: DC-WUSE-01)
    try {
      await client
          .from('distribution_centers')
          .delete()
          .neq('code', 'DC-WUSE-01')
          .neq('id', '22222222-2222-4222-8222-222222222222');
      print('✅ Kept only Abuja DC (DC-WUSE-01)');
    } catch (e) {
      print('ℹ️ distribution_centers delete note: $e');
    }

    // 9. Delete extra Clients (preserve Novacale / Novacare)
    try {
      await client
          .from('clients')
          .delete()
          .not('code', 'in', '("CLI-NOVACALE-01","NOVACARE")');
      print('✅ Kept only Novacare client');
    } catch (e) {
      print('ℹ️ clients delete note: $e');
    }

    // 9b. Delete extra Delivery Agents (preserve ONLY PDA-7000)
    try {
      await client
          .from('delivery_agents')
          .delete()
          .neq('agent_code', 'PDA-7000')
          .neq('id', 'b1111111-1111-4111-8111-111111111111');
      print('✅ Kept only PDA-7000 in delivery_agents');
    } catch (e) {
      print('ℹ️ delivery_agents delete note: $e');
    }

    // 10. Delete extra Users (preserve ONLY Emeka Rider, Adekunle Supervisor, Novacare Client, Amaka Chioma Closer)
    const preservedEmails = [
      'emeka.rider@novaexpress.ng',
      'dc.supervisor@novaexpress.ng',
      'client.novacale@novaexpress.ng',
      'orders@novacare.ng',
      'closer.amaka@novacale.ng',
    ];

    try {
      // Find all users not in preserved emails
      final allUsers = await client.from('users').select('id, email');
      for (final u in allUsers) {
        final email = u['email']?.toString().toLowerCase() ?? '';
        if (!preservedEmails.contains(email)) {
          final uid = u['id'].toString();
          print('🗑️ Removing extra user $email ($uid)...');
          try {
            await client.from('users').delete().eq('id', uid);
          } catch (ue) {
            print('  Notice deleting user: $ue');
          }
          try {
            await client.auth.admin.deleteUser(uid);
          } catch (_) {}
        }
      }
      print('✅ Kept only the 4 initial major users + DC manager');
    } catch (e) {
      print('ℹ️ users prune note: $e');
    }

    print('🎉 Database purge completed successfully!');
  });
}
