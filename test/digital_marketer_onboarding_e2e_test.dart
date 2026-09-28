import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/client_portal/data/datasources/client_portal_remote_datasource.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() async {
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Digital Marketer Onboarding & Foreign Key Integration Test', () {
    test('Successfully onboard Digital Marketer with Auth, Users table, and ClientMarketers records without Foreign Key violation', () async {
      final client = SupabaseClient(
        SupabaseConstants.testingUrl,
        SupabaseConstants.testingServiceRoleKey,
      );

      final clientRows = await client.from('clients').select('id').limit(1);
      final clientId = clientRows.isNotEmpty ? clientRows.first['id'] as String : '33333333-3333-4333-8333-333333333333';

      final dataSource = ClientPortalRemoteDataSourceImpl(client);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'joel.marketer.$ts@novexps-test.com';
      final testPhone = '0808${ts.toString().substring(ts.toString().length - 7)}';

      // 1. Execute Marketer Creation via Remote DataSource
      final marketer = await dataSource.createMarketer(
        clientId: clientId,
        fullName: 'Joel Marketer',
        email: testEmail,
        phone: testPhone,
        password: 'Marketer123!',
        dailyAdSpendBudget: 50000.0,
        commissionRate: 100.0,
        isCommissionEnabled: true,
        isSupervisor: false,
        commissionModel: 'per_form_submission',
        commissionPerFormSubmission: 100.0,
        bankName: 'Access Bank',
        accountNumber: '8085040146',
        accountName: 'Joel Odufu',
      );

      expect(marketer, isNotNull);
      expect(marketer.fullName, equals('Joel Marketer'));
      expect(marketer.email, equals(testEmail));
      expect(marketer.phone, equals(testPhone));
      expect(marketer.userId, isNotNull);
      expect(marketer.marketerCode, startsWith('MKT-'));
      expect(marketer.dailyAdSpendBudget, equals(50000.0));
      expect(marketer.commissionPerFormSubmission, equals(100.0));
      expect(marketer.bankName, equals('Access Bank'));
      expect(marketer.accountNumber, equals('8085040146'));
      expect(marketer.accountName, equals('Joel Odufu'));

      // 2. Verify that public.users contains the record with matching userId
      final usersRes = await client.from('users').select().eq('id', marketer.userId!).limit(1);
      expect((usersRes as List).isNotEmpty, isTrue, reason: 'Record must exist in public.users');
      final userRecord = (usersRes as List).first as Map<String, dynamic>;
      expect(userRecord['email'], equals(testEmail));
      expect(userRecord['role'], equals('marketer'));
      expect(userRecord['first_name'], equals('Joel'));
      expect(userRecord['last_name'], equals('Marketer'));
      expect(userRecord['marketer_id'], equals(marketer.id));

      // 3. Verify that public.client_marketers contains the record with valid FK user_id
      final marketerRes = await client.from('client_marketers').select().eq('id', marketer.id).limit(1);
      expect((marketerRes as List).isNotEmpty, isTrue, reason: 'Record must exist in public.client_marketers');
      final marketerRecord = (marketerRes as List).first as Map<String, dynamic>;
      expect(marketerRecord['user_id'], equals(marketer.userId));
      expect(marketerRecord['full_name'], equals('Joel Marketer'));

      // 4. Clean up test records
      await client.from('client_marketers').delete().eq('id', marketer.id);
      await client.from('users').delete().eq('id', marketer.userId!);
      try {
        await client.auth.admin.deleteUser(marketer.userId!);
      } catch (_) {}
    });
  });
}
