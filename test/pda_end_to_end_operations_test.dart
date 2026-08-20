import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dashboard/presentation/pages/pda_home_page.dart';
import 'package:novexps/features/finance/data/datasources/finance_remote_datasource.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/data/repositories/finance_repository_impl.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/presentation/pages/cash_page.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/pages/notifications_page.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/pages/orders_list_page.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<AppNotificationEntity> list = [
    AppNotificationEntity(
      id: 'notif-001',
      title: 'New Delivery Assigned 📦',
      message: 'Order TRK-8925 (Dr. Aisha Garba) in Maitama has been assigned to your queue.',
      category: NotificationCategory.delivery,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      isRead: false,
      actionRoute: '/orders',
    ),
    AppNotificationEntity(
      id: 'notif-002',
      title: 'Remittance Approved ✓',
      message: 'Your cash remittance of ₦42,500 (REM-00481) has been verified and reconciled by Wuse DC Finance desk.',
      category: NotificationCategory.finance,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      actionRoute: '/cash/history',
    ),
  ];

  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => list;

  @override
  Future<void> emitNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  }) async {}

  @override
  Future<void> markAsRead(String notificationId) async {
    list = list.map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n).toList();
  }

  @override
  Future<void> markAllAsRead() async {
    list = list.map((n) => n.copyWith(isRead: true)).toList();
  }
}

class MockNotificationsRemoteDataSource implements NotificationsRemoteDataSource {
  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async => [];
  @override
  Future<void> createNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  }) async {}
  @override
  Future<void> markAsRead(String notificationId) async {}
  @override
  Future<void> markAllAsRead() async {}
}

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  static const testUserModel = UserModel(
    id: 'a1111111-1111-4111-8111-111111111111',
    email: 'emeka.rider@novaexpress.ng',
    firstName: 'Emeka',
    lastName: 'Rider',
    phone: '08031234567',
    role: 'delivery_agent',
    deliveryAgentCode: 'PDA-7000',
    distributionCenterName: 'Wuse DC',
    personnelType: 'pda',
    compensationType: 'commission',
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    lifetimeDeliveriesCount: 4892,
  );

  @override
  Future<UserModel> login(String email, String password) async => testUserModel;
  @override
  Future<void> logout() async {}
  @override
  Future<UserModel?> getCurrentUser() async => testUserModel;
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
      testUserModel;
}

class MockOrdersRemoteDataSource implements OrdersRemoteDataSource {
  final List<OrderModel> orders;
  MockOrdersRemoteDataSource(this.orders);

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async => orders;
  @override
  Future<OrderModel> getOrderById(String orderId) async => orders.first;
  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes}) async {}
  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
  }) async => {'success': true};
  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  }) async => {'success': true};
}

class MockFinanceRemoteDataSource implements FinanceRemoteDataSource {
  final List<RemittanceModel> remittances;
  MockFinanceRemoteDataSource(this.remittances);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStockRemoteDataSource implements StockRemoteDataSource {
  final List<StockItemModel> stockItems;
  MockStockRemoteDataSource(this.stockItems);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDA End-to-End Operational Workflow Tests', () {
    late UserEntity testPdaUser;
    late List<OrderEntity> testOrders;
    late List<RemittanceEntity> testRemittances;
    late List<StockItemEntity> testStock;

    setUp(() {
      final now = DateTime.now();

      testPdaUser = const UserEntity(
        id: 'a1111111-1111-4111-8111-111111111111',
        email: 'emeka.rider@novaexpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08031234567',
        role: 'delivery_agent',
        deliveryAgentCode: 'PDA-7000',
        distributionCenterName: 'Wuse DC',
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
        lifetimeDeliveriesCount: 4892,
      );

      testOrders = [
        OrderEntity(
          id: 'ord-001',
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
          id: 'ord-002',
          orderNumber: 'TRK-8925',
          customerName: 'Dr. Aisha Garba',
          customerPhone: '08098765432',
          deliveryState: 'Abuja (FCT)',
          deliveryCity: 'Maitama',
          deliveryAddress: '14 Gana Street, Maitama',
          productName: 'Grazer Weight Loss Formula',
          status: 'delivered',
          quantity: 3,
          basePrice: 15000.0,
          upsellAmount: 0.0,
          totalAmount: 45000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-003',
          orderNumber: 'TRK-8926',
          customerName: 'Engr. Femi Babalola',
          customerPhone: '08077665544',
          deliveryState: 'Abuja (FCT)',
          deliveryCity: 'Garki',
          deliveryAddress: '22 Area 11, Garki',
          productName: 'Respira Detox Tea',
          status: 'delivered',
          quantity: 1,
          basePrice: 15000.0,
          upsellAmount: 0.0,
          totalAmount: 15000.0,
          paymentType: 'prepaid',
          paymentStatus: 'collected',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-004',
          orderNumber: 'TRK-8927',
          customerName: 'Madam Ngozi Okonkwo',
          customerPhone: '08055443322',
          deliveryState: 'Abuja (FCT)',
          deliveryCity: 'Asokoro',
          deliveryAddress: '8 Yakubu Gowon Crescent',
          productName: 'Blood Sugar Balancer',
          status: 'call_back',
          quantity: 1,
          basePrice: 18000.0,
          upsellAmount: 0.0,
          totalAmount: 18000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          createdAt: now,
        ),
      ];

      testRemittances = [
        RemittanceEntity(
          id: 'rem-001',
          referenceNumber: 'REM-00481',
          companyId: '11111111-1111-4111-8111-111111111111',
          deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
          amount: 42500.0,
          grossCollections: 45000.0,
          commissionDeducted: 1000.0,
          transportAllowanceDeducted: 1500.0,
          paymentMethod: 'bank_transfer',
          status: 'verified',
          verifiedByName: 'Wuse DC — Operations',
          notes: 'Bank Transfer to NovaExpress GTBank (Ref: TRX-829101). Fully verified.',
          createdAt: now,
        ),
      ];

      testStock = [
        const StockItemEntity(
          id: 'prod-001',
          sku: 'RESP-DTX-01',
          name: 'Respira Detox Tea',
          description: 'Herbal Detox Tea',
          price: 15000.0,
          totalInCustody: 14,
          assignedCount: 2,
          deliveredCount: 1,
          availableCount: 14,
          returnedCount: 0,
          category: 'Wellness',
        ),
        const StockItemEntity(
          id: 'prod-002',
          sku: 'GRZ-WLT-02',
          name: 'Grazer Weight Loss',
          description: 'Herbal Weight Loss Formula',
          price: 20000.0,
          totalInCustody: 8,
          assignedCount: 3,
          deliveredCount: 3,
          availableCount: 8,
          returnedCount: 0,
          category: 'Weight Management',
        ),
      ];
    });

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
        authRemoteDataSourceProvider.overrideWithValue(MockAuthRemoteDataSource()),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(
            loginUseCase: LoginUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
            logoutUseCase: LogoutUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
            getCurrentUserUseCase: GetCurrentUserUseCase(AuthRepositoryImpl(MockAuthRemoteDataSource())),
          );
          notifier.state = AuthState(user: testPdaUser);
          return notifier;
        }),
        ordersRemoteDataSourceProvider.overrideWithValue(MockOrdersRemoteDataSource(orderModels)),
        ordersProvider.overrideWith((ref) {
          final notifier = OrdersNotifier(
            OrdersRepositoryImpl(MockOrdersRemoteDataSource(orderModels)),
          );
          notifier.state = OrdersState(orders: testOrders, isLoading: false);
          return notifier;
        }),
        financeRemoteDataSourceProvider.overrideWithValue(MockFinanceRemoteDataSource(remittanceModels)),
        financeProvider.overrideWith((ref) {
          final notifier = FinanceNotifier(
            FinanceRepositoryImpl(MockFinanceRemoteDataSource(remittanceModels)),
          );
          notifier.state = FinanceState(
            remittances: testRemittances,
            cashInCustody: 0.0,
            totalEarnedBalance: 0.0,
          );
          return notifier;
        }),
        stockRemoteDataSourceProvider.overrideWithValue(MockStockRemoteDataSource(stockModels)),
        stockProvider.overrideWith((ref) {
          final notifier = StockNotifier(
            repository: StockRepositoryImpl(remoteDataSource: MockStockRemoteDataSource(stockModels)),
          );
          notifier.state = StockState(
            stockItems: testStock,
            isLoading: false,
          );
          return notifier;
        }),
        notificationsRemoteDataSourceProvider.overrideWithValue(MockNotificationsRemoteDataSource()),
        notificationsRepositoryProvider.overrideWithValue(MockNotificationsRepository()),
      ];
    }

    testWidgets('1. Deliveries Tab renders cleanly without RangeError and filters by status', (tester) async {
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

      // Verify header renders without RangeError
      expect(find.text('DELIVERIES'), findsOneWidget);
      expect(find.text('E'), findsOneWidget); // Emeka avatar initial

      // Verify Tab summary counters
      expect(find.textContaining('All (4)'), findsOneWidget);
      expect(find.textContaining('In Progress (1)'), findsOneWidget);
      expect(find.textContaining('Delivered (2)'), findsOneWidget);
      expect(find.textContaining('Returns (1)'), findsOneWidget);

      // Verify orders render
      expect(find.text('Chief Aliyu Mohammed'), findsOneWidget);
      expect(find.text('Dr. Aisha Garba'), findsOneWidget);
    });

    testWidgets('2. Home Dashboard correctly calculates live operations metrics', (tester) async {
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

      // Verify Dashboard greetings and Agent code
      expect(find.textContaining('Emeka Rider'), findsWidgets);
      expect(find.textContaining('PDA-7000'), findsOneWidget);

      // Verify Today's delivery count breakdown & section headers
      expect(find.text("TODAY'S DELIVERIES"), findsOneWidget);
      expect(find.text('FINANCIAL SUMMARY'), findsOneWidget);

      // Delivered COD order = ₦45,000 - ₦2,500 (Rider entitlement) = ₦42,500
      // Remitted = ₦42,500 -> Pending Remittance = ₦0.00 (Reconciled)
      expect(find.text('REMITTANCES RECONCILED'), findsOneWidget);
      expect(find.text('₦0.00'), findsWidgets);
    });

    testWidgets('3. Remittance Page displays Commission, Transport, and Reconciled Card', (tester) async {
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

      // Verify 4-card overview metrics
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('To Remit'), findsOneWidget);
      expect(find.text('Commission'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);

      // Verify dynamic filter tabs and history card
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Approved (1)'), findsOneWidget);
      expect(find.text('REM-00481'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatNaira(42500.0)), findsWidgets);
    });

    testWidgets('4. Notifications Center displays categorized real-time alerts', (tester) async {
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

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('Finance & Remittance'), findsOneWidget);
      expect(find.text('Stock & Handover'), findsOneWidget);
      expect(find.text('System Alerts'), findsOneWidget);

      // Verify notification cards appear
      expect(find.textContaining('New Delivery Assigned'), findsOneWidget);
      expect(find.textContaining('Remittance Approved'), findsOneWidget);
    });
  });
}
