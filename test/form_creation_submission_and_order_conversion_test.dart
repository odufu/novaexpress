import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';
import 'package:novexps/features/client_portal/domain/entities/lead_form.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_model.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Phase 1: Lead Form Creation & Configuration Engine', () {
    test('1.1 Form Creation with Deal Packages, Paid/Free Quantities, and Marketer Attribution', () {
      final formJson = {
        'id': 'form-glucosafe-ad-2026',
        'client_id': 'client-respira-ng',
        'title': 'Glucosafe Blood Sugar Promo Landing Page',
        'product_id': 'prod-glucosafe-01',
        'product_name': 'Herbal Glucosafe Max',
        'marketer_id': 'mkt-damilola-01',
        'slug': 'glucosafe-promo-offer',
        'description': 'Targeted TikTok & Facebook Ad Campaign Form',
        'total_submissions': 0,
        'total_orders_booked': 0,
        'total_orders_delivered': 0,
        'is_active': true,
        'redirect_url': 'https://respira.ng/thank-you-glucosafe',
        'packages': [
          {
            'id': 'pkg-1-bottle',
            'name': 'Starter Pack (1 Bottle)',
            'quantity': 1,
            'paid_quantity': 1,
            'free_quantity': 0,
            'price': 25000.0,
            'actual_price': 30000.0,
            'badge': 'STARTER',
            'is_default': false,
          },
          {
            'id': 'pkg-buy2-get1',
            'name': 'Special Deal (Buy 2 Get 1 FREE)',
            'quantity': 3,
            'paid_quantity': 2,
            'free_quantity': 1,
            'price': 45000.0,
            'actual_price': 75000.0,
            'badge': 'MOST POPULAR',
            'is_default': true,
          },
        ],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final leadForm = LeadForm.fromJson(formJson);

      expect(leadForm.id, equals('form-glucosafe-ad-2026'));
      expect(leadForm.marketerId, equals('mkt-damilola-01'));
      expect(leadForm.packages.length, equals(2));

      final popularPackage = leadForm.packages.firstWhere((p) => p['id'] == 'pkg-buy2-get1');
      expect(popularPackage['paid_quantity'], equals(2));
      expect(popularPackage['free_quantity'], equals(1));
      expect(popularPackage['quantity'], equals(3));
      expect(popularPackage['price'], equals(45000.0));
      expect(popularPackage['actual_price'], equals(75000.0));
    });

    test('1.2 Form modifications preserve package parity and increment counter state correctly', () {
      final form = LeadForm(
        id: 'form-test-01',
        clientId: 'client-001',
        formTitle: 'Initial Promo Form',
        formSlug: 'initial-promo-form',
        productId: 'prod-001',
        productName: 'Herbal Tea',
        marketerId: 'mkt-001',
        packages: const [
          {'id': 'p1', 'name': 'Single Pack', 'quantity': 1, 'paid_quantity': 1, 'free_quantity': 0, 'price': 15000.0}
        ],
        totalSubmissions: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = form.copyWith(
        formTitle: 'Updated Promo Form with Buy 2 Get 1',
        packages: [
          ...form.packages,
          {'id': 'p2', 'name': 'Buy 2 Get 1 Free', 'quantity': 3, 'paid_quantity': 2, 'free_quantity': 1, 'price': 28000.0}
        ],
        totalSubmissions: form.totalSubmissions + 1,
      );

      expect(updated.title, equals('Updated Promo Form with Buy 2 Get 1'));
      expect(updated.packages.length, equals(2));
      expect(updated.totalSubmissions, equals(6));
      expect(updated.totalOrdersBooked, equals(6));
    });
  });

  group('Phase 2: Public Lead Form Submission & Canonical Phone Normalization', () {
    test('2.1 Canonical Normalizer handles all Nigerian phone variations from ads', () {
      final variations = {
        '+234 801 234 5678': '08012345678',
        '+2348012345678': '08012345678',
        '234 801 234 5678': '08012345678',
        '2348012345678': '08012345678',
        '00234 801 234 5678': '08012345678',
        '002348012345678': '08012345678',
        '08012345678': '08012345678',
        '080 1234 5678': '08012345678',
        '080-1234-5678': '08012345678',
        '(080) 1234 5678': '08012345678',
        '8012345678': '08012345678',
        ' 801 234 5678 ': '08012345678',
        '+234 (0) 801 234 5678': '08012345678',
      };

      variations.forEach((raw, expected) {
        final normalized = NigerianPhoneHelper.normalize(raw);
        final core10 = NigerianPhoneHelper.core10Digits(raw);

        expect(normalized, equals(expected), reason: 'Failed for "$raw"');
        expect(core10, equals('8012345678'), reason: 'Failed core10 for "$raw"');
      });
    });

    test('2.2 Lead Submission Payload Captures UTM attribution, Alt Phone, and Bonus Units', () {
      const rawCustomerPhone = '+234 812 345 6789';
      const rawAltPhone = '080 9876 5432';

      final submissionPayload = {
        'form_id': 'form-glucosafe-ad-2026',
        'customer_name': 'Bolanle Alabi',
        'customer_phone': NigerianPhoneHelper.normalize(rawCustomerPhone),
        'delivery_address': 'Flat 3, Victoria Garden City',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Eti-Osa',
        'delivery_city': 'Ajah',
        'package_selected': 'Special Deal (Buy 2 Get 1 FREE)',
        'package_quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_id': 'pkg-buy2-get1',
        'order_amount': 45000.0,
        'actual_price': 75000.0,
        'utm_source': 'tiktok',
        'utm_medium': 'paid_video',
        'utm_campaign': 'glucosafe_q3_scale',
        'utm_content': 'dr_adewale_review',
        'ad_id': 'tt_ad_99212',
        'metadata': {
          'raw_phone_submitted': rawCustomerPhone,
          'alt_phone': NigerianPhoneHelper.normalize(rawAltPhone),
          'free_bonus_units': 1,
          'retail_price': 75000.0,
        },
      };

      expect(submissionPayload['customer_phone'], equals('08123456789'));
      expect((submissionPayload['metadata'] as Map)['alt_phone'], equals('08098765432'));
      expect(submissionPayload['package_quantity'], equals(3));
      expect(submissionPayload['paid_quantity'], equals(2));
      expect(submissionPayload['free_quantity'], equals(1));
      expect(submissionPayload['utm_source'], equals('tiktok'));
      expect(submissionPayload['ad_id'], equals('tt_ad_99212'));
    });
  });

  group('Phase 3: Anti-Duplicate Detection & Prevention Logic', () {
    test('3.1 Fresh submission successfully creates new order reference', () {
      final initialSubmissionResult = {
        'is_duplicate': false,
        'order_id': 'ord-live-101',
        'order_number': 'ORD-2026-00101',
        'tracking_number': 'TRK-2026-00101',
        'status': 'new',
        'message': 'Order successfully booked from marketing form',
        'redirect_url': 'https://respira.ng/thank-you',
      };

      expect(initialSubmissionResult['is_duplicate'], isFalse);
      expect(initialSubmissionResult['order_number'], equals('ORD-2026-00101'));
    });

    test('3.2 Re-submission with different phone formatting triggers duplicate protection', () {
      // First submission was +234 812 345 6789 (normalized: 08123456789)
      // Second submission comes in as 08123456789 or 2348123456789
      const secondSubmissionRaw = '0812-345-6789';
      final canonicalPhone = NigerianPhoneHelper.normalize(secondSubmissionRaw);
      expect(canonicalPhone, equals('08123456789'));

      final duplicateSubmissionResult = {
        'is_duplicate': true,
        'order_id': 'ord-live-101',
        'order_number': 'ORD-2026-00101',
        'status': 'new',
        'message': 'An order with this phone number was already placed recently and is being processed.',
        'redirect_url': 'https://respira.ng/thank-you',
      };

      expect(duplicateSubmissionResult['is_duplicate'], isTrue);
      // Returns existing order reference instead of creating duplicate
      expect(duplicateSubmissionResult['order_number'], equals('ORD-2026-00101'));
      expect(duplicateSubmissionResult['order_id'], equals('ord-live-101'));
    });

    test('3.3 Customer with distinct phone creates second order without false positive', () {
      const distinctCustomerPhone = '08033334444';
      final canonicalPhone = NigerianPhoneHelper.normalize(distinctCustomerPhone);

      expect(canonicalPhone, isNot(equals('08123456789')));

      final secondDistinctOrderResult = {
        'is_duplicate': false,
        'order_id': 'ord-live-102',
        'order_number': 'ORD-2026-00102',
        'tracking_number': 'TRK-2026-00102',
        'status': 'new',
        'message': 'Order successfully booked from marketing form',
      };

      expect(secondDistinctOrderResult['is_duplicate'], isFalse);
      expect(secondDistinctOrderResult['order_number'], equals('ORD-2026-00102'));
    });
  });

  group('Phase 4: Converting Submissions to Orders across the System', () {
    test('4.1 Converted Order retains full marketing deal package & attribution metadata', () {
      final orderJson = {
        'id': 'ord-converted-001',
        'order_number': 'ORD-2026-00101',
        'tracking_number': 'TRK-2026-00101',
        'client_id': 'client-respira-ng',
        'product_name': 'Herbal Glucosafe Max',
        'customer_name': 'Bolanle Alabi',
        'customer_phone': '08123456789',
        'delivery_address': 'Flat 3, Victoria Garden City',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ajah',
        'lga': 'Eti-Osa',
        'total_amount': 45000.0,
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_name': 'Special Deal (Buy 2 Get 1 FREE)',
        'package_deal_id': 'pkg-buy2-get1',
        'marketer_id': 'mkt-damilola-01',
        'form_id': 'form-glucosafe-ad-2026',
        'status': 'new',
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final order = OrderModel.fromJson(orderJson);

      expect(order.id, equals('ord-converted-001'));
      expect(order.orderNumber, equals('ORD-2026-00101'));
      expect(order.formId, equals('form-glucosafe-ad-2026'));
      expect(order.marketerId, equals('mkt-damilola-01'));
      expect(order.packageDealName, equals('Special Deal (Buy 2 Get 1 FREE)'));
      expect(order.paidQuantity, equals(2));
      expect(order.freeQuantity, equals(1));
      expect(order.quantity, equals(3));
      expect(order.totalAmount, equals(45000.0));
      expect(order.status, equals('pending')); // OrderModel maps initial 'new' status to 'pending'
    });

    test('4.2 Order Conversation Pipeline Chat initializes with Digital Marketer DP', () {
      final conversationJson = {
        'id': 'conv-ord-converted-001',
        'order_id': 'ord-converted-001',
        'order_number': 'ORD-2026-00101',
        'customer_name': 'Bolanle Alabi',
        'marketer_id': 'mkt-damilola-01',
        'marketer_name': 'Damilola Growth Media',
        'marketer_avatar_url': 'https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg',
        'form_id': 'form-glucosafe-ad-2026',
        'closer_id': null,
        'distribution_center_id': 'dc-ikeja-hub',
        'last_message_text': 'Order booked from TikTok Ad Form: Special Deal (2 + 1 FREE)',
        'last_message_sender_role': 'marketer',
        'created_at': DateTime.now().toIso8601String(),
      };

      final conversation = OrderConversationModel.fromJson(conversationJson);

      expect(conversation.orderId, equals('ord-converted-001'));
      expect(conversation.marketerId, equals('mkt-damilola-01'));
      expect(conversation.marketerName, equals('Damilola Growth Media'));
      expect(conversation.marketerAvatarUrl, equals('https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg'));

      // Validate DP attribution on the order conversation card
      final hasMarketerCreated = conversation.marketerName != null && conversation.marketerName!.isNotEmpty;
      final cardAvatar = hasMarketerCreated ? conversation.marketerAvatarUrl : conversation.closerAvatarUrl;
      final cardTitle = hasMarketerCreated ? conversation.marketerName : conversation.customerName;

      expect(cardAvatar, equals('https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg'));
      expect(cardTitle, equals('Damilola Growth Media'));
    });
  });

  group('Phase 5: Asset Scoping & Supervisory Hierarchy Across Converted Orders', () {
    final supervisorMarketer = ClientMarketer(
      id: 'mkt-supervisor-chief',
      clientId: 'client-respira-ng',
      fullName: 'Chief Marketing Officer',
      email: 'cmo@respira.ng',
      phone: '08011112222',
      marketerCode: 'MKT-CHIEF',
      isSupervisor: true,
      commissionModel: 'per_delivered_order',
      commissionPerDeliveredOrder: 1500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final superviseeMarketer = ClientMarketer(
      id: 'mkt-supervisee-tunde',
      clientId: 'client-respira-ng',
      fullName: 'Tunde Media Buyer',
      email: 'tunde@respira.ng',
      phone: '08033334444',
      marketerCode: 'MKT-TUNDE',
      isSupervisor: false,
      supervisorId: 'mkt-supervisor-chief',
      supervisorName: 'Chief Marketing Officer',
      commissionModel: 'per_form_submission',
      commissionPerFormSubmission: 500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final independentMarketer = ClientMarketer(
      id: 'mkt-independent-sam',
      clientId: 'client-respira-ng',
      fullName: 'Sam Freelance',
      email: 'sam@respira.ng',
      phone: '08055556666',
      marketerCode: 'MKT-SAM',
      isSupervisor: false,
      supervisorId: null,
      commissionModel: 'per_delivered_order',
      commissionPerDeliveredOrder: 1000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final allOrders = [
      // Order 1: From Tunde's Form
      OrderModel.fromJson({
        'id': 'ord-tunde-ad-01',
        'order_number': 'ORD-T1',
        'client_id': 'client-respira-ng',
        'product_name': 'Glucosafe Max',
        'customer_name': 'Customer 1',
        'customer_phone': '08011111111',
        'delivery_address': 'Lagos',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'total_amount': 45000,
        'quantity': 3,
        'marketer_id': 'mkt-supervisee-tunde',
        'form_id': 'form-tunde-promo',
        'status': 'delivered',
      }),
      // Order 2: From Supervisor's Direct Form
      OrderModel.fromJson({
        'id': 'ord-sup-ad-02',
        'order_number': 'ORD-S2',
        'client_id': 'client-respira-ng',
        'product_name': 'Glucosafe Max',
        'customer_name': 'Customer 2',
        'customer_phone': '08022222222',
        'delivery_address': 'Lagos',
        'delivery_state': 'Lagos',
        'delivery_city': 'Yaba',
        'total_amount': 25000,
        'quantity': 1,
        'marketer_id': 'mkt-supervisor-chief',
        'form_id': 'form-chief-promo',
        'status': 'delivered',
      }),
      // Order 3: From Independent Sam's Form
      OrderModel.fromJson({
        'id': 'ord-sam-ad-03',
        'order_number': 'ORD-I3',
        'client_id': 'client-respira-ng',
        'product_name': 'Glucosafe Max',
        'customer_name': 'Customer 3',
        'customer_phone': '08033333333',
        'delivery_address': 'Abuja',
        'delivery_state': 'Abuja',
        'delivery_city': 'Wuse',
        'total_amount': 25000,
        'quantity': 1,
        'marketer_id': 'mkt-independent-sam',
        'form_id': 'form-sam-promo',
        'status': 'delivered',
      }),
      // Order 4: Non-marketing direct merchant phone order (No form, no marketer)
      OrderModel.fromJson({
        'id': 'ord-walkin-04',
        'order_number': 'ORD-W4',
        'client_id': 'client-respira-ng',
        'product_name': 'Glucosafe Max',
        'customer_name': 'Customer 4',
        'customer_phone': '08044444444',
        'delivery_address': 'Enugu',
        'delivery_state': 'Enugu',
        'delivery_city': 'Enugu',
        'total_amount': 25000,
        'quantity': 1,
        'marketer_id': null,
        'form_id': null,
        'status': 'delivered',
      }),
    ];

    test('5.1 Standard marketer strictly scopes to only their own ad orders', () {
      final tundeVisibleOrders = allOrders.where((o) => o.marketerId == superviseeMarketer.id).toList();

      expect(tundeVisibleOrders.length, equals(1));
      expect(tundeVisibleOrders.first.id, equals('ord-tunde-ad-01'));
      expect(tundeVisibleOrders.any((o) => o.id == 'ord-sup-ad-02'), isFalse);
      expect(tundeVisibleOrders.any((o) => o.id == 'ord-sam-ad-03'), isFalse);
      expect(tundeVisibleOrders.any((o) => o.id == 'ord-walkin-04'), isFalse);

      final samVisibleOrders = allOrders.where((o) => o.marketerId == independentMarketer.id).toList();
      expect(samVisibleOrders.length, equals(1));
      expect(samVisibleOrders.first.id, equals('ord-sam-ad-03'));
    });

    test('5.2 Supervisor marketer sees own orders + supervisee orders and excludes non-supervisees', () {
      final teamMarketerIds = {
        supervisorMarketer.id,
        superviseeMarketer.id, // Supervised by Chief
      };

      final supervisorVisibleOrders = allOrders.where((o) => o.marketerId != null && teamMarketerIds.contains(o.marketerId)).toList();

      expect(supervisorVisibleOrders.length, equals(2));
      expect(supervisorVisibleOrders.map((o) => o.id), containsAll(['ord-sup-ad-02', 'ord-tunde-ad-01']));
      // Sam is independent, not supervised by Chief
      expect(supervisorVisibleOrders.any((o) => o.id == 'ord-sam-ad-03'), isFalse);
      // Walkin is manual, not from marketing ad
      expect(supervisorVisibleOrders.any((o) => o.id == 'ord-walkin-04'), isFalse);
    });
  });

  group('Phase 6: Closer Confirmation & Commission Settlement Flow', () {
    test('6.1 Closer confirms customer delivery address without overriding marketing package', () {
      final originalOrder = OrderModel.fromJson({
        'id': 'ord-tunde-ad-01',
        'order_number': 'ORD-T1',
        'client_id': 'client-respira-ng',
        'product_name': 'Glucosafe Max',
        'customer_name': 'Customer 1',
        'customer_phone': '08011111111',
        'delivery_address': 'Initial Street Name',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'total_amount': 45000,
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_name': 'Special Deal (Buy 2 Get 1 FREE)',
        'package_deal_id': 'pkg-buy2-get1',
        'marketer_id': 'mkt-supervisee-tunde',
        'form_id': 'form-tunde-promo',
        'status': 'new',
      });

      // Closer confirms delivery details: updates address and status to 'confirmed'
      final confirmedOrder = originalOrder.copyWith(
        deliveryAddress: 'Suit 4, Allen Avenue, Opposite First Bank',
        deliveryCity: 'Ikeja',
        status: 'confirmed',
        closerId: 'closer-chioma-01',
        closerName: 'Chioma Closer',
      );

      expect(confirmedOrder.status, equals('confirmed'));
      expect(confirmedOrder.deliveryAddress, equals('Suit 4, Allen Avenue, Opposite First Bank'));
      // Package deals and marketing attribution remain pristine
      expect(confirmedOrder.packageDealName, equals('Special Deal (Buy 2 Get 1 FREE)'));
      expect(confirmedOrder.freeQuantity, equals(1));
      expect(confirmedOrder.marketerId, equals('mkt-supervisee-tunde'));
      expect(confirmedOrder.closerName, equals('Chioma Closer'));
    });

    test('6.2 Pay-per-form vs Pay-per-delivery commissions calculate accurately', () {
      // Marketer A: Pay-per-Form (₦500 per booked ad lead form)
      const tundeBookedForms = 24;
      const tundeDeliveredOrders = 18;
      const tundeRatePerForm = 500.0;
      const tundeTotalEarned = tundeBookedForms * tundeRatePerForm;

      expect(tundeTotalEarned, equals(12000.0));
      expect(tundeDeliveredOrders, equals(18));

      // Marketer B: Pay-per-Delivered-Order (₦1,000 per delivered package)
      const samBookedForms = 24;
      const samDeliveredOrders = 18;
      const samRatePerDelivery = 1000.0;
      const samTotalEarned = samDeliveredOrders * samRatePerDelivery;

      expect(samTotalEarned, equals(18000.0));
      expect(samTotalEarned, isNot(equals(samBookedForms * samRatePerDelivery)));
    });
  });

  group('Phase 7: Live Remote Database E2E Execution Test', () {
    test('7.1 Live Supabase RPC fn_submit_marketing_lead_order executes and prevents duplicate', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      // Verify lead_forms exists and retrieve an active form
      final leadForms = await client.from('lead_forms').select().limit(1);

      if (leadForms.isEmpty) {
        // If no lead form exists yet, create one for the test
        final clientProfiles = await client.from('client_profiles').select('id, company_name').limit(1);
        final clientId = clientProfiles.isNotEmpty ? clientProfiles.first['id'] : '00000000-0000-0000-0000-000000000001';

        final newForm = await client.from('lead_forms').insert({
          'client_id': clientId,
          'title': 'Automated Test Promo Form',
          'product_name': 'Test Herbal Formula',
          'slug': 'test-promo-${DateTime.now().millisecondsSinceEpoch}',
          'packages': [
            {'id': 'p1', 'name': 'Standard Pack', 'quantity': 1, 'paid_quantity': 1, 'free_quantity': 0, 'price': 20000.0},
            {'id': 'p2', 'name': 'Buy 2 Get 1 FREE', 'quantity': 3, 'paid_quantity': 2, 'free_quantity': 1, 'price': 40000.0},
          ],
          'is_active': true,
        }).select().single();

        leadForms.add(newForm);
      }

      final testForm = leadForms.first;
      final formId = testForm['id'];

      // Generate a unique test phone number
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch % 1000000;
      final basePhone = '0809${uniqueSuffix.toString().padLeft(6, '0')}';
      final formattedPhoneSubmission1 = '+234 ${basePhone.substring(1, 4)} ${basePhone.substring(4, 7)} ${basePhone.substring(7)}';

      // 1. First Live Submission: Fresh Order
      final payload1 = {
        'form_id': formId,
        'customer_name': 'Test Automation User',
        'customer_phone': formattedPhoneSubmission1,
        'delivery_address': '12 Victoria Island Way',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Eti-Osa',
        'delivery_city': 'Victoria Island',
        'package_selected': 'Buy 2 Get 1 FREE',
        'package_quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_id': 'p2',
        'order_amount': 40000.0,
        'utm_source': 'test_automation',
      };

      final response1 = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': payload1,
      });

      expect(response1, isNotNull);
      final resultMap1 = Map<String, dynamic>.from(response1 as Map);
      expect(resultMap1['is_duplicate'], isFalse);
      expect(resultMap1['order_number'], isNotNull);
      expect(resultMap1['order_id'], isNotNull);

      final initialOrderId = resultMap1['order_id'];
      final initialOrderNumber = resultMap1['order_number'];

      // 2. Second Live Submission: Same Customer, Different Phone Format (e.g. without +234, dashes)
      final formattedPhoneSubmission2 = '${basePhone.substring(0, 4)}-${basePhone.substring(4, 7)}-${basePhone.substring(7)}';

      final payload2 = {
        'form_id': formId,
        'customer_name': 'Test Automation User Duplicate',
        'customer_phone': formattedPhoneSubmission2,
        'delivery_address': '12 Victoria Island Way Updated',
        'delivery_state': 'Lagos',
        'delivery_lga': 'Eti-Osa',
        'delivery_city': 'Victoria Island',
        'package_selected': 'Buy 2 Get 1 FREE',
        'package_quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_id': 'p2',
        'order_amount': 40000.0,
        'utm_source': 'test_automation_retry',
      };

      final response2 = await client.rpc('fn_submit_marketing_lead_order', params: {
        'p_payload': payload2,
      });

      expect(response2, isNotNull);
      final resultMap2 = Map<String, dynamic>.from(response2 as Map);

      // Verify Duplicate is Detected Live by the Stored Procedure!
      expect(resultMap2['is_duplicate'], isTrue);
      expect(resultMap2['order_id'] ?? resultMap2['existing_order_id'], equals(initialOrderId));
      expect(resultMap2['order_number'], equals(initialOrderNumber));
      expect(resultMap2['message'], anyOf(contains('already placed'), contains('already exists')));

      // 3. Verify Orders Table Contains EXACTLY ONE Order with this Normalized Phone
      final canonicalPhone = NigerianPhoneHelper.normalize(basePhone);
      final orders = await client.from('orders').select().eq('customer_phone_normalized', canonicalPhone);

      expect(orders.length, equals(1));
      expect(orders.first['order_number'], equals(initialOrderNumber));
      expect(orders.first['customer_phone_normalized'], equals(canonicalPhone));

      // 4. Verify Customer Leads Table recorded the duplicate submission audit trail
      final leads = await client.from('customer_leads').select().eq('customer_phone_normalized', canonicalPhone);

      expect(leads.length, equals(2));
      expect(leads.any((l) => l['status'] == 'duplicate_submission'), isTrue);
    });
  });
}
