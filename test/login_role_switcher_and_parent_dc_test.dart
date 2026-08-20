import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/pages/login_page.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/users/presentation/pages/user_profile_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_console_layout.dart';

import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';

import 'package:novexps/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

class _MockAuthRemoteDS implements AuthRemoteDataSource {
  final UserModel riderUser = const UserModel(
    id: 'a1111111-1111-4111-8111-111111111111',
    email: 'emeka.rider@novaexpress.ng',
    firstName: 'Emeka',
    lastName: 'Rider',
    phone: '08031234567',
    role: 'delivery_agent',
    deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
    deliveryAgentCode: 'PDA-7000',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    distributionCenterName: 'Wuse Distribution Center',
  );

  final UserModel dcUser = const UserModel(
    id: 'a2222222-2222-4222-8222-222222222222',
    email: 'dc.supervisor@novaexpress.ng',
    firstName: 'Adekunle',
    lastName: 'Supervisor',
    phone: '08091112233',
    role: 'dc_manager',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    distributionCenterName: 'Wuse Distribution Center',
  );

  @override
  Future<UserModel> login(String email, String password) async {
    if (email.contains('dc.')) {
      return dcUser;
    }
    return riderUser;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel> registerDeliveryAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String personnelType,
    required String compensationType,
    required double commissionRate,
    required double transportAllowance,
    required double fuelAllowance,
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    required String assignedZone,
  }) async =>
      riderUser;
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  @override
  Future<List<OrderModel>> getAssignedOrders([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFinanceRemoteDS implements FinanceRemoteDataSource {
  @override
  Future<List<RemittanceModel>> getAgentRemittances([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockRemoteDS implements StockRemoteDataSource {
  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationsRepo implements NotificationsRepository {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationsRemoteDS implements NotificationsRemoteDataSource {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Login Role Switcher & Parent DC Linkage Verification Suite', () {
    List<Override> createOverrides({UserModel? activeUser}) {
      final mockDS = _MockAuthRemoteDS();
      final repo = AuthRepositoryImpl(mockDS);
      return [
        authRemoteDataSourceProvider.overrideWithValue(mockDS),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(
            loginUseCase: LoginUseCase(repo),
            logoutUseCase: LogoutUseCase(repo),
            getCurrentUserUseCase: GetCurrentUserUseCase(repo),
          );
          if (activeUser != null) {
            notifier.state = AuthState(user: activeUser);
          }
          return notifier;
        }),
        ordersRemoteDataSourceProvider.overrideWithValue(_MockOrdersRemoteDS()),
        ordersProvider.overrideWith((ref) {
          final notifier = OrdersNotifier(OrdersRepositoryImpl(_MockOrdersRemoteDS()));
          notifier.state = OrdersState(orders: const [], isLoading: false);
          return notifier;
        }),
        financeRemoteDataSourceProvider.overrideWithValue(_MockFinanceRemoteDS()),
        financeProvider.overrideWith((ref) {
          final notifier = FinanceNotifier(FinanceRepositoryImpl(_MockFinanceRemoteDS()));
          notifier.state = FinanceState(remittances: const []);
          return notifier;
        }),
        stockRemoteDataSourceProvider.overrideWithValue(_MockStockRemoteDS()),
        stockProvider.overrideWith((ref) {
          final notifier = StockNotifier(repository: StockRepositoryImpl(remoteDataSource: _MockStockRemoteDS()));
          notifier.state = const StockState(stockItems: [], isLoading: false);
          return notifier;
        }),
        notificationsRemoteDataSourceProvider.overrideWithValue(_MockNotificationsRemoteDS()),
        notificationsRepositoryProvider.overrideWithValue(_MockNotificationsRepo()),
      ];
    }

    testWidgets('1. LoginPage displays Quick Test Account Selector with Rider and DC cards', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TEST LOGIN SELECTOR'), findsOneWidget);
      expect(find.text('Emeka Rider (PDA-7000)'), findsOneWidget);
      expect(find.text('Parent DC: Wuse Distribution Center (DC-WUSE-01)'), findsOneWidget);
      expect(find.text('Adekunle Supervisor (DC Manager)'), findsOneWidget);
      expect(find.text('Managing DC: Wuse Distribution Center (DC-WUSE-01)'), findsOneWidget);
      expect(find.text('Sign In to PDA App'), findsOneWidget);
    });

    testWidgets('2. Tapping DC Manager card automatically fills DC supervisor credentials and changes button', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the DC Supervisor card
      await tester.tap(find.text('Adekunle Supervisor (DC Manager)'));
      await tester.pumpAndSettle();

      expect(find.text('dc.supervisor@novaexpress.ng'), findsOneWidget);
      expect(find.text('Sign In to DC Console'), findsOneWidget);

      // Tap back to Rider
      await tester.tap(find.text('Emeka Rider (PDA-7000)'));
      await tester.pumpAndSettle();

      expect(find.text('emeka.rider@novaexpress.ng'), findsOneWidget);
      expect(find.text('Sign In to PDA App'), findsOneWidget);
    });

    test('3. Verifies that Wuse Distribution Center is the common parent entity for both PDA and DC', () {
      const rider = UserEntity(
        id: 'a1111111-1111-4111-8111-111111111111',
        email: 'emeka.rider@novaexpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        role: 'delivery_agent',
        deliveryAgentCode: 'PDA-7000',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Distribution Center',
        phone: '08031234567',
      );

      const dcSupervisor = UserEntity(
        id: 'a2222222-2222-4222-8222-222222222222',
        email: 'dc.supervisor@novaexpress.ng',
        firstName: 'Adekunle',
        lastName: 'Supervisor',
        role: 'dc_manager',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Distribution Center',
        phone: '08091112233',
      );

      // Assert common parent DC ID and Name
      expect(rider.distributionCenterId, equals(dcSupervisor.distributionCenterId));
      expect(rider.distributionCenterName, equals('Wuse Distribution Center'));
      expect(dcSupervisor.distributionCenterName, equals('Wuse Distribution Center'));

      // Assert role flags
      expect(rider.isPda, isTrue);
      expect(rider.isDcManager, isFalse);
      expect(dcSupervisor.isDcManager, isTrue);
      expect(dcSupervisor.isPda, isFalse);
    });

    testWidgets('4. Rider UserProfilePage has robust logout dialog and NO direct DC switcher tile', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockDS = _MockAuthRemoteDS();

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(activeUser: mockDS.riderUser),
          child: const MaterialApp(
            home: UserProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that direct DC console switcher tile is REMOVED
      expect(find.text('DC Operations Admin Console'), findsNothing);
      expect(find.text('Switch to Desktop/Tablet Warehouse Console'), findsNothing);

      // Verify Logout Button is present
      expect(find.text('LOGOUT OF TERMINAL'), findsOneWidget);

      // Scroll and tap Logout
      await tester.ensureVisible(find.text('LOGOUT OF TERMINAL'));
      await tester.tap(find.text('LOGOUT OF TERMINAL'));
      await tester.pumpAndSettle();

      // Verify Confirm Logout Dialog appears
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(find.text('Are you sure you want to log out of the NovaExpress Rider Terminal?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Logout'), findsNothing);
    });

    testWidgets('5. DCConsoleLayout has robust supervisor logout dialog and NO direct Rider PDA switcher pill', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockDS = _MockAuthRemoteDS();

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(activeUser: mockDS.dcUser),
          child: const MaterialApp(
            home: DCConsoleLayout(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that direct Rider PDA switcher pill in topbar is REMOVED
      expect(find.text('Rider PDA'), findsNothing);

      // Verify Logout icon button in supervisor sidebar card is present
      final logoutButtons = find.byIcon(Icons.logout_rounded);
      expect(logoutButtons, findsWidgets);

      // Tap logout
      await tester.tap(logoutButtons.first);
      await tester.pumpAndSettle();

      // Verify Confirm DC Logout dialog appears
      expect(find.text('Confirm DC Logout'), findsOneWidget);
      expect(find.text('Are you sure you want to log out of the Distribution Center Management Console?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm DC Logout'), findsNothing);
    });

    testWidgets('6. Sanni Abacha and newly onboarded riders can enter credentials and sign in directly to PDA Terminal', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter Sanni Abacha's created email and password
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, 'sanni.abacha@novaexpress.ng');
      await tester.enterText(textFields.last, 'Password123!');
      await tester.pumpAndSettle();

      // Verify submit button says Sign In to PDA App
      expect(find.text('Sign In to PDA App'), findsOneWidget);

      // Tap Sign In
      await tester.tap(find.text('Sign In to PDA App'));
      await tester.pumpAndSettle();

      // Should complete login without throwing invalid credential error
      expect(find.text('Invalid login credentials'), findsNothing);
    });
  });
}
