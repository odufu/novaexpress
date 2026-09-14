import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/dc_console/data/datasources/dc_console_remote_datasource.dart';
import 'package:novexps/features/client_portal/data/datasources/client_portal_remote_datasource.dart';

void main() {
  test('E2E Verification: Client & Closer Creation, Custom Charges, and Auth Login', () async {
    final serviceClient = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    final anonClient = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseAnonKey,
    );

    final dcRemoteDataSource = DCConsoleRemoteDataSourceImpl();
    final authRemoteDataSource = AuthRemoteDataSourceImpl(anonClient);
    final clientPortalDataSource = ClientPortalRemoteDataSourceImpl();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testClientEmail = 'audit.client.$timestamp@novatest.ng';
    final testClientPassword = 'TestClient123!';
    final testCompanyName = 'Audit Apex Logistics $timestamp';

    final testCloserEmail = 'audit.closer.$timestamp@novatest.ng';
    final testCloserPassword = 'TestCloser123!';

    String? createdClientId;
    String? createdClientUserId;
    String? createdCloserId;

    try {
      print('--- 0. Pre-flight checkEmailExists & checkPhoneExists (modal validation flow) ---');
      final emailExists = await dcRemoteDataSource.checkEmailExists(testClientEmail);
      expect(emailExists, isFalse);
      final phoneExists = await authRemoteDataSource.checkPhoneExists('+2348039999999');
      print('✅ Pre-flight checks passed, client remained open.');

      print('--- 1. Creating Client via DC Console Remote DataSource ---');
      final clientProfile = await dcRemoteDataSource.createClient(
        companyName: testCompanyName,
        contactPerson: 'Audit Contact',
        email: testClientEmail,
        phone: '+234803999${timestamp.toString().substring(timestamp.toString().length - 4)}',
        address: '14 Audit Boulevard',
        city: 'Ikeja',
        stateName: 'Lagos',
        tier: 'enterprise',
        closerLimit: 15,
        password: testClientPassword,
        bankName: 'Guaranty Trust Bank',
        bankAccountNumber: '0123456789',
        bankAccountName: testCompanyName,
        customDeliveryFee: 4200.0,
        customPlatformFee: 650.0,
        customFailedAttemptFee: 750.0,
        authDataSource: authRemoteDataSource,
      );

      createdClientId = clientProfile.id;
      print('Client profile created with ID: $createdClientId');
      expect(createdClientId, isNotEmpty);

      print('--- 2. Verifying public.clients Persistence & Custom Charges ---');
      final dbClientRow = await serviceClient
          .from('clients')
          .select('*')
          .eq('id', createdClientId!)
          .single();

      expect(dbClientRow['company_name'], testCompanyName);
      expect(dbClientRow['account_number'], '0123456789');
      expect(dbClientRow['account_name'], testCompanyName);
      expect(dbClientRow['bank_name'], 'Guaranty Trust Bank');
      expect((dbClientRow['custom_delivery_fee'] as num).toDouble(), 4200.0);
      expect((dbClientRow['custom_platform_fee'] as num).toDouble(), 650.0);
      expect((dbClientRow['custom_failed_attempt_fee'] as num).toDouble(), 750.0);
      print('✅ public.clients record verified with custom fee agreements:');
      print('   Delivery Fee: ${dbClientRow['custom_delivery_fee']}');
      print('   Platform Fee: ${dbClientRow['custom_platform_fee']}');
      print('   Failed Attempt Fee: ${dbClientRow['custom_failed_attempt_fee']}');

      print('--- 3. Verifying public.users & auth.users Persistence ---');
      final dbUserRow = await serviceClient
          .from('users')
          .select('*')
          .eq('email', testClientEmail)
          .single();

      createdClientUserId = dbUserRow['id'];
      expect(dbUserRow['role'], 'client');
      expect(dbUserRow['company_id'], isNotNull);
      print('✅ public.users record verified with ID: $createdClientUserId, role: ${dbUserRow['role']}');

      print('--- 4. Testing Client Login via Supabase Auth (Public Anon Client) ---');
      final authResponse = await anonClient.auth.signInWithPassword(
        email: testClientEmail,
        password: testClientPassword,
      );

      expect(authResponse.session, isNotNull);
      expect(authResponse.user?.email, testClientEmail);
      print('✅ Supabase Auth signInWithPassword SUCCESSFUL! Token: ${authResponse.session?.accessToken.substring(0, 20)}...');

      print('--- 5. Testing Flutter App AuthRemoteDataSourceImpl.login ---');
      final userModel = await authRemoteDataSource.login(
        testClientEmail,
        testClientPassword,
      );

      expect(userModel.email, testClientEmail);
      expect(userModel.role, 'client');
      expect(userModel.clientId, createdClientId);
      expect(userModel.bankAccountNumber, '0123456789');
      print('✅ AuthRemoteDataSourceImpl.login SUCCESSFUL! User: ${userModel.firstName} ${userModel.lastName}, Role: ${userModel.role}');

      print('--- 6. Creating Closer via ClientPortalRemoteDataSource ---');
      final closer = await clientPortalDataSource.createCloser(
        clientId: createdClientId!,
        fullName: 'Audit Telesales Closer',
        email: testCloserEmail,
        phone: '+23480777${timestamp.toString().substring(timestamp.toString().length - 5)}',
        password: testCloserPassword,
        dailyCallTarget: 40,
        commissionRate: 600.0,
      );

      createdCloserId = closer.id;
      print('Closer created with ID: $createdCloserId, code: ${closer.closerCode}');

      print('--- 7. Verifying public.client_closers Persistence ---');
      final dbCloserRow = await serviceClient
          .from('client_closers')
          .select('*')
          .eq('id', createdCloserId)
          .single();

      expect(dbCloserRow['client_id'], createdClientId);
      expect((dbCloserRow['commission_rate'] as num).toDouble(), 600.0);
      expect(dbCloserRow['daily_call_target'], 40);
      print('✅ public.client_closers verified: Commission Rate: ${dbCloserRow['commission_rate']} NGN/order');

      print('--- 8. Testing Closer Login via Supabase Auth ---');
      final closerAuthRes = await anonClient.auth.signInWithPassword(
        email: testCloserEmail,
        password: testCloserPassword,
      );
      expect(closerAuthRes.session, isNotNull);
      print('✅ Closer Supabase Auth signInWithPassword SUCCESSFUL!');

    } finally {
      print('--- Cleanup: Removing test records ---');
      try {
        if (createdCloserId != null) {
          await serviceClient.from('client_closers').delete().eq('id', createdCloserId);
        }
        await serviceClient.from('users').delete().eq('email', testCloserEmail);
        final closerAuthUsers = await serviceClient.auth.admin.listUsers();
        for (final u in closerAuthUsers) {
          if (u.email?.toLowerCase() == testCloserEmail.toLowerCase()) {
            await serviceClient.auth.admin.deleteUser(u.id);
          }
        }
      } catch (e) {
        print('Cleanup closer warning: $e');
      }

      try {
        if (createdClientId != null) {
          await serviceClient.from('clients').delete().eq('id', createdClientId);
        }
        await serviceClient.from('users').delete().eq('email', testClientEmail);
        if (createdClientUserId != null) {
          await serviceClient.auth.admin.deleteUser(createdClientUserId);
        }
        final clientAuthUsers = await serviceClient.auth.admin.listUsers();
        for (final u in clientAuthUsers) {
          if (u.email?.toLowerCase() == testClientEmail.toLowerCase()) {
            await serviceClient.auth.admin.deleteUser(u.id);
          }
        }
      } catch (e) {
        print('Cleanup client warning: $e');
      }
      print('✅ Cleanup completed.');
    }
  });
}
