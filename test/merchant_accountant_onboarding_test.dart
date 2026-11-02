import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/client_portal/domain/entities/client_accountant.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_accountant_credentials_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_onboard_accountant_modal.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_accountants_page.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockAccountant = ClientAccountant(
    id: 'acc-uuid-1',
    clientId: 'client-123',
    userId: 'user-acc-1',
    accountantCode: 'ACC-NOVA-101',
    fullName: 'Fatima Aliyu',
    email: 'fatima.accountant@brand.ng',
    phone: '08099887766',
    isActive: true,
    canApproveSettlements: true,
    canManageExpenses: true,
    canDisbursePayouts: true,
    totalSettlementsValidated: 14,
    totalAmountValidated: 2850000.0,
    createdAt: DateTime(2026, 10, 15),
  );

  final mockInactiveAccountant = ClientAccountant(
    id: 'acc-uuid-2',
    clientId: 'client-123',
    accountantCode: 'ACC-NOVA-102',
    fullName: 'Musa Bello',
    email: 'musa.bello@brand.ng',
    phone: '08011223344',
    isActive: false,
    canApproveSettlements: false,
    canManageExpenses: true,
    canDisbursePayouts: false,
    totalSettlementsValidated: 2,
    totalAmountValidated: 120000.0,
  );

  group('Merchant Accountant Entity & User Role Tests', () {
    test('ClientAccountant json serialization and deserialization preserves all attributes', () {
      final json = mockAccountant.toJson();
      expect(json['id'], 'acc-uuid-1');
      expect(json['accountant_code'], 'ACC-NOVA-101');
      expect(json['full_name'], 'Fatima Aliyu');
      expect(json['can_approve_settlements'], true);
      expect(json['total_settlements_validated'], 14);

      final fromJson = ClientAccountant.fromJson(json);
      expect(fromJson.id, mockAccountant.id);
      expect(fromJson.accountantCode, mockAccountant.accountantCode);
      expect(fromJson.fullName, mockAccountant.fullName);
      expect(fromJson.email, mockAccountant.email);
      expect(fromJson.canApproveSettlements, true);
      expect(fromJson.canManageExpenses, true);
      expect(fromJson.canDisbursePayouts, true);
      expect(fromJson.totalSettlementsValidated, 14);
      expect(fromJson.totalAmountValidated, 2850000.0);
    });

    test('UserEntity and UserModel correctly identify merchant_accountant role and home console route', () {
      const userEntity = UserEntity(
        id: 'u-acc-1',
        email: 'fatima@brand.ng',
        firstName: 'Fatima',
        lastName: 'Aliyu',
        phone: '08099887766',
        role: 'merchant_accountant',
        clientId: 'client-123',
        accountantId: 'acc-uuid-1',
        accountantCode: 'ACC-NOVA-101',
      );

      expect(userEntity.isMerchantAccountant, isTrue);
      expect(userEntity.isClient, isTrue);
      expect(userEntity.isRider, isFalse);
      expect(userEntity.homeConsoleRoute, '/merchant-settlements');
      expect(userEntity.roleDescription, 'Merchant Finance Accountant');

      final userModel = UserModel.fromJson({
        'id': 'u-acc-1',
        'email': 'fatima@brand.ng',
        'first_name': 'Fatima',
        'last_name': 'Aliyu',
        'phone': '08099887766',
        'role': 'merchant_accountant',
        'client_id': 'client-123',
        'accountant_code': 'ACC-NOVA-101',
      });

      expect(userModel.isMerchantAccountant, isTrue);
      expect(userModel.isRider, isFalse);
      expect(userModel.accountantCode, 'ACC-NOVA-101');
      expect(userModel.homeConsoleRoute, '/merchant-settlements');
    });

    test('MockAuthRemoteDataSource logs in merchant accountant by email and code to /merchant-settlements', () async {
      final mockAuth = MockAuthRemoteDataSource();
      final user = await mockAuth.login('accountant@novacare.com', 'Password123!');
      expect(user.isMerchantAccountant, isTrue);
      expect(user.isRider, isFalse);
      expect(user.role, 'merchant_accountant');
      expect(user.accountantCode, 'ACC-NOVA-001');
      expect(user.homeConsoleRoute, '/merchant-settlements');

      // Test login with staff code
      final userByCode = await mockAuth.login('ACC-NOVA-001', 'Password123!');
      expect(userByCode.isMerchantAccountant, isTrue);
      expect(userByCode.isRider, isFalse);
      expect(userByCode.homeConsoleRoute, '/merchant-settlements');
    });

    test('ClientPortalState computes correct KPIs and search filtering for accountants', () {
      final state = ClientPortalState(
        clientProfile: const ClientProfile(
          id: 'client-123',
          companyName: 'Nova Merchant Ltd',
          contactPerson: 'Admin User',
          email: 'admin@novamerchant.com',
          phone: '08000000000',
          address: 'Plot 402 Aminu Kano Cres',
        ),
        accountants: [mockAccountant, mockInactiveAccountant],
      );

      expect(state.totalAccountantsCount, 2);
      expect(state.activeAccountantsCount, 1);
      expect(state.inactiveAccountantsCount, 1);
      expect(state.totalSettlementsValidatedByAccountants, 16);
      expect(state.totalSettlementAmountValidated, 2970000.0);

      // Search filtering by name
      final stateWithSearch = state.copyWith(searchQuery: 'Fatima');
      expect(stateWithSearch.filteredAccountants.length, 1);
      expect(stateWithSearch.filteredAccountants.first.fullName, 'Fatima Aliyu');

      // Search filtering by code
      final stateWithCodeSearch = state.copyWith(searchQuery: 'ACC-NOVA-102');
      expect(stateWithCodeSearch.filteredAccountants.length, 1);
      expect(stateWithCodeSearch.filteredAccountants.first.accountantCode, 'ACC-NOVA-102');
    });
  });

  group('Merchant Accountant Credentials Modal Tests', () {
    testWidgets('ClientAccountantCredentialsModal displays credentials, app link and copy button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ClientAccountantCredentialsModal(
                accountant: mockAccountant,
                initialPassword: 'TempPassword456!',
                clientName: 'Nova Brand Ltd',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accountant Ready'), findsOneWidget);
      expect(find.text('Fatima Aliyu'), findsOneWidget);
      expect(find.text('ACC-NOVA-101'), findsOneWidget);
      expect(find.text('fatima.accountant@brand.ng'), findsOneWidget);
      expect(find.text('TempPassword456!'), findsOneWidget);
      expect(find.text('Settlement Sign-off'), findsOneWidget);
      expect(find.text('Manage Expenses'), findsOneWidget);
      expect(find.text('Disburse Payouts'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });
  });

  group('Merchant Accountants Page & Subnav Tests', () {
    testWidgets('ClientAccountantsPage displays header, KPI cards and accountant manifest table', (tester) async {
      final container = ProviderContainer(
        overrides: [
          clientPortalProvider.overrideWith((ref) => MockClientPortalNotifier(ref, [mockAccountant, mockInactiveAccountant])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ClientAccountantsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accountants'), findsWidgets);
      expect(find.text('1 Active'), findsOneWidget);
      expect(find.text('Fatima Aliyu'), findsOneWidget);
      expect(find.text('ACC-NOVA-101'), findsOneWidget);
      expect(find.text('Musa Bello'), findsOneWidget);
      expect(find.text('ACC-NOVA-102'), findsOneWidget);
      expect(find.text('Onboard'), findsOneWidget);
    });

    testWidgets('ClientOnboardAccountantModal renders all inputs and validates required fields', (tester) async {
      final container = ProviderContainer(
        overrides: [
          clientPortalProvider.overrideWith((ref) => MockClientPortalNotifier(ref, [mockAccountant])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ClientOnboardAccountantModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboard Accountant'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Official Email'), findsOneWidget);
      expect(find.text('Phone (WhatsApp)'), findsOneWidget);
      expect(find.text('Finance Permissions'), findsOneWidget);
      expect(find.text('Settlement Sign-off'), findsOneWidget);

      // Tap Onboard with empty fields to trigger validation
      final onboardBtn = find.widgetWithText(ElevatedButton, 'Onboard');
      await tester.ensureVisible(onboardBtn);
      await tester.tap(onboardBtn);
      await tester.pumpAndSettle();

      expect(find.text('First name required'), findsOneWidget);
      expect(find.text('Last name required'), findsOneWidget);
      expect(find.text('Email required'), findsOneWidget);
    });

    testWidgets('ClientPortalLayout displays Accountants in Finance subnav and loads page', (tester) async {
      final container = ProviderContainer(
        overrides: [
          clientPortalProvider.overrideWith((ref) => MockClientPortalNotifier(ref, [mockAccountant])),
          clientActiveTabProvider.overrideWith((ref) => 'finance_accountants'),
          notificationsProvider.overrideWith((ref) => MockTestNotificationsNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ClientPortalLayout(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accountants'), findsWidgets);
      expect(find.text('Fatima Aliyu'), findsOneWidget);
    });
  });
}

class MockClientPortalNotifier extends ClientPortalNotifier {
  final List<ClientAccountant> initialAccountants;

  MockClientPortalNotifier(super.ref, this.initialAccountants) {
    state = ClientPortalState(
      clientProfile: const ClientProfile(
        id: 'client-123',
        companyName: 'Nova Merchant Ltd',
        contactPerson: 'Admin User',
        email: 'admin@novamerchant.com',
        phone: '08000000000',
        address: 'Plot 402 Aminu Kano Cres',
      ),
      accountants: initialAccountants,
    );
  }

  @override
  Future<void> loadClientData({bool silent = false}) async {}

  @override
  Future<ClientAccountant> createAccountant({
    required String fullName,
    required String email,
    required String phone,
    String? password,
    String? accountantCode,
    bool canApproveSettlements = true,
    bool canManageExpenses = true,
    bool canDisbursePayouts = true,
    String? avatarUrl,
  }) async {
    final newAcc = ClientAccountant(
      id: 'acc-${DateTime.now().millisecondsSinceEpoch}',
      clientId: state.clientProfile.id,
      accountantCode: accountantCode ?? 'ACC-NOVA-103',
      fullName: fullName,
      email: email,
      phone: phone,
      canApproveSettlements: canApproveSettlements,
      canManageExpenses: canManageExpenses,
      canDisbursePayouts: canDisbursePayouts,
    );
    state = state.copyWith(accountants: [newAcc, ...state.accountants]);
    return newAcc;
  }
}

class MockTestNotificationsNotifier extends StateNotifier<NotificationsState>
    implements NotificationsNotifier {
  MockTestNotificationsNotifier()
      : super(const NotificationsState(notifications: []));

  @override
  Future<void> emitNotification({
    required String title,
    required String message,
    required String category,
    String? actionRoute,
  }) async {}

  @override
  Future<void> fetchNotifications([String? agentId]) async {}

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  void setFilter(String filter) {}
}
