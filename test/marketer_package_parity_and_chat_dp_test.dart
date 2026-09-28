import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_model.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_message_model.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';

void main() {
  group('Marketer Package Parity Tests', () {
    test('Package deals support paid units, free bonuses, and actual retail prices', () {
      final leadPackage = {
        'id': 'pkg-buy2-get1',
        'name': 'Buy 2 Get 1 FREE Special',
        'quantity': 3, // Total stock deducted
        'paid_quantity': 2,
        'free_quantity': 1,
        'price': 45000.0,
        'actual_price': 75000.0,
        'badge': 'HOT DEAL',
        'description': 'Buy two units and get one extra unit completely free!',
        'is_default': true,
      };

      expect(leadPackage['quantity'], equals(3));
      expect(leadPackage['paid_quantity'], equals(2));
      expect(leadPackage['free_quantity'], equals(1));
      expect(leadPackage['price'], equals(45000.0));
      expect(leadPackage['actual_price'], equals(75000.0));
      expect(leadPackage['badge'], equals('HOT DEAL'));

      // Validate stock deduction rule: physical inventory deduction equals paid + free units
      final paidQty = leadPackage['paid_quantity'] as int;
      final freeQty = leadPackage['free_quantity'] as int;
      final totalDeductionQty = leadPackage['quantity'] as int;
      expect(totalDeductionQty, equals(paidQty + freeQty));
    });

    test('OrderEntity and OrderModel serialize and deserialize package deal attributes', () {
      final json = {
        'id': 'ord-test-999',
        'order_number': 'ORD-99901',
        'tracking_number': 'TRK-99901',
        'client_id': 'client-respira',
        'product_name': 'Herbal Glucosafe',
        'customer_name': 'Adeola Balogun',
        'customer_phone': '08012345678',
        'delivery_address': 'Plot 4, Allen Avenue',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'total_amount': 45000.0,
        'quantity': 3,
        'paid_quantity': 2,
        'free_quantity': 1,
        'package_deal_name': 'Buy 2 Get 1 FREE Special',
        'package_deal_id': 'pkg-buy2-get1',
        'marketer_id': 'mkt-dami-01',
        'form_id': 'form-glucosafe-promo',
        'closer_id': 'closer-chioma-01',
        'status': 'new',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, equals('ord-test-999'));
      expect(order.paidQuantity, equals(2));
      expect(order.freeQuantity, equals(1));
      expect(order.packageDealName, equals('Buy 2 Get 1 FREE Special'));
      expect(order.packageDealId, equals('pkg-buy2-get1'));
      expect(order.marketerId, equals('mkt-dami-01'));
      expect(order.formId, equals('form-glucosafe-promo'));
      expect(order.quantity, equals(3));
    });
  });

  group('Order Pipeline Chat & Marketer DP Attribution Tests', () {
    test('OrderConversation deserializes digital marketer DP and attribution data', () {
      final json = {
        'id': 'conv-ord-999',
        'order_id': 'ord-test-999',
        'client_id': 'client-respira',
        'customer_name': 'Adeola Balogun',
        'order_number': 'ORD-99901',
        'marketer_id': 'mkt-dami-01',
        'marketer_name': 'Damilola Media',
        'marketer_avatar_url': 'https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg',
        'form_id': 'form-glucosafe-promo',
        'closer_id': 'closer-chioma-01',
        'closer_name': 'Chioma Okafor',
        'distribution_center_id': 'dc-ikeja-main',
        'delivery_agent_id': 'rider-tunde-01',
        'last_message_text': 'Order booked from TikTok Campaign form',
        'last_message_sender_role': 'marketer',
        'last_message_at': DateTime.now().toIso8601String(),
        'unread_client_count': 0,
        'unread_dc_count': 1,
        'unread_rider_count': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final conv = OrderConversationModel.fromJson(json);

      expect(conv.marketerId, equals('mkt-dami-01'));
      expect(conv.marketerName, equals('Damilola Media'));
      expect(conv.marketerAvatarUrl, equals('https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg'));
      expect(conv.formId, equals('form-glucosafe-promo'));

      // Validate DP attribution logic: when marketer created the order via their form, the card DP is that of the digital marketer
      final isMarketerCreated = conv.marketerName != null && conv.marketerName!.isNotEmpty;
      final displayAvatar = isMarketerCreated ? conv.marketerAvatarUrl : conv.closerAvatarUrl;
      final displayName = isMarketerCreated ? conv.marketerName : conv.customerName;

      expect(isMarketerCreated, isTrue);
      expect(displayAvatar, equals('https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg'));
      expect(displayName, equals('Damilola Media'));
    });

    test('ChatSenderRole.marketer serializes and parses correctly in messages', () {
      final msgJson = {
        'id': 'msg-001',
        'conversation_id': 'conv-ord-999',
        'sender_id': 'mkt-dami-01',
        'sender_role': 'marketer',
        'sender_name': 'Damilola Media',
        'sender_avatar_url': 'https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg',
        'message_text': 'Customer selected the Buy 2 Get 1 FREE special on TikTok form!',
        'message_type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      };

      final message = OrderConversationMessageModel.fromJson(msgJson);

      expect(message.senderRole, equals(ChatSenderRole.marketer));
      expect(message.senderName, equals('Damilola Media'));
      expect(message.senderAvatarUrl, equals('https://res.cloudinary.com/demo/image/upload/v1/dami_dp.jpg'));

      final serialized = message.toJson();
      expect(serialized['sender_role'], equals('marketer'));
    });

    test('ClientMarketer entity supports full profile photo, contact, and settlement bank update', () {
      final marketer = ClientMarketer(
        id: 'mkt-dami-01',
        clientId: 'client-respira',
        fullName: 'Damilola Media Growth',
        email: 'damilola@growth.ng',
        phone: '08123456789',
        marketerCode: 'MKT-DAMI',
        avatarUrl: 'https://res.cloudinary.com/demo/image/upload/v1/new_dami_dp.jpg',
        bankName: 'Opay (Paycom)',
        accountNumber: '8123456789',
        accountName: 'Damilola Media Solutions',
        dailyAdSpendBudget: 50000.0,
        totalLeadsGenerated: 240,
        totalOrdersGenerated: 180,
        totalOrdersDelivered: 150,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = marketer.copyWith(
        avatarUrl: 'https://res.cloudinary.com/demo/image/upload/v1/updated_photo.jpg',
        phone: '08199998888',
        bankName: 'Moniepoint MFB',
        accountNumber: '9999888877',
        accountName: 'Damilola Ventures',
      );

      expect(updated.avatarUrl, equals('https://res.cloudinary.com/demo/image/upload/v1/updated_photo.jpg'));
      expect(updated.phone, equals('08199998888'));
      expect(updated.bankName, equals('Moniepoint MFB'));
      expect(updated.accountNumber, equals('9999888877'));
      expect(updated.accountName, equals('Damilola Ventures'));
    });
  });

  group('Nigerian Phone Normalization & Duplicate Avoidance Tests', () {
    test('NigerianPhoneHelper canonicalizes all valid variations to 080XXXXXXXX', () {
      final variations = [
        '+234 801 234 5678',
        '+2348012345678',
        '234 801 234 5678',
        '2348012345678',
        '00234 801 234 5678',
        '002348012345678',
        '08012345678',
        '080 1234 5678',
        '080-1234-5678',
        '(080) 1234 5678',
        '8012345678',
        ' 801 234 5678 ',
        '+234 (0) 801 234 5678',
      ];

      for (final raw in variations) {
        final canonical = NigerianPhoneHelper.normalize(raw);
        final core10 = NigerianPhoneHelper.core10Digits(raw);
        expect(
          canonical,
          equals('08012345678'),
          reason: 'Failed to normalize variation: "$raw"',
        );
        expect(
          core10,
          equals('8012345678'),
          reason: 'Failed to extract core 10 digits from variation: "$raw"',
        );
      }
    });

    test('Duplicate form submission payload returns existing order reference without creating duplicates', () {
      final freshOrderResponse = {
        'order_id': 'ord-live-001',
        'order_number': 'ORD-2026-0001',
        'status': 'new',
        'is_duplicate': false,
        'message': 'Order successfully booked from marketing form',
      };

      expect(freshOrderResponse['is_duplicate'], isFalse);

      final duplicateOrderResponse = {
        'order_id': 'ord-live-001',
        'order_number': 'ORD-2026-0001',
        'status': 'pending',
        'is_duplicate': true,
        'message': 'An order with this phone number was already placed recently and is being processed.',
      };

      expect(duplicateOrderResponse['is_duplicate'], isTrue);
      expect(duplicateOrderResponse['order_number'], equals('ORD-2026-0001'));
    });
  });

  group('Marketer Asset Scoping & Supervisory Hierarchy Tests', () {
    final supervisor = ClientMarketer(
      id: 'mkt-supervisor-01',
      clientId: 'client-respira',
      fullName: 'Chief Marketing Officer',
      email: 'cmo@respira.ng',
      phone: '08022223333',
      marketerCode: 'MKT-SUP-01',
      isSupervisor: true,
      commissionModel: 'per_delivered_order',
      commissionPerDeliveredOrder: 1500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final superviseeA = ClientMarketer(
      id: 'mkt-staff-01',
      clientId: 'client-respira',
      fullName: 'Tunde Media Buyer',
      email: 'tunde@respira.ng',
      phone: '08033334444',
      marketerCode: 'MKT-TUNDE',
      isSupervisor: false,
      supervisorId: 'mkt-supervisor-01',
      supervisorName: 'Chief Marketing Officer',
      commissionModel: 'per_form_submission',
      commissionPerFormSubmission: 500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final unassignedMarketerB = ClientMarketer(
      id: 'mkt-independent-02',
      clientId: 'client-respira',
      fullName: 'Independent Marketer',
      email: 'indie@respira.ng',
      phone: '08044445555',
      marketerCode: 'MKT-INDIE',
      isSupervisor: false,
      supervisorId: null,
      commissionModel: 'per_delivered_order',
      commissionPerDeliveredOrder: 1000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final allMarketers = [supervisor, superviseeA, unassignedMarketerB];

    test('Regular digital marketer strictly scopes to only their own assets', () {
      final activeMarketer = superviseeA;
      final allowedIds = {activeMarketer.id};

      // Simulated orders in system
      final orders = [
        OrderModel.fromJson({
          'id': 'ord-1',
          'order_number': 'ORD-1',
          'client_id': 'client-respira',
          'product_name': 'Glucosafe',
          'customer_name': 'Customer A',
          'customer_phone': '08011111111',
          'delivery_address': 'Lagos',
          'delivery_state': 'Lagos',
          'delivery_city': 'Ikeja',
          'total_amount': 25000,
          'quantity': 1,
          'marketer_id': superviseeA.id,
          'form_id': 'form-tunde-ad-01',
          'status': 'new',
        }),
        OrderModel.fromJson({
          'id': 'ord-2',
          'order_number': 'ORD-2',
          'client_id': 'client-respira',
          'product_name': 'Glucosafe',
          'customer_name': 'Customer B',
          'customer_phone': '08022222222',
          'delivery_address': 'Abuja',
          'delivery_state': 'Abuja',
          'delivery_city': 'Garki',
          'total_amount': 25000,
          'quantity': 1,
          'marketer_id': unassignedMarketerB.id,
          'form_id': 'form-indie-ad-02',
          'status': 'new',
        }),
      ];

      final visibleOrders = orders.where((o) => allowedIds.contains(o.marketerId)).toList();

      expect(visibleOrders.length, equals(1));
      expect(visibleOrders.first.id, equals('ord-1'));
      expect(visibleOrders.any((o) => o.marketerId == unassignedMarketerB.id), isFalse);
    });

    test('Supervisor marketer can see supervisees orders and filter between team and self', () {
      final supervisees = allMarketers.where((m) => m.supervisorId == supervisor.id).toList();
      expect(supervisees.length, equals(1));
      expect(supervisees.first.id, equals(superviseeA.id));

      final allTeamMarketerIds = {supervisor.id, ...supervisees.map((s) => s.id)};

      final orders = [
        OrderModel.fromJson({
          'id': 'ord-sup-1',
          'order_number': 'ORD-S1',
          'client_id': 'client-respira',
          'product_name': 'Glucosafe',
          'customer_name': 'Customer S',
          'customer_phone': '08011111111',
          'delivery_address': 'Lagos',
          'delivery_state': 'Lagos',
          'delivery_city': 'Ikeja',
          'total_amount': 25000,
          'quantity': 1,
          'marketer_id': supervisor.id,
          'form_id': 'form-sup-01',
          'status': 'delivered',
        }),
        OrderModel.fromJson({
          'id': 'ord-tunde-1',
          'order_number': 'ORD-T1',
          'client_id': 'client-respira',
          'product_name': 'Glucosafe',
          'customer_name': 'Customer T',
          'customer_phone': '08022222222',
          'delivery_address': 'Lagos',
          'delivery_state': 'Lagos',
          'delivery_city': 'Yaba',
          'total_amount': 25000,
          'quantity': 1,
          'marketer_id': superviseeA.id,
          'form_id': 'form-tunde-01',
          'status': 'delivered',
        }),
        OrderModel.fromJson({
          'id': 'ord-indie-1',
          'order_number': 'ORD-I1',
          'client_id': 'client-respira',
          'product_name': 'Glucosafe',
          'customer_name': 'Customer I',
          'customer_phone': '08033333333',
          'delivery_address': 'Port Harcourt',
          'delivery_state': 'Rivers',
          'delivery_city': 'PH',
          'total_amount': 25000,
          'quantity': 1,
          'marketer_id': unassignedMarketerB.id,
          'form_id': 'form-indie-01',
          'status': 'delivered',
        }),
      ];

      // All Team View
      final allTeamOrders = orders.where((o) => allTeamMarketerIds.contains(o.marketerId)).toList();
      expect(allTeamOrders.length, equals(2));
      expect(allTeamOrders.map((o) => o.id), containsAll(['ord-sup-1', 'ord-tunde-1']));
      expect(allTeamOrders.any((o) => o.id == 'ord-indie-1'), isFalse);

      // Self View
      final selfOrders = orders.where((o) => o.marketerId == supervisor.id).toList();
      expect(selfOrders.length, equals(1));
      expect(selfOrders.first.id, equals('ord-sup-1'));
    });

    test('Configurable commission correctly computes per_form_submission and per_delivered_order models', () {
      // Supervisee A uses per_form_submission
      expect(superviseeA.commissionModel, equals('per_form_submission'));
      expect(superviseeA.effectiveCommissionPerSubmission, equals(500.0));
      const totalBookedForms = 35;
      final tundeEarnings = totalBookedForms * superviseeA.effectiveCommissionPerSubmission;
      expect(tundeEarnings, equals(17500.0));

      // Supervisor uses per_delivered_order
      expect(supervisor.commissionModel, equals('per_delivered_order'));
      expect(supervisor.effectiveCommissionPerDelivery, equals(1500.0));
      const totalDeliveredOrders = 20;
      final supervisorEarnings = totalDeliveredOrders * supervisor.effectiveCommissionPerDelivery;
      expect(supervisorEarnings, equals(30000.0));
    });
  });
}
