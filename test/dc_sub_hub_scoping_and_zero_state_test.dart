import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_console_layout.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_finance_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_transactions_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_riders_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _DummyAuthRemoteDS implements AuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyNotificationsRepo implements NotificationsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyFinanceDS implements FinanceRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyOrdersDS implements OrdersRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyStockDS implements StockRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sub-DC Isolation and Zero-State Verification Suite', () {
    const subDc = DistributionCenter(
      id: 'dc-dc-002',
      name: 'Newi Regional Center',
      code: 'DC-002',
      state: 'Anambra',
      city: 'Nnewi',
      address: '5 Hotel Street, Nnewi',
      isHub: false,
      isGrandDc: false,
      isActive: true,
    );

    const subDcSupervisor = UserEntity(
      id: 'usr-sup-002',
      email: 'supervisor.002@novaexpress.ng',
      firstName: 'Station',
      lastName: 'Supervisor',
      phone: '08000000002',
      role: 'dc_manager',
      distributionCenterId: 'dc-dc-002',
      distributionCenterName: 'Newi Regional Center',
      deliveryAgentCode: 'DC-002',
    );

    test('1. DCConsoleNotifier scopes dcDrivers strictly to active hub (Newi DC starts with 0 riders)', () {
      final notifier = DCConsoleNotifier();
      // Initially Wuse DC drivers exist in default fleet
      expect(notifier.state.drivers.isNotEmpty, isTrue);

      // Switch to Newi Regional Center
      notifier.switchActiveHub(subDc);

      expect(notifier.state.activeHubId, equals('dc-dc-002'));
      expect(notifier.state.activeHubName, equals('Newi Regional Center'));
      expect(notifier.state.isCurrentHubGrandDc, isFalse);

      // Verify that dcDrivers and filteredDrivers are strictly 0 for Newi DC
      expect(notifier.state.dcDrivers.length, equals(0));
      expect(notifier.state.filteredDrivers.length, equals(0));

      // Now onboard a local rider to Newi DC
      notifier.addDriver(
        const DCFleetDriver(
          id: 'rdr-newi-01',
          driverCode: 'RDR-002-1',
          name: 'Chidi Nnewi',
          phone: '08099887766',
          email: 'chidi@novaexpress.com',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775?w=150',
          vehicleModel: 'Bajaj Boxer 150',
          vehiclePlate: 'ANM-002-XX',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: 'Nnewi Central',
          distributionCenterId: 'dc-dc-002',
          totalAssignedOrders: 0,
          completedOrders: 0,
          routeProgressPercent: 0,
          efficiencyRating: 5.0,
          cashInCustody: 0,
          itemsInCustody: 0,
        ),
      );

      // Now Newi DC has exactly 1 driver
      expect(notifier.state.dcDrivers.length, equals(1));
      expect(notifier.state.dcDrivers.first.name, equals('Chidi Nnewi'));
    });

    testWidgets('2. DCFinancePage displays ₦0.00 (not ₦1,500,500.00) when new DC has no remittances', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dcNotifier = DCConsoleNotifier();
      dcNotifier.switchActiveHub(subDc);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => dcNotifier),
            financeProvider.overrideWith((ref) {
              final notifier = FinanceNotifier(FinanceRepositoryImpl(_DummyFinanceDS()));
              notifier.state = FinanceState(remittances: const []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCFinancePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure ₦0.00 is present and ₦1,500,500.00 is NOT present
      expect(find.text('₦0.00'), findsAtLeast(1));
      expect(find.text('₦1,500,500.00'), findsNothing);
      expect(find.text('0 Settlements'), findsOneWidget);
    });

    testWidgets('3. DCTransactionsPage displays ₦0.00 for all 4 KPIs (no hardcoded fallbacks)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dcNotifier = DCConsoleNotifier();
      dcNotifier.switchActiveHub(subDc);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => dcNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCTransactionsPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // None of the old hardcoded numbers should be rendered
      expect(find.text('₦1,250,000.00'), findsNothing);
      expect(find.text('₦840,000.00'), findsNothing);
      expect(find.text('₦410,000.00'), findsNothing);
      expect(find.text('₦320,000.00'), findsNothing);

      // Verify ₦0.00 is rendered across the empty volume tiles
      expect(find.text('₦0.00'), findsAtLeast(1));
      expect(find.text('0 Recorded Transactions'), findsOneWidget);
    });

    testWidgets('4. DCRidersPage displays 0 Agents for new DC and shows clean empty roster message', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dcNotifier = DCConsoleNotifier();
      dcNotifier.switchActiveHub(subDc);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => dcNotifier),
            ordersProvider.overrideWith((ref) {
              final notifier = OrdersNotifier(OrdersRepositoryImpl(_DummyOrdersDS()));
              notifier.state = OrdersState(orders: const [], isLoading: false);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DCRidersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Summary tiles show 0
      expect(find.text('0 Agents'), findsOneWidget);
      expect(find.text('0 Riders'), findsOneWidget);
      expect(find.text('0 on Duty'), findsOneWidget);
      expect(find.text('All Agents (0)'), findsOneWidget);

      // Empty roster notice
      expect(find.text('No delivery personnel onboarded to this distribution center yet.'), findsOneWidget);
    });

    testWidgets('5. DCConsoleLayout top header locks to current DC (no dropdown switcher) and hides Distribution Centers tab for sub-DC', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dcNotifier = DCConsoleNotifier();
      dcNotifier.switchActiveHub(subDc);

      final dummyAuthRepo = AuthRepositoryImpl(_DummyAuthRemoteDS());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => dcNotifier),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                loginUseCase: LoginUseCase(dummyAuthRepo),
                logoutUseCase: LogoutUseCase(dummyAuthRepo),
                getCurrentUserUseCase: GetCurrentUserUseCase(dummyAuthRepo),
              );
              notifier.state = const AuthState(
                user: subDcSupervisor,
              );
              return notifier;
            }),
            notificationsProvider.overrideWith((ref) {
              final notifier = NotificationsNotifier(
                repository: _DummyNotificationsRepo(),
                ref: ref,
              );
              notifier.state = const NotificationsState(notifications: []);
              return notifier;
            }),
            stockProvider.overrideWith((ref) {
              final notifier = StockNotifier(repository: StockRepositoryImpl(remoteDataSource: _DummyStockDS()));
              notifier.state = const StockState(stockItems: [], isLoading: false);
              return notifier;
            }),
            ordersProvider.overrideWith((ref) {
              final notifier = OrdersNotifier(OrdersRepositoryImpl(_DummyOrdersDS()));
              notifier.state = OrdersState(orders: const [], isLoading: false);
              return notifier;
            }),
            financeProvider.overrideWith((ref) {
              final notifier = FinanceNotifier(FinanceRepositoryImpl(_DummyFinanceDS()));
              notifier.state = FinanceState(remittances: const [], transactions: const []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: DCConsoleLayout(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar displays current DC name and code
      expect(find.text('Newi Regional Center'), findsAtLeast(1));
      expect(find.text('(DC-002)'), findsAtLeast(1));

      // No distribution center popup switcher in top bar
      expect(find.byType(PopupMenuButton<DistributionCenter>), findsNothing);

      // Sidebar items check: 'Distribution Centers' nav item must NOT exist for non-primary sub-DC
      expect(find.text('Distribution Centers'), findsNothing);

      // Other standard tabs should be present
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Deliveries & Orders'), findsOneWidget);
      expect(find.text('Cash & Remittances'), findsOneWidget);
      expect(find.text('Transactions & Ledger'), findsOneWidget);
      expect(find.text('Riders & Fleet'), findsOneWidget);
      expect(find.text('Clients & Merchants'), findsOneWidget);
    });
  });
}
