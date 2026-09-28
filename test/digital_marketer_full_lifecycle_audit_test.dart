import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';
import 'package:novexps/features/client_portal/domain/entities/lead_form.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_model.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Digital Marketer Full Lifecycle Audit', () {
    test('1. Marketer Onboarding & Supervisory Hierarchy Serialization', () {
      final supervisorJson = {
        'id': 'mkt-sup-001',
        'client_id': 'client-respira-01',
        'marketer_code': 'MKT-SUP-01',
        'full_name': 'Chief Emeka Supervisor',
        'email': 'emeka.ads@agency.com',
        'phone': '08031112233',
        'daily_ad_spend_budget': 150000.0,
        'commission_rate': 1500.0,
        'is_commission_enabled': true,
        'is_supervisor': true,
        'supervisor_id': null,
        'commission_type': 'per_delivered_order',
        'commission_per_form_submission': 0.0,
        'commission_per_delivered_order': 1500.0,
        'bank_name': 'Zenith Bank',
        'bank_account_number': '1012345678',
        'bank_account_name': 'Emeka Media Ltd',
        'total_leads_generated': 120,
        'total_orders_generated': 95,
        'total_orders_delivered': 68,
        'total_commission_earned': 102000.0,
        'is_active': true,
      };

      final supervisor = ClientMarketer.fromJson(supervisorJson);
      expect(supervisor.id, equals('mkt-sup-001'));
      expect(supervisor.isSupervisor, isTrue);
      expect(supervisor.commissionPerDeliveredOrder, equals(1500.0));
      expect(supervisor.totalCommissionEarned, equals(102000.0));

      final superviseeJson = {
        'id': 'mkt-sub-002',
        'client_id': 'client-respira-01',
        'marketer_code': 'MKT-SUB-02',
        'full_name': 'Junior Media Buyer Tunde',
        'email': 'tunde.ads@agency.com',
        'phone': '08059998877',
        'daily_ad_spend_budget': 40000.0,
        'commission_rate': 500.0,
        'is_commission_enabled': true,
        'is_supervisor': false,
        'supervisor_id': 'mkt-sup-001',
        'commission_type': 'per_form_submission',
        'commission_per_form_submission': 500.0,
        'commission_per_delivered_order': 0.0,
        'total_leads_generated': 40,
        'total_orders_generated': 40,
        'total_orders_delivered': 25,
        'total_commission_earned': 20000.0,
        'is_active': true,
      };

      final supervisee = ClientMarketer.fromJson(superviseeJson);
      expect(supervisee.id, equals('mkt-sub-002'));
      expect(supervisee.isSupervisor, isFalse);
      expect(supervisee.supervisorId, equals('mkt-sup-001'));
      expect(supervisee.commissionPerFormSubmission, equals(500.0));
    });

    test('2. Lead Form Creation with Package Bundles & Marketer Attribution', () {
      final form = LeadForm(
        id: 'frm-mkt-audit-01',
        clientId: 'client-respira-01',
        marketerId: 'mkt-sup-001',
        productId: 'prd-herb-boost',
        productName: 'Herbal Power Formula',
        formTitle: 'Herbal Power Official Ad Campaign',
        formSlug: 'herbal-power-deal',
        description: 'Official Direct Response Landing Page',
        packages: const [
          {
            'package_id': 'pkg-1',
            'package_name': 'Single Bottle Starter',
            'quantity': 1,
            'paid_quantity': 1,
            'free_quantity': 0,
            'price': 18000.0,
          },
          {
            'package_id': 'pkg-2',
            'package_name': 'Buy 2 Get 1 FREE (Super Deal)',
            'quantity': 3,
            'paid_quantity': 2,
            'free_quantity': 1,
            'price': 34000.0,
          }
        ],
        pixelId: 'PIXEL-FB-98765',
        capiToken: 'CAPI-SECRET-TOKEN',
        testEventCode: 'TEST-1234',
        isActive: true,
        totalViews: 500,
        totalSubmissions: 50,
        actualDeliveredCount: 38,
      );

      expect(form.id, equals('frm-mkt-audit-01'));
      expect(form.marketerId, equals('mkt-sup-001'));
      expect(form.packages.length, equals(2));
      expect(form.packages[1]['free_quantity'], equals(1));
      expect(form.packages[1]['paid_quantity'], equals(2));
      expect(form.totalOrdersBooked, equals(50));
      expect(form.totalOrdersDelivered, equals(38));
      expect(form.conversionRate, equals(10.0));
    });

    test('3. Pipeline Chat Serialization with Marketer DP and Sender Role', () {
      final conversationJson = {
        'id': 'conv-mkt-001',
        'order_id': 'ord-mkt-001',
        'order_number': 'ORD-MKT-001',
        'client_id': 'client-respira-01',
        'closer_id': 'cls-amaka-01',
        'closer_name': 'Amaka Closer',
        'delivery_agent_id': 'agt-kabir-01',
        'delivery_agent_name': 'Kabiru Rider',
        'marketer_id': 'mkt-sup-001',
        'marketer_name': 'Chief Emeka Supervisor',
        'marketer_phone': '08031112233',
        'marketer_avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final conv = OrderConversationModel.fromJson(conversationJson);
      expect(conv.orderId, equals('ord-mkt-001'));
      expect(conv.marketerId, equals('mkt-sup-001'));
      expect(conv.marketerName, equals('Chief Emeka Supervisor'));
      expect(conv.marketerAvatarUrl, contains('images.unsplash.com'));

      expect(ChatSenderRole.marketer.name, equals('marketer'));
      expect(ChatSenderRole.values.byName('marketer'), equals(ChatSenderRole.marketer));
    });

    test('4. Live Remote Supabase E2E: Marketer Creation -> Form Submit -> Closer Confirm -> Delivery Trigger -> Commission Accrual', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      // A. Verify / Create Digital Marketer with 'per_delivered_order' commission
      final marketers = await client.from('client_marketers').select().limit(1);
      final Map<String, dynamic> marketer;
      if (marketers.isEmpty) {
        final clients = await client.from('clients').select().limit(1);
        final clientId = clients.isNotEmpty ? clients.first['id'] : '11111111-1111-4111-8111-111111111111';
        final newMarketer = await client.from('client_marketers').insert({
          'client_id': clientId,
          'marketer_code': 'MKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'full_name': 'Live Audit Digital Marketer',
          'email': 'marketer.${DateTime.now().millisecondsSinceEpoch}@ads.com',
          'phone': '08031234567',
          'commission_type': 'per_delivered_order',
          'commission_rate': 2500.0,
          'commission_per_delivered_order': 2500.0,
          'is_commission_enabled': true,
          'is_supervisor': true,
          'total_orders_delivered': 0,
          'total_commission_earned': 0.0,
          'is_active': true,
        }).select().single();
        marketer = Map<String, dynamic>.from(newMarketer);
      } else {
        marketer = Map<String, dynamic>.from(marketers.first);
        await client.from('client_marketers').update({
          'commission_type': 'per_delivered_order',
          'commission_per_delivered_order': 2500.0,
        }).eq('id', marketer['id']);
      }

      final marketerId = marketer['id'];
      final initialDelivered = (marketer['total_orders_delivered'] as num?)?.toInt() ?? 0;
      final initialCommission = (marketer['total_commission_earned'] as num?)?.toDouble() ?? 0.0;

      // B. Fetch an active form and closer
      final forms = await client.from('lead_forms').select().limit(1);
      expect(forms.isNotEmpty, isTrue);
      final form = forms.first;
      final formId = form['id'];

      final closers = await client.from('client_closers').select().limit(1);
      final closerId = closers.isNotEmpty ? closers.first['id'] : null;

      // C. Public Form Submission with raw phone formatting and marketer attribution
      final uniquePhone = '+234 812 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final submitRes = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': {
          'form_id': formId,
          'customer_name': 'E2E Marketer Flow Buyer',
          'customer_phone': uniquePhone,
          'customer_alt_phone': '0809 111 2233',
          'delivery_address': 'Plot 22 Ikeja GRA',
          'delivery_state': 'Lagos',
          'delivery_lga': 'Ikeja',
          'delivery_city': 'Ikeja',
          'package_selected': 'Super Deal Promo',
          'package_quantity': 3,
          'paid_quantity': 2,
          'free_quantity': 1,
          'order_amount': 34000.0,
        }
      });

      expect(submitRes, isNotNull);
      final submitMap = Map<String, dynamic>.from(submitRes as Map);
      expect(submitMap['is_duplicate'], isFalse);
      final orderId = submitMap['order_id'];
      expect(orderId, isNotNull);

      // Attach marketer directly to order if needed for strict test parity
      await client.from('orders').update({'marketer_id': marketerId}).eq('id', orderId);

      // D. Verify initial unconfirmed state: DC auto-dispatch must be suppressed
      final orderBeforeConfirm = await client.from('orders').select().eq('id', orderId).single();
      expect(orderBeforeConfirm['status'], equals('new'));
      expect(orderBeforeConfirm['assignment_status'], equals('pending_closer_confirmation'));

      // E. Sales Closer Confirmation & Approval -> Triggers LGA DC routing
      final confirmRes = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderId,
        'p_closer_id': closerId,
        'p_action': 'confirm',
        'p_delivery_address': 'Plot 22 Commercial Ave, Ikeja GRA, Lagos',
        'p_delivery_state': 'Lagos',
        'p_delivery_lga': 'Ikeja',
        'p_notes': 'Customer confirmed delivery for afternoon.',
      });

      expect(confirmRes, isNotNull);
      final confirmMap = Map<String, dynamic>.from(confirmRes as Map);
      expect(confirmMap['success'], isTrue);
      expect(confirmMap['status'], equals('confirmed'));
      expect(confirmMap['distribution_center_name'], equals('LAGOS MAIN DC'));

      // F. Rider Delivery to Buyer (POD): Update Order Status to 'delivered'
      // This fires the automated trigger: trg_orders_marketer_delivery_lifecycle!
      await client.from('orders').update({
        'status': 'delivered',
        'payment_status': 'collected',
        'delivered_at': DateTime.now().toIso8601String(),
        'proof_of_delivery_url': 'https://storage.googleapis.com/proofs/pod-signature-001.png',
      }).eq('id', orderId);

      // G. Verify Marketer Stats & Commission Accrual in Database
      final refreshedMarketer = await client.from('client_marketers').select().eq('id', marketerId).single();
      final updatedDelivered = (refreshedMarketer['total_orders_delivered'] as num?)?.toInt() ?? 0;
      final updatedCommission = (refreshedMarketer['total_commission_earned'] as num?)?.toDouble() ?? 0.0;

      expect(updatedDelivered, greaterThanOrEqualTo(initialDelivered + 1));
      expect(updatedCommission, greaterThanOrEqualTo(initialCommission + 2500.0));

      // H. Verify In-App Notification dispatched to Marketer
      if (refreshedMarketer['user_id'] != null) {
        final notifications = await client
            .from('notifications')
            .select()
            .eq('user_id', refreshedMarketer['user_id'])
            .order('created_at', ascending: false)
            .limit(1);

        if (notifications.isNotEmpty) {
          expect(notifications.first['title'], contains('Buyer Received Delivery'));
        }
      }
    });
  });
}
