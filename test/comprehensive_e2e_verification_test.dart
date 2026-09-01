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
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';

import 'package:novexps/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

// UI Pages
import 'package:novexps/features/dashboard/presentation/pages/pda_home_page.dart';
import 'package:novexps/features/orders/presentation/pages/orders_list_page.dart';
import 'package:novexps/features/orders/presentation/pages/order_detail_page.dart';
import 'package:novexps/features/finance/presentation/pages/cash_page.dart';
import 'package:novexps/features/finance/presentation/pages/log_remittance_page.dart';
import 'package:novexps/features/finance/presentation/pages/payouts_page.dart';
import 'package:novexps/features/finance/presentation/pages/transaction_history_page.dart';
import 'package:novexps/features/stock/presentation/pages/stock_page.dart';
import 'package:novexps/features/stock/presentation/pages/stock_details_grazer_page.dart';
import 'package:novexps/features/notifications/presentation/pages/notifications_page.dart';
import 'package:novexps/features/users/presentation/pages/user_profile_page.dart';

// Mocks for UI testing
class MockNotificationsRepo implements NotificationsRepository {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [
        AppNotificationEntity(
          id: 'notif-e2e-01',
          title: 'New Delivery Assigned 📦',
          message: 'Order TRK-8924 assigned to your route.',
          category: NotificationCategory.delivery,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationsRemoteDS implements NotificationsRemoteDataSource {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthRemoteDS implements AuthRemoteDataSource {
  static const testUser = UserModel(
    id: 'd3a629c4-33dc-414b-b037-5abd074367ee',
    email: 'rider.emeka@novaexpress.com',
    firstName: 'Emeka',
    lastName: 'Rider',
    phone: '08031234567',
    role: 'delivery_agent',
    deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
    deliveryAgentCode: 'PDA-7000',
    distributionCenterName: 'Wuse Distribution Center',
    lifetimeDeliveriesCount: 4892,
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

  @override
  Future<UserModel> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  }) async =>
      testUser;
}

class MockOrdersRemoteDS implements OrdersRemoteDataSource {
  final List<OrderModel> orders;
  MockOrdersRemoteDS(this.orders);

  @override
  Future<List<OrderModel>> getAssignedOrders([String? agentId]) async => orders;

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    return orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => orders.first,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFinanceRemoteDS implements FinanceRemoteDataSource {
  final List<RemittanceModel> remittances;
  MockFinanceRemoteDS(this.remittances);

  @override
  Future<List<RemittanceModel>> getAgentRemittances([String? agentId]) async => remittances;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStockRemoteDS implements StockRemoteDataSource {
  final List<StockItemModel> stock;
  MockStockRemoteDS(this.stock);

  @override
  Future<List<StockItemModel>> getVehicleStockItems([String? agentId]) async => stock;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('PDA Comprehensive Riverpod & UI Widget Verification Suite', () {
    final now = DateTime.now();
    final testUserEntity = UserEntity(
      id: 'd3a629c4-33dc-414b-b037-5abd074367ee',
      email: 'rider.emeka@novaexpress.com',
      firstName: 'Emeka',
      lastName: 'Rider',
      phone: '08031234567',
      role: 'delivery_agent',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentCode: 'PDA-7000',
      distributionCenterName: 'Wuse Distribution Center',
      lifetimeDeliveriesCount: 4892,
    );

    final testOrders = [
      OrderEntity(
        id: '20202020-2020-4020-8020-202020202020',
        orderNumber: 'TRK-8924',
        customerName: 'Chief Aliyu Mohammed',
        customerPhone: '08031234567',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Plot 402 Aminu Kano Crescent',
        productName: 'Respira Detox Tea',
        status: 'in_transit',
        quantity: 2,
        basePrice: 20000.0,
        upsellAmount: 5000.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: now,
      ),
      OrderEntity(
        id: '20202020-2020-4020-8020-303030303030',
        orderNumber: 'TRK-8925',
        customerName: 'Dr. Aisha Garba',
        customerPhone: '08098765432',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Maitama',
        deliveryAddress: '14 Gana Street, Maitama',
        productName: 'Grazer Herbal Tea',
        status: 'delivered',
        quantity: 3,
        basePrice: 15000.0,
        upsellAmount: 0.0,
        totalAmount: 45000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        createdAt: now,
      ),
    ];

    final testRemittances = [
      RemittanceEntity(
        id: '40404040-4040-4040-8040-404040404040',
        referenceNumber: 'REM-004',
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
        amount: 15000.0,
        grossCollections: 30000.0,
        commissionDeducted: 6000.0,
        transportAllowanceDeducted: 9000.0,
        paymentMethod: 'bank_transfer',
        status: 'verified',
        verifiedByName: 'Wuse DC Finance Desk',
        notes: 'Bank transfer verified and reconciled.',
        createdAt: now,
      ),
    ];

    final testStock = [
      const StockItemEntity(
        id: 'd1111111-1111-4111-8111-111111111111',
        sku: 'SKU-RSP01',
        name: 'Respira Detox Tea',
        description: 'Herbal Detox Tea',
        price: 26000.0,
        totalInCustody: 14,
        assignedCount: 2,
        deliveredCount: 1,
        availableCount: 14,
        returnedCount: 0,
        category: 'Wellness',
      ),
      const StockItemEntity(
        id: 'd2222222-2222-4222-8222-222222222222',
        sku: 'SKU-GRZ02',
        name: 'Grazer Herbal Tea',
        description: 'Herbal Tea Formula',
        price: 15000.0,
        totalInCustody: 8,
        assignedCount: 3,
        deliveredCount: 3,
        availableCount: 8,
        returnedCount: 0,
        category: 'Weight Management',
      ),
    ];

    List<Override> createOverrides() {
      final orderModels = testOrders
          .map((o) => OrderModel(
                id: o.id,
                orderNumber: o.orderNumber,
                customerName: o.customerName,
                customerPhone: o.customerPhone,
                deliveryAddress: o.deliveryAddress,
                deliveryCity: o.deliveryCity,
                deliveryState: o.deliveryState,
                productName: o.productName,
                status: o.status,
                quantity: o.quantity,
                basePrice: o.basePrice,
                upsellAmount: o.upsellAmount,
                totalAmount: o.totalAmount,
                paymentType: o.paymentType,
                paymentStatus: o.paymentStatus,
                createdAt: o.createdAt,
              ))
          .toList();

      final remittanceModels = testRemittances
          .map((r) => RemittanceModel(
                id: r.id,
                referenceNumber: r.referenceNumber,
                companyId: r.companyId,
                deliveryAgentId: r.deliveryAgentId,
                amount: r.amount,
                grossCollections: r.grossCollections,
                commissionDeducted: r.commissionDeducted,
                transportAllowanceDeducted: r.transportAllowanceDeducted,
                paymentMethod: r.paymentMethod,
                status: r.status,
                verifiedByName: r.verifiedByName,
                notes: r.notes,
                createdAt: r.createdAt,
              ))
          .toList();

      final stockModels = testStock
          .map((s) => StockItemModel(
                id: s.id,
                sku: s.sku,
                name: s.name,
                description: s.description,
                price: s.price,
                totalInCustody: s.totalInCustody,
                assignedCount: s.assignedCount,
                deliveredCount: s.deliveredCount,
                availableCount: s.availableCount,
                returnedCount: s.returnedCount,
                category: s.category,
              ))
          .toList();

      return [
        authRemoteDataSourceProvider.overrideWithValue(MockAuthRemoteDS()),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(
            loginUseCase: LoginUseCase(AuthRepositoryImpl(MockAuthRemoteDS())),
            logoutUseCase: LogoutUseCase(AuthRepositoryImpl(MockAuthRemoteDS())),
            getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(MockAuthRemoteDS())),
          );
          notifier.state = AuthState(user: testUserEntity);
          return notifier;
        }),
        ordersRemoteDataSourceProvider.overrideWithValue(MockOrdersRemoteDS(orderModels)),
        ordersProvider.overrideWith((ref) {
          final notifier = OrdersNotifier(
            OrdersRepositoryImpl(MockOrdersRemoteDS(orderModels)),
          );
          notifier.state = OrdersState(orders: testOrders, isLoading: false);
          return notifier;
        }),
        financeRemoteDataSourceProvider.overrideWithValue(MockFinanceRemoteDS(remittanceModels)),
        financeProvider.overrideWith((ref) {
          final notifier = FinanceNotifier(
            FinanceRepositoryImpl(MockFinanceRemoteDS(remittanceModels)),
          );
          notifier.state = FinanceState(
            remittances: testRemittances,
            cashInCustody: 25000.0,
            totalEarnedBalance: 18500.0,
          );
          return notifier;
        }),
        stockRemoteDataSourceProvider.overrideWithValue(MockStockRemoteDS(stockModels)),
        stockProvider.overrideWith((ref) {
          final notifier = StockNotifier(
            repository: StockRepositoryImpl(remoteDataSource: MockStockRemoteDS(stockModels)),
          );
          notifier.state = StockState(
            stockItems: testStock,
            isLoading: false,
          );
          return notifier;
        }),
        notificationsRemoteDataSourceProvider.overrideWithValue(MockNotificationsRemoteDS()),
        notificationsRepositoryProvider.overrideWithValue(MockNotificationsRepo()),
      ];
    }

    testWidgets('1. UI: Home Dashboard renders correctly with live metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: PdaHomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PdaHomePage), findsOneWidget);
      expect(find.textContaining('Emeka'), findsWidgets);
    });

    testWidgets('2. UI: Deliveries Page & Order Details Page render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: OrdersListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(OrdersListPage), findsOneWidget);
      expect(find.text('Chief Aliyu Mohammed'), findsOneWidget);

      // Test OrderDetailPage
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            home: OrderDetailPage(orderId: testOrders.first.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailPage), findsOneWidget);
    });

    testWidgets('3. UI: Cash Remittance & Payouts Page render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: CashPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CashPage), findsOneWidget);

      // Payouts Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: PayoutsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PayoutsPage), findsOneWidget);

      // Transaction History Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: TransactionHistoryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(TransactionHistoryPage), findsOneWidget);

      // Log Remittance Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: LogRemittancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(LogRemittancePage), findsOneWidget);
    });

    testWidgets('4. UI: Stock Inventory & Grazer Details Page render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: StockPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(StockPage), findsOneWidget);

      // Stock Details Grazer Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: StockDetailsGrazerPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(StockDetailsGrazerPage), findsOneWidget);
    });

    testWidgets('5. UI: Notifications Center & Profile Page render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      // User Profile Page
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: const MaterialApp(
            home: UserProfilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(find.textContaining('Emeka Rider'), findsWidgets);
    });
  });
}
