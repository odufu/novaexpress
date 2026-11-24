import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/exceptions/exceptions.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/admin_console/presentation/widgets/admin_user_modal.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/auth/presentation/widgets/change_password_modal.dart';

void main() {
  group('Admin User Onboarding with Custom Password & Password Change', () {
    test('1. Onboarding user with custom password registers in auth datasource and enables login', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adminNotifier = container.read(adminConsoleProvider.notifier);
      final mockAuth = MockAuthRemoteDataSource();

      const testEmail = 'tunde.operations@novaxpress.ng';
      const testPassword = 'NovaPassword@2026';

      final newUser = AdminUserItem(
        id: 'usr-tunde-test-01',
        email: testEmail,
        firstName: 'Tunde',
        lastName: 'Adeleke',
        phone: '08123456789',
        role: 'dc_operations',
        distributionCenterId: 'DC-ABJ-01',
        distributionCenterName: 'Abuja Central DC',
        status: 'active',
      );

      // Save user with custom password
      await adminNotifier.saveUser(newUser, testPassword);

      // Verify user appears in state
      final adminState = container.read(adminConsoleProvider);
      expect(adminState.users.any((u) => u.email == testEmail), isTrue);

      // Verify login with correct custom password succeeds
      final loggedInUser = await mockAuth.login(testEmail, testPassword);
      expect(loggedInUser.email, equals(testEmail));
      expect(loggedInUser.firstName, equals('Tunde'));

      // Verify login with wrong password fails
      expect(
        () => mockAuth.login(testEmail, 'WrongPassword123!'),
        throwsA(isA<AppAuthException>()),
      );
    });

    test('2. User can change password successfully, invalidating old password', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authProvider.notifier);
      final mockAuth = MockAuthRemoteDataSource();

      const userEmail = 'change.pass.user@novaxpress.ng';
      const initialPassword = 'InitialSecret#2026';
      const newPassword = 'UpgradedSecret#2027';

      // Seed user in mock auth
      final adminNotifier = container.read(adminConsoleProvider.notifier);
      await adminNotifier.saveUser(
        AdminUserItem(
          id: 'usr-pwd-test-02',
          email: userEmail,
          firstName: 'Chidi',
          lastName: 'Okeke',
          phone: '08098765432',
          role: 'merchant_inventory_officer',
          status: 'active',
        ),
        initialPassword,
      );

      // Log in as user
      await authNotifier.login(userEmail, initialPassword);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Attempt changing password with wrong current password should fail
      final failedChange = await authNotifier.changePassword(
        currentPassword: 'IncorrectOldPassword',
        newPassword: newPassword,
      );
      expect(failedChange['success'], isFalse);

      // Change password with correct current password should succeed
      final successChange = await authNotifier.changePassword(
        currentPassword: initialPassword,
        newPassword: newPassword,
      );
      expect(successChange['success'], isTrue);

      // Verify login with old password now fails
      expect(
        () => mockAuth.login(userEmail, initialPassword),
        throwsA(isA<AppAuthException>()),
      );

      // Verify login with new password succeeds
      final userWithNewPass = await mockAuth.login(userEmail, newPassword);
      expect(userWithNewPass.email, equals(userEmail));
    });

    testWidgets('3. AdminUserModal allows password entry and generation', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminUserItem? savedUser;
      String? savedPassword;

      final dcs = <AdminDistributionCenter>[
        const AdminDistributionCenter(
          id: 'DC-ABJ-01',
          code: 'ABJ-01',
          name: 'Abuja Central DC',
          city: 'Abuja',
          state: 'FCT',
          address: 'Idu Industrial Yard',
          supervisorName: 'Adekunle Supervisor',
          capacity: 10000,
          activeRiders: 15,
          currentStockCount: 4500,
          vaultBalance: 250000,
        ),
      ];

      final merchants = <AdminMerchant>[
        const AdminMerchant(
          id: 'merchant-novacare',
          businessName: 'Novacare Limited',
          contactName: 'Dr. Chuka Okafor',
          email: 'novacare@novaxpress.net',
          phone: '08034455667',
          tier: 'Enterprise',
          status: 'active',
          closerCount: 2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUserModal(
              distributionCenters: dcs,
              merchants: merchants,
              onSave: (user, password) {
                savedUser = user;
                savedPassword = password;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial Account Password label and Generate button
      expect(find.text('Initial Account Password *'), findsOneWidget);
      expect(find.text('Generate Secure'), findsOneWidget);

      // Tap Generate Secure password
      await tester.tap(find.text('Generate Secure'));
      await tester.pumpAndSettle();

      // Fill in required fields
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Tunde'), 'Nkechi');
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Adeleke'), 'Nwosu');
      await tester.enterText(find.widgetWithText(TextFormField, 'user@novaxpress.ng'), 'nkechi.nwosu@novaxpress.ng');

      // Submit
      await tester.tap(find.text('Create User'));
      await tester.pumpAndSettle();

      expect(savedUser, isNotNull);
      expect(savedUser!.firstName, equals('Nkechi'));
      expect(savedUser!.lastName, equals('Nwosu'));
      expect(savedUser!.email, equals('nkechi.nwosu@novaxpress.ng'));
      expect(savedPassword, isNotNull);
      expect(savedPassword!.startsWith('Nova'), isTrue);
      expect(savedPassword!.length, greaterThanOrEqualTo(6));
    });

    testWidgets('4. ChangePasswordModal validates current, new, and confirm passwords', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChangePasswordModal(
                email: 'test.user@novaxpress.ng',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('test.user@novaxpress.ng'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);

      // Try saving with empty fields -> should show required validation errors
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password is required'), findsOneWidget);
      expect(find.text('New password is required'), findsOneWidget);

      // Enter mismatched passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'OldPass123!');
      await tester.enterText(textFields.at(1), 'NewPass123!');
      await tester.enterText(textFields.at(2), 'DifferentPass123!');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
