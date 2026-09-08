import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:novexps/core/exceptions/exceptions.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DC Supervisor Authentication and Routing Verification', () {
    test('1. Unregistered emails are rejected; only registered accounts can login', () async {
      final authDs = AuthRemoteDataSourceImpl(
        SupabaseClient(
          'https://placeholder.supabase.co',
          'placeholder-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

      expect(
        () => authDs.login('unregistered.random@novaexpress.ng', 'Password123!'),
        throwsA(isA<AppAuthException>()),
      );
    });

    test('2. Registered accounts log in with their creation role and cannot be misidentified by email heuristics', () async {
      final authDs = AuthRemoteDataSourceImpl(
        SupabaseClient(
          'https://placeholder.supabase.co',
          'placeholder-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

      // Register an account as DC supervisor
      AuthRemoteDataSourceImpl.registerUserInMemory(
        const UserModel(
          id: 'u-kaduna-01',
          email: 'supervisor.kaduna@novaexpress.ng',
          firstName: 'Ibrahim',
          lastName: 'Kaduna',
          phone: '08031112233',
          role: 'dc_manager',
          distributionCenterId: 'dc-kad-01',
          distributionCenterName: 'Kaduna Regional Hub',
        ),
        'Password123!',
      );

      final loggedSupervisor = await authDs.login('supervisor.kaduna@novaexpress.ng', 'Password123!');
      expect(loggedSupervisor.role, equals('dc_manager'));
      expect(loggedSupervisor.isDcManager, isTrue);
      expect(loggedSupervisor.deliveryAgentId, isNull);

      // Verified seed supervisor
      final seedSupervisor = await authDs.login('dc.supervisor@novaexpress.ng', 'Password123!');
      expect(seedSupervisor.role, equals('dc_manager'));
      expect(seedSupervisor.isDcManager, isTrue);

      // Verified seed rider
      final seedRider = await authDs.login('emeka.rider@novaexpress.ng', 'Password123!');
      expect(seedRider.role, equals('delivery_agent'));
      expect(seedRider.isDcManager, isFalse);
      expect(seedRider.isRider, isTrue);
    });

    test('3. Supervisor entity accurately exposes role permissions for DC Console', () {
      const supervisorUser = UserEntity(
        id: 'usr-sup-002',
        email: 'supervisor.002@novaexpress.ng',
        firstName: 'Station',
        lastName: 'Supervisor',
        phone: '08000000002',
        role: 'dc_manager',
        distributionCenterId: 'dc-002',
        distributionCenterName: 'Newi Regional Center',
        deliveryAgentCode: 'DC-002',
      );

      expect(supervisorUser.isDcManager, isTrue);
      expect(supervisorUser.isClient, isFalse);
      expect(supervisorUser.isPda, isFalse);
      expect(supervisorUser.isInHouseRider, isFalse);
    });
  });
}
