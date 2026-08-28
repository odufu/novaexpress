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
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

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

import 'package:novexps/features/dc_console/presentation/pages/dc_console_layout.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_dashboard_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_orders_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_stock_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_returns_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_payouts_page.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_riders_page.dart';

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

class _MockAuthRemoteDS implements AuthRemoteDataSource {
  static const testUser = UserModel(
    id: 'admin-001',
    email: 'dc.supervisor@novaexpress.ng',
    firstName: 'Adekunle',
    lastName: 'Supervisor',
    phone: '08099887766',
    role: 'dc_manager',
    distributionCenterName: 'Wuse Distribution Center',
  );

  @override
  Future<UserModel> login(String email, String password) async => testUser;
  @override
  Future<void> logout() async {}
  @override
  Future<UserModel?> getCurrentUser() async => testUser;
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
      testUser;
}

class _MockOrdersRemoteDS implements OrdersRemoteDataSource {
  @override
  Future<List<OrderModel>> getAssignedOrders([String? agentId]) async => [];

  @override
  Future<List<OrderModel>> getDistributionCenterOrders([String? distributionCenterId]) async => [
        OrderModel(
          id: 'ord-8930',
          orderNumber: 'TRK-8930',
          customerName: 'Senator Kashim Shettima',
          customerPhone: '08091112233',
          deliveryState: 'Abuja (FCT)',
          deliveryCity: 'Abuja',
          deliveryAddress: 'Plot 104 Shehu Shagari Way, Maitama, Abuja',
          productName: '2x Respira Detox Tea',
          status: 'pending',
          quantity: 2,
          basePrice: 25000.0,
          upsellAmount: 0.0,
          totalAmount: 50000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          distributionCenterId: '22222222-2222-4222-8222-222222222222',
          createdAt: DateTime.now(),
        ),
      ];

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {}

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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Distribution Center (DC) Console UI & Business Operations Verification Suite', () {
    const mockUser = UserEntity(
      id: 'admin-001',
      email: 'dc.supervisor@novaexpress.ng',
      firstName: 'Adekunle',
      lastName: 'Supervisor',
      role: 'dc_manager',
      phone: '08099887766',
    );

    List<Override> createOverrides() {
      return [
        authRemoteDataSourceProvider.overrideWithValue(_MockAuthRemoteDS()),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(
            loginUseCase: LoginUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
            logoutUseCase: LogoutUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
            getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(_MockAuthRemoteDS())),
          );
          notifier.state = const AuthState(user: mockUser);
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
        dcConsoleProvider.overrideWith((ref) {
          final notifier = DCConsoleNotifier();
          notifier.state = notifier.state.copyWith(
            drivers: const [
              DCFleetDriver(
                id: 'drv-001',
                driverCode: 'RDR-103',
                name: 'Jameson Miller',
                phone: '08023456789',
                avatarUrl: '',
                vehicleModel: 'Isuzu NPR',
                vehiclePlate: '12-XZ-01',
                vehicleType: 'Van',
                status: 'active',
                assignedZone: 'Wuse II & Zone 4',
                totalAssignedOrders: 18,
                completedOrders: 13,
                routeProgressPercent: 72.0,
                efficiencyRating: 98.4,
                cashInCustody: 145000.0,
                itemsInCustody: 12,
                personnelType: 'in_house_rider',
                compensationType: 'hybrid',
              ),
              DCFleetDriver(
                id: 'b1111111-1111-4111-8111-111111111111',
                driverCode: 'PDA-7000',
                name: 'Emeka Rider',
                phone: '08012345678',
                avatarUrl: '',
                vehicleModel: 'Bajaj Boxer',
                vehiclePlate: 'ABJ-204-XY',
                vehicleType: 'Motorcycle',
                status: 'active',
                assignedZone: 'Wuse II & Abuja Central',
                totalAssignedOrders: 53,
                completedOrders: 51,
                routeProgressPercent: 96.0,
                efficiencyRating: 99.2,
                cashInCustody: 953000.0,
                itemsInCustody: 22,
                personnelType: 'pda',
                compensationType: 'commission',
              ),
            ],
          );
          return notifier;
        }),
      ];
    }

    testWidgets('1. DC Console Layout renders responsive collapsible sidebar and 8 business tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: DCConsoleLayout(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCConsoleLayout), findsOneWidget);
      expect(find.text('NovaExpress DC'), findsOneWidget);
      expect(find.text('Hub Operations Command'), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Deliveries & Orders'), findsOneWidget);
      expect(find.text('Inventory & Stock'), findsOneWidget);
      expect(find.text('Cash & Remittances'), findsOneWidget);
      expect(find.text('Transactions & Ledger'), findsOneWidget);
      expect(find.text('Returns & QC Desk'), findsOneWidget);
      expect(find.text('Rider Payouts'), findsOneWidget);
      expect(find.text('Riders & Fleet'), findsOneWidget);
    });

    testWidgets('2. DCDashboardPage renders live hub KPIs, GPS city map, and driver manifest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCDashboardPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCDashboardPage), findsOneWidget);
      expect(find.text('Wuse Distribution Center'), findsOneWidget);
      expect(find.text('DC-WUSE-01'), findsOneWidget);
      expect(find.text('Restock Picking Queue'), findsOneWidget);
      expect(find.text('In-Transit Orders'), findsOneWidget);
      expect(find.text('Cash in Fleet Custody'), findsOneWidget);
      expect(find.text('Returns Awaiting QC'), findsOneWidget);
      expect(find.text('Delivery Personnel Manifest'), findsOneWidget);
      expect(find.text('Jameson Miller'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsOneWidget);
    });

    testWidgets('3. DCOrdersPage renders unassigned orders pool and in-transit routes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCOrdersPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCOrdersPage), findsOneWidget);
      expect(find.textContaining('All Orders'), findsWidgets);
      expect(find.textContaining('Unassigned Pool'), findsWidgets);
      expect(find.textContaining('In-Transit Routes'), findsWidgets);
      expect(find.textContaining('Delivered / POD'), findsWidgets);
      expect(find.textContaining('Failed / Rescheduled'), findsWidgets);
      expect(find.text('Master Orders Directory'), findsOneWidget);

      // Navigate to Unassigned Pool tab
      await tester.tap(find.textContaining('Unassigned Pool').first);
      await tester.pumpAndSettle();
      expect(find.text('Unassigned Orders Pool'), findsOneWidget);
      expect(find.text('TRK-8930 • Senator Kashim Shettima (08091112233)'), findsOneWidget);
    });

    testWidgets('4. DCStockPage renders all 4 warehouse inventory sub-tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCStockPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DCStockPage), findsOneWidget);
      expect(find.textContaining('Master Products & Inventory'), findsOneWidget);
      expect(find.textContaining('DC Warehouse Stock Batches'), findsOneWidget);
      expect(find.text('Bulk Stock Intake (Waybill)'), findsOneWidget);
      expect(find.textContaining('Rider Picking Queue'), findsOneWidget);
      expect(find.text('Dispatch Handover Counter'), findsOneWidget);
    });

    testWidgets('5. DCReturnsPage, DCPayoutsPage, DCRidersPage render cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      // Returns Desk
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCReturnsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DCReturnsPage), findsOneWidget);
      expect(find.text('Customer Returns & QC Grading Desk'), findsOneWidget);

      // Payouts Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCPayoutsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DCPayoutsPage), findsOneWidget);
      expect(find.text('Rider Payout Claims & Earnings Approvals'), findsOneWidget);

      // Riders Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: Scaffold(body: DCRidersPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DCRidersPage), findsOneWidget);
      expect(find.text('Riders & Delivery Fleet Control'), findsOneWidget);
    });
  });
}
