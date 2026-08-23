import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/users/presentation/pages/user_profile_page.dart';
import 'package:novexps/features/users/presentation/widgets/change_password_modal.dart';
import 'package:novexps/features/users/presentation/widgets/edit_profile_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRider = UserModel(
    id: 'user-joel-1234',
    email: 'joel.odufu@novaexpress.ng',
    firstName: 'Joel',
    lastName: 'Odufu',
    phone: '08085040146',
    role: 'delivery_agent',
    deliveryAgentId: 'agent-joel-1234',
    deliveryAgentCode: 'PDA-7182',
    distributionCenterName: 'Wuse Distribution Center',
    lifetimeDeliveriesCount: 0,
    rating: 5.0,
    personnelType: 'pda',
    compensationType: 'commission',
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    fuelAllowance: 0.0,
    baseSalary: 0.0,
    vehicleType: 'Motorcycle (Bajaj Boxer)',
    vehiclePlateNumber: 'ABJ-894-XA',
    operatingState: 'Abuja (FCT)',
    operatingCity: 'Wuse II',
    bankName: 'Guaranty Trust Bank (GTBank)',
    bankAccountNumber: '0123456789',
    bankAccountName: 'Joel Odufu',
    agentStatus: 'active',
  );

  testWidgets('UserProfilePage renders real dynamic rider data and categorized sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(testRider)),
          ordersProvider.overrideWith((ref) => MockOrdersNotifier()),
        ],
        child: const MaterialApp(
          home: UserProfilePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Rider Name & Code
    expect(find.text('Joel Odufu'), findsWidgets);
    expect(find.text('PDA-7182'), findsOneWidget);
    expect(find.text('FREELANCE PDA'), findsOneWidget);

    // Verify Real Metrics (0 lifetime drops for new rider)
    expect(find.text('0'), findsOneWidget);
    expect(find.text('LIFETIME DROPS'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('SUCCESS RATE'), findsOneWidget);

    // Verify Classified Sections
    expect(find.text('Personal & Contact Details'), findsOneWidget);
    expect(find.text('08085040146'), findsOneWidget);
    expect(find.text('joel.odufu@novaexpress.ng'), findsOneWidget);
    expect(find.text('Wuse II, Abuja (FCT)'), findsOneWidget);

    expect(find.text('Compensation & Settlement Bank'), findsOneWidget);
    expect(find.text('Guaranty Trust Bank (GTBank)'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);

    expect(find.text('Vehicle & Fleet License'), findsOneWidget);
    expect(find.text('Motorcycle (Bajaj Boxer)'), findsOneWidget);
    expect(find.text('ABJ-894-XA'), findsOneWidget);

    expect(find.text('Security & Authentication'), findsOneWidget);
    expect(find.text('Change Account Password'), findsOneWidget);
  });

  testWidgets('EditProfileModal opens with tabbed interface and populates fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(testRider)),
          ordersProvider.overrideWith((ref) => MockOrdersNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditProfileModal.show(context, testRider),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT RIDER PROFILE'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Settlement Bank'), findsOneWidget);
    expect(find.text('Vehicle & Fleet'), findsOneWidget);
    expect(find.text('SAVE PROFILE CHANGES'), findsOneWidget);
  });

  testWidgets('ChangePasswordModal validates inputs and triggers update', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(testRider)),
          ordersProvider.overrideWith((ref) => MockOrdersNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ChangePasswordModal.show(context),
                child: const Text('Open Security Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Security Modal'));
    await tester.pumpAndSettle();

    expect(find.text('Change Account Password'), findsOneWidget);
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);

    // Try submitting without filling fields
    await tester.tap(find.text('UPDATE PASSWORD'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your current password'), findsOneWidget);
  });
}

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(UserModel user)
      : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required String operatingState,
    required String operatingCity,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    String? avatarUrl,
  }) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return {'success': true, 'message': 'Password changed successfully!'};
  }

  @override
  Future<void> checkCurrentUser() async {}
}

class MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  MockOrdersNotifier() : super(OrdersState(orders: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadOrders([String? agentId]) async {}
}
