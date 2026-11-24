import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/data/datasources/admin_remote_datasource.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin User Onboarding & Immediate Login Verification', () {
    test('Precious Etuk super admin account logs in successfully with 1FeJirO#', () async {
      final authDataSource = MockAuthRemoteDataSource();

      final user = await authDataSource.login('psolomonetuk95@gmail.com', '1FeJirO#');
      expect(user.email, equals('psolomonetuk95@gmail.com'));
      expect(user.firstName, equals('Precious'));
      expect(user.lastName, equals('Etuk'));
      expect(user.role, equals('super_admin'));
    });

    test('Onboarding a new user in admin datasource registers them for login', () async {
      final adminDataSource = AdminRemoteDataSource();
      final authDataSource = MockAuthRemoteDataSource();

      const testUser = AdminUserItem(
        id: '99999999-aaaa-bbbb-cccc-111111111111',
        email: 'test.onboarded@novaxpress.ng',
        firstName: 'Test',
        lastName: 'Officer',
        phone: '08099998888',
        role: 'dc_operations',
        distributionCenterName: 'Abuja Central DC',
        status: 'active',
      );

      final onboarded = await adminDataSource.onboardUser(
        user: testUser,
        password: 'SecureTestPass123!',
      );

      expect(onboarded.email, equals('test.onboarded@novaxpress.ng'));

      // Verify login works with the new credentials
      final loggedIn = await authDataSource.login('test.onboarded@novaxpress.ng', 'SecureTestPass123!');
      expect(loggedIn.email, equals('test.onboarded@novaxpress.ng'));
      expect(loggedIn.role, equals('dc_operations'));
    });

    test('Precious Etuk wrong password throws AppAuthException', () async {
      final authDataSource = MockAuthRemoteDataSource();

      expect(
        () => authDataSource.login('psolomonetuk95@gmail.com', 'WrongPass!'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
