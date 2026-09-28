import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/features/client_portal/domain/entities/lead_form.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Phase 1: Lead Form Creation & Configuration Engine', () {
    test('1.1 Form Creation with Deal Packages, Paid/Free Quantities, and Marketer Attribution', () {
      final form = LeadForm(
        id: 'form-herb-boost-01',
        clientId: 'client-respira-ng',
        marketerId: 'mkt-chidi-ads',
        productId: 'prod-herb-boost',
        productName: 'Herbal Power Formula',
        formTitle: 'Herbal Power Promo Deal',
        formSlug: 'herbal-power-promo',
        description: 'Special ad landing page for Nigerian customers',
        packages: const [
          {
            'id': 'pkg-1',
            'name': 'Single Bottle Starter',
            'quantity': 1,
            'paid_quantity': 1,
            'free_quantity': 0,
            'price': 18000.0,
          },
          {
            'id': 'pkg-2',
            'name': 'Buy 2 Get 1 FREE (Super Deal)',
            'quantity': 3,
            'paid_quantity': 2,
            'free_quantity': 1,
            'price': 34000.0,
          },
        ],
        redirectUrl: 'https://respira.ng/thank-you',
        pixelId: 'PIXEL-FB-987654',
        capiToken: 'CAPI-SECRET-TOKEN',
        testEventCode: 'TEST1234',
        fieldOptions: const {
          'require_email': false,
          'require_alt_phone': true,
          'require_city': true,
          'require_notes': false,
        },
        appearance: const {
          'primary_color': '#10B981',
          'button_text': 'Claim Promo Deal Now',
          'badge_text': 'Pay On Delivery Nationwide',
        },
        isActive: true,
        totalViews: 0,
        totalSubmissions: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(form.id, equals('form-herb-boost-01'));
      expect(form.marketerId, equals('mkt-chidi-ads'));
      expect(form.packages.length, equals(2));
      expect(form.packages[1]['free_quantity'], equals(1));
      expect(form.packages[1]['paid_quantity'], equals(2));
      expect(form.packages[1]['quantity'], equals(3));
      expect(form.totalSubmissions, equals(0));
    });
  });

  group('Phase 2: Public Lead Form Submission & Canonical Phone Normalization', () {
    test('2.1 Nigerian phone variations normalize canonical phone for deduplication', () {
      const rawInputWithCountryCode = '+234 803 987 6543';
      const rawInputWithDashes = '0803-987-6543';
      const rawInputNoZero = '8039876543';

      final canonical1 = NigerianPhoneHelper.normalize(rawInputWithCountryCode);
      final canonical2 = NigerianPhoneHelper.normalize(rawInputWithDashes);
      final canonical3 = NigerianPhoneHelper.normalize(rawInputNoZero);

      expect(canonical1, equals('08039876543'));
      expect(canonical2, equals('08039876543'));
      expect(canonical3, equals('08039876543'));
      expect(canonical1, equals(canonical2));
      expect(canonical2, equals(canonical3));
    });
  });

  group('Phase 3: Auto-Assignment of Lead Order to Sales Closer', () {
    test('3.1 Order created from ad form is assigned to product closer and awaits confirmation', () {
      final order = OrderModel.fromJson({
        'id': 'ord-lead-test-001',
        'order_number': 'ORD-LEAD-001',
        'client_id': 'client-respira-ng',
        'product_name': 'Herbal Power Formula',
        'customer_name': 'Chief Adeleke',
        'customer_phone': '08039876543',
        'customer_phone_normalized': '08039876543',
        'customer_alt_phone': '08129998877',
        'delivery_address': 'Ikeja',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Ikeja',
        'package_deal_name': 'Buy 2 Get 1 FREE (Super Deal)',
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'total_amount': 34000.0,
        'status': 'new',
        'assignment_status': 'pending_closer_confirmation',
        'closer_id': 'cls-amaka-telesales',
        'closer_name': 'Amaka Chioma',
      });

      expect(order.status, equals('pending')); // OrderModel maps 'new' to 'pending' in domain
      expect(order.closerName, equals('Amaka Chioma'));
      expect(order.closerId, equals('cls-amaka-telesales'));
      expect(order.isAssignedInTransit, isFalse);
      expect(order.deliveryAgentId, isNull);
    });
  });

  group('Phase 4: Sales Closer Contact & Order Detail Editing', () {
    test('4.1 Closer calls customer and enriches address, LGA, and package upgrade', () {
      final originalOrder = OrderModel.fromJson({
        'id': 'ord-lead-test-001',
        'order_number': 'ORD-LEAD-001',
        'client_id': 'client-respira-ng',
        'product_name': 'Herbal Power Formula',
        'customer_name': 'Chief Adeleke',
        'customer_phone': '08039876543',
        'delivery_address': 'Ikeja',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Ikeja',
        'package_deal_name': 'Single Bottle Starter',
        'quantity': 1,
        'paid_quantity': 1,
        'free_quantity': 0,
        'total_amount': 18000.0,
        'status': 'new',
        'assignment_status': 'pending_closer_confirmation',
        'closer_id': 'cls-amaka-telesales',
        'closer_name': 'Amaka Chioma',
      });

      // Closer contacts customer via call:
      // Customer provides exact building number, landmark, and upgrades to 3-pack promo!
      final editedOrder = originalOrder.copyWith(
        deliveryAddress: 'Plot 14, Commercial Avenue, Opposite First Bank, Ikeja GRA',
        lga: 'Ikeja',
        deliveryCity: 'Ikeja',
        packageDealName: 'Buy 2 Get 1 FREE (Super Deal)',
        quantity: 3,
        freeQuantity: 1,
        totalAmount: 34000.0,
        deliveryNotes: 'Customer confirmed via call. Deliver between 11am - 3pm.',
      );

      expect(editedOrder.deliveryAddress, contains('Opposite First Bank, Ikeja GRA'));
      expect(editedOrder.quantity, equals(3));
      expect(editedOrder.freeQuantity, equals(1));
      expect(editedOrder.totalAmount, equals(34000.0));
      expect(editedOrder.deliveryNotes, contains('Deliver between 11am - 3pm'));
    });
  });

  group('Phase 5: Closer Next-Stage Decision Engine', () {
    final baseOrder = OrderModel.fromJson({
      'id': 'ord-decision-001',
      'order_number': 'ORD-DEC-001',
      'client_id': 'client-respira-ng',
      'product_name': 'Herbal Power Formula',
      'customer_name': 'Musa Bello',
      'customer_phone': '08023456789',
      'delivery_address': 'Kaduna Central',
      'delivery_state': 'Kaduna',
      'delivery_lga': 'Kaduna North',
      'total_amount': 34000.0,
      'status': 'new',
      'closer_id': 'cls-amaka-telesales',
      'closer_name': 'Amaka Chioma',
    });

    test('5.1 Decision: Reschedule / Call Back records follow-up and keeps order in closer pipeline', () {
      final callbackDate = DateTime.now().add(const Duration(days: 2));
      final rescheduledOrder = baseOrder.copyWith(
        status: 'rescheduled',
        deliveryNotes: 'Customer travelling today. Call back on Wednesday for delivery at ${callbackDate.toIso8601String()}.',
      );

      expect(rescheduledOrder.status, equals('rescheduled'));
      expect(rescheduledOrder.isDelivered, isFalse);
      expect(rescheduledOrder.deliveryAgentId, isNull);
      expect(rescheduledOrder.deliveryNotes, contains('Call back on Wednesday'));
      expect(callbackDate.isAfter(DateTime.now()), isTrue);
    });

    test('5.2 Decision: Cancel / Reject marks order cancelled with reason and withholds dispatch', () {
      final cancelledOrder = baseOrder.copyWith(
        status: 'cancelled',
        deliveryNotes: 'Order cancelled: Customer placed order by mistake, does not want product.',
      );

      expect(cancelledOrder.status, equals('cancelled'));
      expect(cancelledOrder.deliveryAgentId, isNull);
      expect(cancelledOrder.deliveryNotes, contains('Customer placed order by mistake'));
    });

    test('5.3 Decision: Confirm & Approve advances status to confirmed and triggers routing', () {
      final confirmedOrder = baseOrder.copyWith(
        status: 'confirmed',
        deliveryNotes: 'Customer verified and confirmed. Ready for immediate dispatch.',
      );

      expect(confirmedOrder.status, equals('confirmed'));
      expect(confirmedOrder.closerName, equals('Amaka Chioma'));
    });
  });

  group('Phase 6: Automatic DC Routing Based on Handled LGA', () {
    // Setup Mock Distribution Centers mirroring system state
    final lagosDc = DistributionCenter(
      id: '00000000-0000-4000-8000-789360182886',
      name: 'LAGOS MAIN DC',
      code: 'DC-LGS-001',
      state: 'Lagos',
      city: 'Ikeja',
      address: 'Plot 14 Commercial Avenue, Ikeja GRA, Lagos',
      isGrandDc: false,
      isHub: false,
      isActive: true,
      operatingZones: const [
        'Ikeja', 'Agege', 'Alimosho', 'Oshodi-Isolo', 'Kosofe', 'Surulere',
        'Lagos Island', 'Lagos Mainland', 'Mushin', 'Apapa', 'Amuwo-Odofin'
      ],
    );

    final kadunaDc = DistributionCenter(
      id: '00000000-0000-4000-8000-789382566045',
      name: 'Kaduna Main DC',
      code: 'DC-KD-001',
      state: 'Kaduna',
      city: 'Kaduna North',
      address: 'Ali Akilu Road, Kaduna',
      isGrandDc: false,
      isHub: true,
      isActive: true,
      operatingZones: const [
        'Kaduna North', 'Kaduna South', 'Chikun', 'Igabi', 'Zaria', 'Sabon Gari'
      ],
    );

    final mainDc = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Wuse Grand Central Distribution Center',
      code: 'DC-WUSE-01',
      state: 'Abuja (FCT)',
      city: 'Wuse 2',
      address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
      isGrandDc: true,
      isHub: true,
      isActive: true,
      operatingZones: const [
        'Abuja Municipal (AMAC)', 'Wuse I', 'Wuse II', 'Maitama', 'Garki', 'Bwari'
      ],
    );

    final allDcs = [lagosDc, kadunaDc, mainDc];

    DistributionCenter resolveTargetDcForOrder(String deliveryState, String deliveryLga) {
      final cleanLga = deliveryLga.trim().toLowerCase();
      // 1. Match DC that explicitly handles this LGA
      for (final dc in allDcs) {
        if (!dc.isActive) continue;
        for (final z in dc.operatingZones) {
          if (z.trim().toLowerCase() == cleanLga) {
            return dc;
          }
        }
      }
      // 2. If NO DC handles that LGA, automatically send to Main DC!
      return allDcs.firstWhere((d) => d.isGrandDc || d.isHub, orElse: () => mainDc);
    }

    test('6.1 Order with LGA handled by regional DC routes directly to that DC', () {
      final targetDc = resolveTargetDcForOrder('Lagos', 'Ikeja');

      expect(targetDc.id, equals(lagosDc.id));
      expect(targetDc.name, equals('LAGOS MAIN DC'));
      expect(targetDc.operatingZones, contains('Ikeja'));
    });

    test('6.2 Order in Northern region with LGA handled by Kaduna DC routes to Kaduna DC', () {
      final targetDc = resolveTargetDcForOrder('Kaduna', 'Zaria');

      expect(targetDc.id, equals(kadunaDc.id));
      expect(targetDc.name, equals('Kaduna Main DC'));
      expect(targetDc.operatingZones, contains('Zaria'));
    });
  });

  group('Phase 7: Out-of-Coverage LGA Auto-Routing to Main DC', () {
    final lagosDc = DistributionCenter(
      id: '00000000-0000-4000-8000-789360182886',
      name: 'LAGOS MAIN DC',
      code: 'DC-LGS-001',
      state: 'Lagos',
      city: 'Ikeja',
      address: 'Plot 14 Commercial Avenue, Ikeja GRA, Lagos',
      isGrandDc: false,
      isHub: false,
      isActive: true,
      operatingZones: const ['Ikeja', 'Alimosho', 'Surulere'],
    );

    final mainDc = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Wuse Grand Central Distribution Center',
      code: 'DC-WUSE-01',
      state: 'Abuja (FCT)',
      city: 'Wuse 2',
      address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
      isGrandDc: true,
      isHub: true,
      isActive: true,
      operatingZones: const ['Abuja Municipal (AMAC)', 'Wuse II'],
    );

    final allDcs = [lagosDc, mainDc];

    DistributionCenter resolveTargetDcForOrder(String deliveryState, String deliveryLga) {
      final cleanLga = deliveryLga.trim().toLowerCase();
      for (final dc in allDcs) {
        if (!dc.isActive) continue;
        for (final z in dc.operatingZones) {
          if (z.trim().toLowerCase() == cleanLga) return dc;
        }
      }
      // Out-of-coverage fallback -> Main DC
      return allDcs.firstWhere((d) => d.isGrandDc, orElse: () => mainDc);
    }

    test('7.1 Order with LGA NOT handled by any regional DC automatically routes to Main DC', () {
      // Customer orders in Enugu North (No regional DC covers Enugu)
      final targetDc = resolveTargetDcForOrder('Enugu', 'Enugu North');

      expect(targetDc.id, equals(mainDc.id));
      expect(targetDc.name, equals('Wuse Grand Central Distribution Center'));
      expect(targetDc.isGrandDc, isTrue);
    });

    test('7.2 Order in Rivers state (Port Harcourt) automatically routes to Main DC', () {
      // Customer orders in Port Harcourt (No regional DC covers Rivers)
      final targetDc = resolveTargetDcForOrder('Rivers', 'Port Harcourt');

      expect(targetDc.id, equals(mainDc.id));
      expect(targetDc.isGrandDc, isTrue);
    });
  });

  group('Phase 8: Live Remote Database E2E Execution Test', () {
    test('8.1 Live Supabase execution: Submit lead order -> Confirm by closer -> Auto-route to DC by LGA and Main DC fallback', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      // 1. Fetch an active lead form and closer from remote database
      final forms = await client.from('lead_forms').select().limit(1);
      expect(forms.isNotEmpty, isTrue, reason: 'Remote database should have at least one lead_form');
      final testForm = forms.first;
      final formId = testForm['id'];

      final closers = await client.from('client_closers').select().limit(1);
      final closerId = closers.isNotEmpty ? closers.first['id'] : null;

      // 2. LIVE SUBMISSION 1: Order with LGA 'Ikeja' (Covered by LAGOS MAIN DC)
      final testPhone1 = '+234 810 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final payload1 = {
        'form_id': formId,
        'customer_name': 'Live Test Customer Ikeja',
        'customer_phone': testPhone1,
        'customer_alt_phone': '08099887766',
        'delivery_address': 'Plot 10 Allen Avenue',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Ikeja',
        'delivery_city': 'Ikeja',
        'package_selected': 'Standard Pack',
        'package_quantity': 1,
        'paid_quantity': 1,
        'free_quantity': 0,
        'order_amount': 25000.0,
      };

      final subResponse1 = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': payload1,
      });

      expect(subResponse1, isNotNull);
      final subMap1 = Map<String, dynamic>.from(subResponse1 as Map);
      expect(subMap1['is_duplicate'], isFalse);
      final orderId1 = subMap1['order_id'];
      expect(orderId1, isNotNull);

      // 3. LIVE CLOSER CONFIRMATION 1: Confirm order for 'Ikeja' LGA
      final confirmResponse1 = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderId1,
        'p_closer_id': closerId,
        'p_action': 'confirm',
        'p_delivery_address': 'Plot 10 Allen Avenue, Opposite First Bank',
        'p_delivery_state': 'Lagos',
        'p_delivery_lga': 'Ikeja',
        'p_notes': 'Customer confirmed delivery for tomorrow morning.',
      });

      expect(confirmResponse1, isNotNull);
      final confirmMap1 = Map<String, dynamic>.from(confirmResponse1 as Map);
      expect(confirmMap1['success'], isTrue);
      expect(confirmMap1['status'], equals('confirmed'));
      expect(confirmMap1['distribution_center_id'], equals('00000000-0000-4000-8000-789360182886'));
      expect(confirmMap1['distribution_center_name'], equals('LAGOS MAIN DC'));
      expect(confirmMap1['is_main_dc'], isFalse);

      // 4. LIVE SUBMISSION 2: Order with Uncovered LGA 'Enugu North'
      final testPhone2 = '+234 811 ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final payload2 = {
        'form_id': formId,
        'customer_name': 'Live Test Customer OutOfCoverage',
        'customer_phone': testPhone2,
        'delivery_address': 'Zik Avenue',
        'delivery_state': 'Enugu',
        'delivery_lga': 'Enugu North',
        'delivery_city': 'Enugu',
        'package_selected': 'Standard Pack',
        'package_quantity': 1,
        'paid_quantity': 1,
        'free_quantity': 0,
        'order_amount': 25000.0,
      };

      final subResponse2 = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': payload2,
      });

      expect(subResponse2, isNotNull);
      final subMap2 = Map<String, dynamic>.from(subResponse2 as Map);
      expect(subMap2['is_duplicate'], isFalse);
      final orderId2 = subMap2['order_id'];
      expect(orderId2, isNotNull);

      // 5. LIVE CLOSER CONFIRMATION 2: Confirm order with uncovered LGA -> Auto-routes to Main DC!
      final confirmResponse2 = await client.rpc('fn_confirm_closer_order', params: {
        'p_order_id': orderId2,
        'p_closer_id': closerId,
        'p_action': 'confirm',
        'p_delivery_address': 'Plot 45 Zik Avenue, Near Stadium',
        'p_delivery_state': 'Enugu',
        'p_delivery_lga': 'Enugu North',
        'p_notes': 'Customer confirmed delivery in Enugu.',
      });

      expect(confirmResponse2, isNotNull);
      final confirmMap2 = Map<String, dynamic>.from(confirmResponse2 as Map);
      expect(confirmMap2['success'], isTrue);
      expect(confirmMap2['status'], equals('confirmed'));
      expect(confirmMap2['distribution_center_id'], equals('22222222-2222-4222-8222-222222222222'));
      expect(confirmMap2['distribution_center_name'], contains('Wuse Grand Central'));
      expect(confirmMap2['is_main_dc'], isTrue);

      // 6. Verify Orders in Database
      final orderRows = await client.from('orders').select().inFilter('id', [orderId1, orderId2]);
      expect(orderRows.length, equals(2));

      final row1 = orderRows.firstWhere((r) => r['id'] == orderId1);
      expect(row1['status'], equals('confirmed'));
      expect(row1['distribution_center_id'], equals('00000000-0000-4000-8000-789360182886'));
      expect(row1['routing_notes'], contains('LAGOS MAIN DC'));

      final row2 = orderRows.firstWhere((r) => r['id'] == orderId2);
      expect(row2['status'], equals('confirmed'));
      expect(row2['distribution_center_id'], equals('22222222-2222-4222-8222-222222222222'));
      expect(row2['routing_notes'], contains('Main DC'));
    });
  });
}
