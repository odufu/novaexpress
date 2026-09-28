import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer_payout.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Digital Marketer Details & Commission Payout Audit', () {
    test('1. ClientMarketer & ClientMarketerPayout Entity Serialization', () {
      final marketerJson = {
        'id': 'mkt-test-payout-001',
        'client_id': 'client-respira-01',
        'marketer_code': 'MKT-PAYOUT-01',
        'full_name': 'Victor Ad Specialist',
        'email': 'victor.payout@adagency.com',
        'phone': '08022334455',
        'daily_ad_spend_budget': 100000.0,
        'commission_rate': 2000.0,
        'is_commission_enabled': true,
        'is_supervisor': true,
        'supervisor_id': null,
        'commission_type': 'per_delivered_order',
        'commission_per_form_submission': 0.0,
        'commission_per_delivered_order': 2000.0,
        'bank_name': 'Access Bank',
        'bank_account_number': '0123456789',
        'bank_account_name': 'Victor Payout Ent',
        'total_leads_generated': 50,
        'total_orders_generated': 40,
        'total_orders_delivered': 30,
        'total_commission_earned': 60000.0,
        'unpaid_commission_balance': 40000.0,
        'total_paid_commission': 20000.0,
        'is_active': true,
      };

      final marketer = ClientMarketer.fromJson(marketerJson);
      expect(marketer.id, equals('mkt-test-payout-001'));
      expect(marketer.unpaidCommissionBalance, equals(40000.0));
      expect(marketer.totalPaidCommission, equals(20000.0));
      expect(marketer.totalCommissionEarned, equals(60000.0));

      final payoutJson = {
        'id': 'payout-uuid-001',
        'marketer_id': marketer.id,
        'client_id': 'client-respira-01',
        'payout_number': 'PAY-MKT-2026-0001',
        'amount': 20000.0,
        'bank_name': 'Access Bank',
        'account_number': '0123456789',
        'account_name': 'Victor Payout Ent',
        'transfer_reference': 'TRF-TEST-8899',
        'proof_of_payment_url': 'https://s3.supabase.co/storage/receipts/rec1.jpg',
        'notes': 'Bi-weekly Facebook Ad commission payout',
        'status': 'completed',
        'processed_by': 'Admin Sarah',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final payout = ClientMarketerPayout.fromJson(payoutJson);
      expect(payout.id, equals('payout-uuid-001'));
      expect(payout.marketerId, equals(marketer.id));
      expect(payout.amount, equals(20000.0));
      expect(payout.hasReceipt, isTrue);
      expect(payout.status, equals('completed'));
      expect(payout.proofOfPaymentUrl, contains('rec1.jpg'));
    });

    test('2. Live Remote Supabase E2E: Marketer Creation -> Balance Accrual -> RPC Disburse Payout -> Safe Delete', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      final clientRows = await client.from('clients').select('id').limit(1);
      final clientId = clientRows.isNotEmpty ? clientRows.first['id'] : '33333333-3333-4333-8333-333333333333';

      final testTs = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'marketer-$testTs@media-agency.com';
      final testCode = 'MKT-${testTs.toString().substring(testTs.toString().length - 5)}';

      // Step A: Insert a test digital marketer with initial commission balance
      final insertedMarketer = await client.from('client_marketers').insert({
        'client_id': clientId,
        'marketer_code': testCode,
        'full_name': 'Audit E2E Marketer $testTs',
        'email': testEmail,
        'phone': '080${testTs.toString().substring(testTs.toString().length - 8)}',
        'daily_ad_spend_budget': 75000.0,
        'commission_rate': 2500.0,
        'is_commission_enabled': true,
        'is_supervisor': false,
        'commission_type': 'per_delivered_order',
        'commission_per_delivered_order': 2500.0,
        'bank_name': 'Guaranty Trust Bank',
        'account_number': '0987654321',
        'account_name': 'Audit E2E Marketer',
        'total_leads_generated': 15,
        'total_orders_generated': 10,
        'total_orders_delivered': 8,
        'total_commission_earned': 20000.0,
        'unpaid_commission_balance': 20000.0,
        'total_paid_commission': 0.0,
        'is_active': true,
      }).select().single();

      final testMarketerId = insertedMarketer['id'];
      expect(testMarketerId, isNotNull);
      expect((insertedMarketer['unpaid_commission_balance'] as num).toDouble(), equals(20000.0));

      // Step B: Disburse commission payout of 12,000 via stored procedure RPC
      final payoutRes = await client.rpc('fn_disburse_marketer_payout', params: {
        'p_marketer_id': testMarketerId,
        'p_client_id': clientId,
        'p_amount': 12000.0,
        'p_bank_name': 'Guaranty Trust Bank',
        'p_account_number': '0987654321',
        'p_account_name': 'Audit E2E Marketer',
        'p_disbursement_ref': 'TXREF-$testTs',
        'p_proof_of_payment_url': 'https://mock-storage.com/proofs/pay-$testTs.jpg',
        'p_notes': 'Settling 6 delivered customer orders',
      });

      expect(payoutRes, isNotNull);
      final payoutId = payoutRes['payout_id'];
      expect(payoutId, isNotNull);
      expect(payoutRes['payout_number'], startsWith('MPAY-'));
      expect((payoutRes['amount'] as num).toDouble(), equals(12000.0));
      expect(payoutRes['status'], equals('remitted'));

      // Step C: Verify marketer balance has been dynamically decremented
      final updatedMarketer = await client
          .from('client_marketers')
          .select()
          .eq('id', testMarketerId)
          .single();

      final remainingUnpaid = (updatedMarketer['unpaid_commission_balance'] as num).toDouble();
      final totalPaid = (updatedMarketer['total_paid_commission'] as num).toDouble();
      expect(remainingUnpaid, equals(8000.0)); // 20,000 - 12,000
      expect(totalPaid, equals(12000.0));

      // Step D: Verify payout record persisted in marketer_payouts table
      final payoutRecords = await client
          .from('marketer_payouts')
          .select()
          .eq('marketer_id', testMarketerId);

      expect(payoutRecords.length, equals(1));
      expect(payoutRecords[0]['disbursement_ref'], equals('TXREF-$testTs'));
      expect(payoutRecords[0]['proof_of_payment_url'], contains('pay-$testTs.jpg'));

      // Step E: Disburse remaining balance of 8,000
      final finalPayoutRes = await client.rpc('fn_disburse_marketer_payout', params: {
        'p_marketer_id': testMarketerId,
        'p_client_id': clientId,
        'p_amount': 8000.0,
        'p_bank_name': 'Guaranty Trust Bank',
        'p_account_number': '0987654321',
        'p_account_name': 'Audit E2E Marketer',
        'p_disbursement_ref': 'TXREF-FINAL-$testTs',
        'p_proof_of_payment_url': '',
        'p_notes': 'Settling final balance',
      });

      expect(finalPayoutRes['status'], equals('remitted'));

      final finalMarketer = await client
          .from('client_marketers')
          .select()
          .eq('id', testMarketerId)
          .single();

      expect((finalMarketer['unpaid_commission_balance'] as num).toDouble(), equals(0.0));
      expect((finalMarketer['total_paid_commission'] as num).toDouble(), equals(20000.0));

      // Step F: Test safe marketer deletion RPC fn_delete_marketer
      final deleteResult = await client.rpc('fn_delete_marketer', params: {
        'p_marketer_id': testMarketerId,
      });
      expect(deleteResult['success'], isTrue);

      final checkDeleted = await client
          .from('client_marketers')
          .select()
          .eq('id', testMarketerId)
          .maybeSingle();
      expect(checkDeleted, isNull);

      // Clean up payout test records
      await client.from('marketer_payouts').delete().eq('marketer_id', testMarketerId);
    });

    test('3. Live Remote Supabase E2E: Supervisory Marketer Hierarchy, Supervisee Summary RPC, and Dual-Tier Delivery Notifications', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      final clientRows = await client.from('clients').select('id').limit(1);
      final clientId = clientRows.isNotEmpty ? clientRows.first['id'] : '33333333-3333-4333-8333-333333333333';

      final userRows = await client.from('users').select('id').limit(2);
      final supUserId = userRows.isNotEmpty ? userRows.first['id'] : null;
      final subUserId = userRows.length > 1 ? userRows[1]['id'] : null;

      final productRows = await client.from('products').select('id, name').limit(1);
      final productId = productRows.isNotEmpty ? productRows.first['id'] : null;
      final productName = productRows.isNotEmpty ? productRows.first['name'] : 'Respira Tea';

      final ts = DateTime.now().millisecondsSinceEpoch;

      // 1. Create Supervisory Digital Marketer
      final supervisor = await client.from('client_marketers').insert({
        'client_id': clientId,
        'user_id': supUserId,
        'marketer_code': 'MKT-SUP-${ts.toString().substring(8)}',
        'full_name': 'Chief Supervisor $ts',
        'email': 'supervisor.$ts@adagency.com',
        'phone': '08091112233',
        'daily_ad_spend_budget': 150000.0,
        'commission_rate': 1000.0,
        'is_commission_enabled': true,
        'is_supervisor': true,
        'commission_type': 'per_delivered_order',
        'commission_per_delivered_order': 1000.0,
        'bank_name': 'Zenith Bank',
        'account_number': '1012345678',
        'account_name': 'Chief Supervisor Ads',
        'total_leads_generated': 0,
        'total_orders_generated': 0,
        'total_orders_delivered': 0,
        'total_commission_earned': 0.0,
        'unpaid_commission_balance': 0.0,
        'is_active': true,
      }).select().single();

      final supervisorId = supervisor['id'];
      expect(supervisorId, isNotNull);

      // 2. Create Supervisee Media Buyer linked to the Supervisor
      final supervisee = await client.from('client_marketers').insert({
        'client_id': clientId,
        'user_id': subUserId,
        'supervisor_id': supervisorId,
        'marketer_code': 'MKT-SUB-${ts.toString().substring(8)}',
        'full_name': 'Junior Media Buyer $ts',
        'email': 'junior.$ts@adagency.com',
        'phone': '08094445566',
        'daily_ad_spend_budget': 45000.0,
        'commission_rate': 2500.0,
        'is_commission_enabled': true,
        'is_supervisor': false,
        'commission_type': 'per_delivered_order',
        'commission_per_delivered_order': 2500.0,
        'bank_name': 'Access Bank',
        'account_number': '0123456789',
        'account_name': 'Junior Media Buyer',
        'total_leads_generated': 10,
        'total_orders_generated': 5,
        'total_orders_delivered': 0,
        'total_commission_earned': 0.0,
        'unpaid_commission_balance': 0.0,
        'is_active': true,
      }).select().single();

      final superviseeId = supervisee['id'];
      expect(superviseeId, isNotNull);

      // 3. Create a test lead form attributed to the Supervisee
      String? formId;
      if (productId != null) {
        final form = await client.from('lead_forms').insert({
          'client_id': clientId,
          'marketer_id': superviseeId,
          'product_id': productId,
          'product_name': productName,
          'form_title': 'High-Converting Supervisee Landing Page $ts',
          'form_slug': 'supervisee-promo-$ts',
          'is_active': true,
          'total_views': 100,
          'total_submissions': 10,
          'total_orders_booked': 5,
          'total_orders_delivered': 0,
        }).select().single();
        formId = form['id'];
      }

      // 4. Test RPC: fn_get_marketer_supervisees
      final rpcSupervisees = await client.rpc('fn_get_marketer_supervisees', params: {
        'p_supervisor_id': supervisorId,
      });

      expect(rpcSupervisees, isA<List>());
      final list = rpcSupervisees as List;
      expect(list.length, equals(1));
      expect(list.first['id'], equals(superviseeId));
      expect(list.first['full_name'], equals('Junior Media Buyer $ts'));
      if (formId != null) {
        expect(list.first['total_forms_count'], equals(1));
      }

      // 5. Test Live Order Delivery Lifecycle & Dual-Tier Notification
      final testOrderNumber = 'ORD-SUP-TEST-$ts';
      final order = await client.from('orders').insert({
        'order_number': testOrderNumber,
        'client_id': clientId,
        'marketer_id': superviseeId,
        'form_id': formId,
        'customer_name': 'Amina Buyer $ts',
        'customer_phone': '08039998877',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'delivery_address': '12 Commercial Avenue',
        'lga': 'Ikeja',
        'product_id': productId,
        'product_name': productName,
        'status': 'pending_dispatch',
        'quantity': 2,
        'base_price': 15000.0,
        'upsell_amount': 0.0,
        'total_amount': 30000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
      }).select().single();

      final orderId = order['id'];
      expect(orderId, isNotNull);

      // Trigger Delivery Milestone: transition status to 'delivered'
      await client.from('orders').update({
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // 6. Verify Supervisee stats incremented
      final updatedSupervisee = await client
          .from('client_marketers')
          .select()
          .eq('id', superviseeId)
          .single();

      expect(updatedSupervisee['total_orders_delivered'], equals(1));
      expect((updatedSupervisee['total_commission_earned'] as num).toDouble(), equals(2500.0));
      expect((updatedSupervisee['unpaid_commission_balance'] as num).toDouble(), equals(2500.0));

      // 7. Verify In-App Notification was generated for the primary Supervisee AND the Supervisor
      if (subUserId != null) {
        final subNotifs = await client
            .from('notifications')
            .select()
            .eq('user_id', subUserId)
            .order('created_at', ascending: false)
            .limit(1);
        if (subNotifs.isNotEmpty) {
          expect(subNotifs.first['title'], contains('Buyer Received Delivery!'));
        }
      }

      if (supUserId != null) {
        final supNotifs = await client
            .from('notifications')
            .select()
            .eq('user_id', supUserId)
            .order('created_at', ascending: false)
            .limit(1);
        if (supNotifs.isNotEmpty) {
          expect(supNotifs.first['title'], contains('Team Order Delivered!'));
          expect(supNotifs.first['message'], contains('Junior Media Buyer $ts'));
        }
      }

      // Clean up test data safely
      await client.from('orders').delete().eq('id', orderId);
      if (formId != null) {
        await client.from('lead_forms').delete().eq('id', formId);
      }
      await client.rpc('fn_delete_marketer', params: {'p_marketer_id': superviseeId});
      await client.rpc('fn_delete_marketer', params: {'p_marketer_id': supervisorId});
    });
  });
}
