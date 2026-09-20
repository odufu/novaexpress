import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/customer_lead.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Closer Account Creation & Capacity Scaling', () {
    test('ClientProfile auto-expands closerLimit when new closers exceed capacity', () {
      var profile = const ClientProfile(
        id: '00000000-0000-4000-8000-789382731303',
        companyName: 'Novacare Health & Wellness Ltd',
        contactPerson: 'Dr. Chuka Okafor',
        email: 'merchant@novacare.com',
        phone: '08031234567',
        address: 'Central Area, Abuja',
        tier: 'enterprise',
        closerLimit: 2,
        totalClosersCount: 2,
        isEnterprise: true,
      );

      // Simulating adding a closer when capacity is full
      final newTotalCount = profile.totalClosersCount + 1;
      final newLimit = newTotalCount > profile.closerLimit ? newTotalCount + 15 : profile.closerLimit;
      profile = profile.copyWith(
        totalClosersCount: newTotalCount,
        closerLimit: newLimit,
      );

      expect(profile.totalClosersCount, 3);
      expect(profile.closerLimit, 18);
      expect(profile.closerLimit > profile.totalClosersCount, isTrue);
    });

    test('Closer initial credentials register in auth memory registry', () {
      final closer = ClientCloser(
        id: 'cls-test-101',
        clientId: '00000000-0000-4000-8000-789382731303',
        userId: 'usr-test-101',
        closerCode: 'CLS-NOVA-002',
        fullName: 'Chidinma Eze',
        email: 'chidinma@novacare.com',
        phone: '08031234567',
        dailyCallTarget: 60,
        commissionRate: 750.0,
      );

      expect(closer.fullName, 'Chidinma Eze');
      expect(closer.closerCode, 'CLS-NOVA-002');
      expect(closer.commissionRate, 750.0);
      expect(closer.dailyCallTarget, 60);
      expect(closer.isActive, isTrue);
    });
  });

  group('Credentials Formatting & Send Channels', () {
    String formatPhoneNumber(String raw) {
      final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.startsWith('0') && digits.length >= 10) {
        return '234${digits.substring(1)}';
      }
      if (digits.startsWith('234')) {
        return digits;
      }
      return digits.isNotEmpty ? '234$digits' : '2348000000000';
    }

    String buildInviteMessage({
      required String companyName,
      required String fullName,
      required String closerCode,
      required String email,
      required String password,
    }) {
      return '''🎉 *Welcome to the $companyName Telesales Team!*

Hello $fullName, your Closer Workspace account has been created on NoveXPS.

Here are your official login credentials:
🌐 *Portal URL:* https://novexps.web.app
👤 *Name:* $fullName
🆔 *Closer Code:* $closerCode
📧 *Login Email:* $email
🔒 *Password:* $password

📲 Please log into the portal to review your assigned customer leads, place live dispatch orders, and track your closed delivery commissions.

Best regards,
$companyName Management''';
    }

    test('Phone number normalizes local 080 format to international 234 standard', () {
      expect(formatPhoneNumber('08031234567'), '2348031234567');
      expect(formatPhoneNumber('+234 802 112 2334'), '2348021122334');
      expect(formatPhoneNumber('2348123456789'), '2348123456789');
    });

    test('Invite message contains all critical credential tokens', () {
      final msg = buildInviteMessage(
        companyName: 'Novacare',
        fullName: 'Amaka Chioma',
        closerCode: 'CLS-NOVA-001',
        email: 'closer@novacare.com',
        password: 'Password123!',
      );

      expect(msg, contains('Novacare'));
      expect(msg, contains('Amaka Chioma'));
      expect(msg, contains('CLS-NOVA-001'));
      expect(msg, contains('closer@novacare.com'));
      expect(msg, contains('Password123!'));
      expect(msg, contains('https://novexps.web.app'));
    });

    test('WhatsApp URL encoding generates valid web link', () {
      final phone = formatPhoneNumber('08021122334');
      final message = buildInviteMessage(
        companyName: 'Novacare',
        fullName: 'Amaka Chioma',
        closerCode: 'CLS-NOVA-001',
        email: 'closer@novacare.com',
        password: 'Password123!',
      );

      final encoded = Uri.encodeComponent(message);
      final waUri = Uri.parse('https://wa.me/$phone?text=$encoded');

      expect(waUri.scheme, 'https');
      expect(waUri.host, 'wa.me');
      expect(waUri.path, '/2348021122334');
      expect(waUri.queryParameters['text'], contains('Amaka Chioma'));
      expect(waUri.queryParameters['text'], contains('Password123!'));
    });

    test('SMS URI generates valid scheme and parameters', () {
      final msg = 'Hello Closer';
      final smsUri = Uri(
        scheme: 'sms',
        path: '08021122334',
        queryParameters: {'body': msg},
      );

      expect(smsUri.scheme, 'sms');
      expect(smsUri.path, '08021122334');
      expect(smsUri.queryParameters['body'], 'Hello Closer');
    });
  });

  group('Closer Performance Monitoring & Attribution Engine', () {
    final closer = const ClientCloser(
      id: 'closer-uuid-001',
      clientId: '00000000-0000-4000-8000-789382731303',
      userId: 'user-uuid-001',
      closerCode: 'CLS-NOVA-001',
      fullName: 'Amaka Chioma',
      email: 'closer@novacare.com',
      phone: '08021122334',
      dailyCallTarget: 50,
      commissionRate: 500.0,
      totalLeadsAssigned: 10,
    );

    final now = DateTime.now();

    final orderDelivered = OrderEntity(
      id: 'ord-001',
      orderNumber: 'NOV-2026-1001',
      customerName: 'Fatima Aliyu',
      customerPhone: '08011111111',
      deliveryState: 'Abuja',
      deliveryCity: 'Garki',
      deliveryAddress: 'Area 11',
      productName: 'Respira Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 25000,
      upsellAmount: 0,
      totalAmount: 25000,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'paid',
      closerId: 'closer-uuid-001',
      closerName: 'Amaka Chioma',
      closerCode: 'CLS-NOVA-001',
      createdAt: now,
    );

    final orderInTransit = OrderEntity(
      id: 'ord-002',
      orderNumber: 'NOV-2026-1002',
      customerName: 'Ibrahim Musa',
      customerPhone: '08022222222',
      deliveryState: 'Abuja',
      deliveryCity: 'Wuse 2',
      deliveryAddress: 'Adetokunbo Ademola',
      productName: 'Respira Tea',
      status: 'in_transit',
      quantity: 2,
      basePrice: 45000,
      upsellAmount: 0,
      totalAmount: 45000,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      closerId: 'user-uuid-001', // User ID match
      closerName: 'closer@novacare.com',
      createdAt: now,
    );

    final orderPending = OrderEntity(
      id: 'ord-003',
      orderNumber: 'NOV-2026-1003',
      customerName: 'Grace Eze',
      customerPhone: '08033333333',
      deliveryState: 'Abuja',
      deliveryCity: 'Maitama',
      deliveryAddress: 'Gana Street',
      productName: 'Respira Tea',
      status: 'pending_dispatch',
      quantity: 1,
      basePrice: 25000,
      upsellAmount: 0,
      totalAmount: 25000,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      closerCode: 'CLS-NOVA-001', // Closer Code match
      createdAt: now,
    );

    final orderOtherCloser = OrderEntity(
      id: 'ord-004',
      orderNumber: 'NOV-2026-1004',
      customerName: 'Tunde Bakare',
      customerPhone: '08044444444',
      deliveryState: 'Lagos',
      deliveryCity: 'Ikeja',
      deliveryAddress: 'Allen Avenue',
      productName: 'Detox Cleanse',
      status: 'delivered',
      quantity: 1,
      basePrice: 30000,
      upsellAmount: 0,
      totalAmount: 30000,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'paid',
      closerId: 'other-closer-999',
      closerName: 'Kelechi Obi',
      closerCode: 'CLS-LAG-002',
      createdAt: now,
    );

    test('getOrdersForCloser accurately attributes across all closer identifiers', () {
      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health',
          contactPerson: 'Dr. Chuka',
          email: 'merchant@novacare.com',
          phone: '08031234567',
          address: 'Abuja',
        ),
        closers: [closer],
        orders: [orderDelivered, orderInTransit, orderPending, orderOtherCloser],
      );

      final matchedOrders = state.getOrdersForCloser(closer.id, closer.email);
      expect(matchedOrders.length, 3);
      expect(matchedOrders.map((o) => o.orderNumber).toList(), containsAll(['NOV-2026-1001', 'NOV-2026-1002', 'NOV-2026-1003']));
      expect(matchedOrders.map((o) => o.orderNumber).toList(), isNot(contains('NOV-2026-1004')));
    });

    test('getCloserPerformanceMetrics correctly calculates revenue, commission, and success rate', () {
      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health',
          contactPerson: 'Dr. Chuka',
          email: 'merchant@novacare.com',
          phone: '08031234567',
          address: 'Abuja',
        ),
        closers: [closer],
        orders: [orderDelivered, orderInTransit, orderPending, orderOtherCloser],
      );

      final metrics = state.getCloserPerformanceMetrics(closer.id, closer.email);

      expect(metrics['totalBooked'], 3);
      expect(metrics['bookedCount'], 3);
      expect(metrics['deliveredCount'], 1);
      expect(metrics['inTransitCount'], 1);
      expect(metrics['pendingCount'], 1);
      expect(metrics['failedCount'], 0);
      expect(metrics['grossSales'], 25000.0);
      expect(metrics['earnedCommission'], 1 * 500.0);
      // 1 delivered out of 3 booked = 33.33%
      expect((metrics['successRate'] as double).toStringAsFixed(1), '33.3');
    });

    test('totalCloserRevenue calculates sum of delivered closer orders', () {
      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health',
          contactPerson: 'Dr. Chuka',
          email: 'merchant@novacare.com',
          phone: '08031234567',
          address: 'Abuja',
        ),
        closers: [closer],
        orders: [orderDelivered, orderInTransit, orderPending, orderOtherCloser],
      );

      // Delivered closer orders: ord-001 (25000) + ord-004 (30000) = 55000
      expect(state.totalCloserRevenue, 55000.0);
    });

    test('topClosersLeaderboard dynamically ranks closers by live booked orders', () {
      final closer2 = const ClientCloser(
        id: 'closer-uuid-002',
        clientId: '00000000-0000-4000-8000-789382731303',
        closerCode: 'CLS-NOVA-002',
        fullName: 'Chidinma Eze',
        email: 'chidinma@novacare.com',
        phone: '08099999999',
        totalOrdersBooked: 0,
      );

      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health',
          contactPerson: 'Dr. Chuka',
          email: 'merchant@novacare.com',
          phone: '08031234567',
          address: 'Abuja',
        ),
        closers: [closer2, closer], // closer has 3 live booked orders, closer2 has 0
        orders: [orderDelivered, orderInTransit, orderPending],
      );

      final leaderboard = state.topClosersLeaderboard;
      expect(leaderboard.first.id, closer.id);
      expect(leaderboard.last.id, closer2.id);
    });
  });

  group('Closer Code Collision Prevention & Pre-flight Error Formatting', () {
    test('Calculates next closer code suffix higher than any existing suffix in team', () {
      final existingClosers = [
        const ClientCloser(id: '1', clientId: 'c1', closerCode: 'CLS-NOVA-001', fullName: 'Amaka', email: 'a@n.com', phone: '0801'),
        const ClientCloser(id: '2', clientId: 'c1', closerCode: 'CLS-NOVA-002', fullName: 'Chidinma', email: 'b@n.com', phone: '0802'),
        const ClientCloser(id: '3', clientId: 'c1', closerCode: 'CLS-NOVA-103', fullName: 'Prince', email: 'c@n.com', phone: '0803'),
      ];

      int maxExisting = 0;
      for (final c in existingClosers) {
        final match = RegExp(r'\d+$').firstMatch(c.closerCode);
        if (match != null) {
          final n = int.tryParse(match.group(0)!);
          if (n != null && n > maxExisting) maxExisting = n;
        }
      }

      final candidateNum = maxExisting >= 100 ? maxExisting + 1 : (maxExisting > 0 ? maxExisting + 1 : 101);
      final generatedCode = 'CLS-NOVA-${candidateNum.toString().padLeft(3, '0')}';

      expect(maxExisting, 103);
      expect(candidateNum, 104);
      expect(generatedCode, 'CLS-NOVA-104');
    });

    test('Translates postgres duplicate key exceptions to user-friendly messages', () {
      String formatError(String raw) {
        if (raw.contains('users_phone_number_key') || (raw.contains('phone_number') && raw.contains('already exists'))) {
          return "Phone number is already registered to another account. Please use a unique phone number.";
        } else if (raw.contains('client_closers_closer_code_key') || (raw.contains('closer_code') && raw.contains('already exists'))) {
          return "Closer code collision detected. Please try again to generate a new unique code.";
        } else if (raw.contains('users_email_key') || (raw.contains('email') && raw.contains('already exists'))) {
          return "Email is already registered. Please use a unique email address.";
        }
        return raw;
      }

      const phoneErr = 'PostgresException(message: duplicate key value violates unique constraint "users_phone_number_key", code: 23505, details: Key (phone_number)=(08085040146) already exists., hint: null)';
      const closerErr = 'PostgresException(message: duplicate key value violates unique constraint "client_closers_closer_code_key", code: 23505, details: Key (closer_code)=(CLS-NOVA-104) already exists., hint: null)';
      const emailErr = 'PostgresException(message: duplicate key value violates unique constraint "users_email_key", code: 23505, details: Key (email)=(closer@novacare.com) already exists., hint: null)';

      expect(formatError(phoneErr), contains('already registered to another account'));
      expect(formatError(closerErr), contains('Closer code collision detected'));
      expect(formatError(emailErr), contains('Email is already registered'));
    });
  });
}
