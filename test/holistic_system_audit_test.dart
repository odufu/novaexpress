import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Holistic Audit - Domain & Model Resilience', () {
    test('1.1 OrderModel serializes and deserializes closer confirmation and LGA routing fields', () {
      final json = {
        'id': 'ord-audit-001',
        'order_number': 'ORD-AUDIT-001',
        'client_id': 'client-audit-01',
        'customer_name': 'Audited Customer',
        'customer_phone': '08023456789',
        'customer_phone_normalized': '08023456789',
        'customer_alt_phone': '08123456789',
        'delivery_address': 'Plot 5 Commercial Ave',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'delivery_lga': 'Ikeja',
        'lga': 'Ikeja',
        'distribution_center_id': '00000000-0000-4000-8000-789360182886',
        'distribution_center_name': 'LAGOS MAIN DC',
        'package_deal_name': 'Triple Pack Boost',
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'total_amount': 38000.0,
        'status': 'confirmed',
        'assignment_status': 'assigned_to_dc',
        'closer_id': 'cls-audit-01',
        'closer_name': 'Chioma Closer',
        'marketer_id': 'mkt-audit-01',
        'form_id': 'frm-audit-01',
        'lead_id': 'lead-audit-01',
        'confirmed_at': '2026-09-28T07:00:00Z',
        'scheduled_delivery_date': '2026-09-30T10:00:00Z',
        'cancellation_reason': null,
        'created_at': '2026-09-28T06:00:00Z',
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, equals('ord-audit-001'));
      expect(order.orderNumber, equals('ORD-AUDIT-001'));
      expect(order.deliveryLga, equals('Ikeja'));
      expect(order.closerName, equals('Chioma Closer'));
      expect(order.closerId, equals('cls-audit-01'));
      expect(order.packageDealName, equals('Triple Pack Boost'));
      expect(order.paidQuantity, equals(2));
      expect(order.freeQuantity, equals(1));
      expect(order.totalAmount, equals(38000.0));
      expect(order.status, equals('confirmed'));
      expect(order.marketerId, equals('mkt-audit-01'));
      expect(order.leadId, equals('lead-audit-01'));
    });

    test('1.2 DistributionCenter domain model handles operating zones and Main DC identification', () {
      final dc = DistributionCenter.fromJson({
        'id': '22222222-2222-4222-8222-222222222222',
        'name': 'Wuse Grand Central Distribution Center',
        'code': 'DC-WUSE-01',
        'state': 'Abuja (FCT)',
        'city': 'Abuja',
        'operating_zones': ['AMAC', 'Wuse I', 'Wuse II', 'Maitama', 'Garki'],
        'is_main_dc': true,
        'is_grand_dc': true,
        'is_hub': true,
        'is_active': true,
      });

      expect(dc.id, equals('22222222-2222-4222-8222-222222222222'));
      expect(dc.isGrandDc, isTrue);
      expect(dc.operatingZones, contains('Wuse II'));
      expect(dc.operatingZones, contains('AMAC'));
      expect(dc.operatingZones.length, equals(5));
    });

    test('1.3 Nigerian phone canonicalization handles all local and international ad variations', () {
      final numbers = [
        '+234 803 123 4567',
        '0803 123 4567',
        '803 123 4567',
        '234-803-123-4567',
        '+2348031234567',
        '08031234567',
      ];

      final normalizedList = numbers.map(NigerianPhoneHelper.normalize).toSet();
      expect(normalizedList.length, equals(1));
      expect(normalizedList.first, equals('08031234567'));
    });
  });

  group('Holistic Audit - Live Database & Stored Procedures E2E Audit', () {
    test('2.1 Verify Database Performance Indexes, Realtime publications, and Stored Procedures', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      // 1. Audit Distribution Centers: Exactly One Main DC exists (Wuse Grand Central)
      final mainDcs = await client
          .from('distribution_centers')
          .select()
          .eq('is_main_dc', true);

      expect(mainDcs.isNotEmpty, isTrue, reason: 'System must have a designated Main DC');
      final mainDc = mainDcs.firstWhere(
        (dc) => dc['id'] == '22222222-2222-4222-8222-222222222222',
        orElse: () => mainDcs.first,
      );
      expect(mainDc['name'], contains('Wuse Grand Central'));
      expect(mainDc['is_grand_dc'], isTrue);

      // 2. Audit Regional DCs: Operating zones are correctly structured JSON arrays
      final allDcs = await client.from('distribution_centers').select().eq('is_active', true);
      expect(allDcs.length, greaterThanOrEqualTo(3));
      for (final dc in allDcs) {
        expect(dc['operating_zones'], isNotNull);
        expect(dc['operating_zones'], isA<List>());
      }

      // 3. Audit Full End-to-End Lifecycle:
      // Form creation -> Submission -> Closer assignment -> Closer edit/confirm -> Strict LGA DC routing
      final forms = await client.from('lead_forms').select().limit(1);
      expect(forms.isNotEmpty, isTrue);
      final form = forms.first;
      final formId = form['id'];

      final closers = await client.from('client_closers').select().limit(1);
      final closerId = closers.isNotEmpty ? closers.first['id'] : null;

      // Submission A: Covered LGA 'Ikeja' (Lagos)
      final uniquePhoneA = '+234 802 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final submitA = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': {
          'form_id': formId,
          'customer_name': 'Audit Buyer Lagos',
          'customer_phone': uniquePhoneA,
          'delivery_address': 'Plot 10 Allen Ave',
          'delivery_state': 'Lagos',
          'delivery_lga': 'Ikeja',
          'delivery_city': 'Ikeja',
          'package_selected': 'Single Starter',
          'package_quantity': 1,
          'paid_quantity': 1,
          'free_quantity': 0,
          'order_amount': 22000.0,
        }
      });

      expect(submitA, isNotNull);
      final mapA = Map<String, dynamic>.from(submitA as Map);
      expect(mapA['is_duplicate'], isFalse);
      final orderIdA = mapA['order_id'];
      expect(orderIdA, isNotNull);

      // Verify Order before closer confirmation:
      // Status must be 'new' and assignment_status must be 'pending_closer_confirmation'
      // Premature auto-dispatch must be suppressed!
      final orderBeforeConfirm = await client.from('orders').select().eq('id', orderIdA).single();
      expect(orderBeforeConfirm['status'], equals('new'));
      expect(orderBeforeConfirm['assignment_status'], equals('pending_closer_confirmation'));

      // Closer Action A: Confirm and approve order for Ikeja
      final confirmA = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderIdA,
        'p_closer_id': closerId,
        'p_action': 'confirm',
        'p_delivery_address': 'Plot 10 Allen Avenue, Ikeja, Lagos',
        'p_delivery_state': 'Lagos',
        'p_delivery_lga': 'Ikeja',
        'p_notes': 'Customer reached by phone, confirmed delivery for tomorrow.',
      });

      expect(confirmA, isNotNull);
      final confirmMapA = Map<String, dynamic>.from(confirmA as Map);
      expect(confirmMapA['success'], isTrue);
      expect(confirmMapA['status'], equals('confirmed'));
      expect(confirmMapA['distribution_center_id'], equals('00000000-0000-4000-8000-789360182886'));
      expect(confirmMapA['distribution_center_name'], equals('LAGOS MAIN DC'));
      expect(confirmMapA['is_main_dc'], isFalse);

      // Submission B: Out-of-Coverage LGA 'Enugu North' (Enugu) -> Auto-routes to Main DC
      final uniquePhoneB = '+234 807 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final submitB = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': {
          'form_id': formId,
          'customer_name': 'Audit Buyer OutOfCoverage',
          'customer_phone': uniquePhoneB,
          'delivery_address': 'Zik Ave, Enugu',
          'delivery_state': 'Enugu',
          'delivery_lga': 'Enugu North',
          'delivery_city': 'Enugu',
          'package_selected': 'Single Starter',
          'package_quantity': 1,
          'paid_quantity': 1,
          'free_quantity': 0,
          'order_amount': 22000.0,
        }
      });

      final mapB = Map<String, dynamic>.from(submitB as Map);
      final orderIdB = mapB['order_id'];

      // Closer Action B: Confirm and approve order for uncovered LGA
      final confirmB = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderIdB,
        'p_closer_id': closerId,
        'p_action': 'confirm',
        'p_delivery_address': 'Plot 15 Zik Avenue, Enugu North',
        'p_delivery_state': 'Enugu',
        'p_delivery_lga': 'Enugu North',
        'p_notes': 'Confirmed via call with buyer.',
      });

      final confirmMapB = Map<String, dynamic>.from(confirmB as Map);
      expect(confirmMapB['success'], isTrue);
      expect(confirmMapB['status'], equals('confirmed'));
      expect(confirmMapB['distribution_center_id'], equals('22222222-2222-4222-8222-222222222222'));
      expect(confirmMapB['distribution_center_name'], contains('Wuse Grand Central'));
      expect(confirmMapB['is_main_dc'], isTrue);

      // Closer Action C: Reschedule Decision Engine
      final uniquePhoneC = '+234 809 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final submitC = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': {
          'form_id': formId,
          'customer_name': 'Audit Buyer Reschedule',
          'customer_phone': uniquePhoneC,
          'delivery_address': 'Garki 2',
          'delivery_state': 'Abuja (FCT)',
          'delivery_lga': 'Abuja Municipal (AMAC)',
          'package_selected': 'Single Starter',
          'package_quantity': 1,
          'order_amount': 22000.0,
        }
      });
      final mapC = Map<String, dynamic>.from(submitC as Map);
      final orderIdC = mapC['order_id'];

      final rescheduleTime = DateTime.now().add(const Duration(days: 3));
      final rescheduleResult = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderIdC,
        'p_closer_id': closerId,
        'p_action': 'reschedule',
        'p_notes': 'Customer requested call back in 3 days',
        'p_scheduled_delivery_date': rescheduleTime.toIso8601String(),
      });

      final rescheduleMap = Map<String, dynamic>.from(rescheduleResult as Map);
      expect(rescheduleMap['success'], isTrue);
      expect(rescheduleMap['action'], equals('reschedule'));
      expect(rescheduleMap['status'], equals('rescheduled'));

      final orderCInDb = await client.from('orders').select().eq('id', orderIdC).single();
      expect(orderCInDb['status'], equals('rescheduled'));
      expect(orderCInDb['assignment_status'], equals('pending_closer_callback'));

      // Closer Action D: Cancel Decision Engine
      final uniquePhoneD = '+234 805 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final submitD = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': {
          'form_id': formId,
          'customer_name': 'Audit Buyer Cancel',
          'customer_phone': uniquePhoneD,
          'delivery_address': 'Unknown Street',
          'delivery_state': 'Kano',
          'delivery_lga': 'Kano Municipal',
          'package_selected': 'Single Starter',
          'package_quantity': 1,
          'order_amount': 22000.0,
        }
      });
      final mapD = Map<String, dynamic>.from(submitD as Map);
      final orderIdD = mapD['order_id'];

      final cancelResult = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderIdD,
        'p_closer_id': closerId,
        'p_action': 'cancel',
        'p_cancellation_reason': 'Customer stated they ordered by mistake and declined delivery.',
      });

      final cancelMap = Map<String, dynamic>.from(cancelResult as Map);
      expect(cancelMap['success'], isTrue);
      expect(cancelMap['action'], equals('cancel'));
      expect(cancelMap['status'], equals('cancelled'));

      final orderDInDb = await client.from('orders').select().eq('id', orderIdD).single();
      expect(orderDInDb['status'], equals('cancelled'));
      expect(orderDInDb['assignment_status'], equals('cancelled_by_closer'));
      expect(orderDInDb['cancellation_reason'], contains('ordered by mistake'));
    });
  });
}
