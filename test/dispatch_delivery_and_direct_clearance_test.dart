import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/domain/usecases/get_current_user.dart';
import 'package:novexps/features/auth/domain/usecases/login.dart';
import 'package:novexps/features/auth/domain/usecases/logout.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/repositories/dc_console_repository.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_finance_operations_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_remittance_detail_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/mark_order_delivered_modal.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/domain/entities/transaction_item.dart';
import 'package:novexps/features/finance/domain/repositories/finance_repository.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOrdersRepository implements OrdersRepository {
  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => [];

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => [];

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFinanceRepository implements FinanceRepository {
  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String agentId) async => [];

  @override
  Future<List<TransactionItem>> getRiderTransactions(String agentId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStockRepository implements StockRepository {
  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId, String? dcId]) async => [];

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDCConsoleRepository implements DCConsoleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuthNotifier(UserEntity? user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationsNotifier extends StateNotifier<NotificationsState>
    implements NotificationsNotifier {
  _FakeNotificationsNotifier() : super(const NotificationsState());

  final List<String> emittedTitles = [];

  @override
  Future<void> fetchNotifications([String? agentId]) async {}

  @override
  Future<void> emitLocalNotification({
    required String title,
    required String message,
    NotificationCategory category = NotificationCategory.system,
    String? orderId,
    String? orderNumber,
    String? actionRoute,
    Map<String, dynamic>? payload,
  }) async {
    emittedTitles.add(title);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePipelineChatRemoteDataSource implements PipelineChatRemoteDataSource {
  final OrderConversationEntity conversation;

  _FakePipelineChatRemoteDataSource(this.conversation);

  @override
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId) async =>
      conversation;

  @override
  Future<List<OrderConversationEntity>> fetchConversations({
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
  }) async =>
      [conversation];

  @override
  Future<List<OrderConversationEntity>> fetchConversationsScoped({
    required String userRole,
    required String userId,
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
    String? closerId,
    String? marketerId,
  }) async =>
      [conversation];

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userRole,
  }) async {}

  @override
  Future<List<OrderConversationMessageEntity>> fetchMessages(
    String conversationId,
  ) async =>
      const [];

  @override
  Stream<List<OrderConversationMessageEntity>> streamMessages(
    String conversationId,
  ) =>
      const Stream.empty();

  @override
  Future<OrderConversationMessageEntity> sendMessage({
    required String conversationId,
    required String orderId,
    required String senderName,
    required ChatSenderRole senderRole,
    required String messageBody,
    String? senderId,
    String? senderAvatarUrl,
    ChatMessageType messageType = ChatMessageType.text,
    Map<String, dynamic>? metadata,
    String? clientMessageId,
  }) async {
    return OrderConversationMessageEntity(
      id: 'msg-1',
      conversationId: conversationId,
      orderId: orderId,
      senderName: senderName,
      senderRole: senderRole,
      messageBody: messageBody,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Map<String, dynamic>> transferOrderProductAndOwnership({
    required String orderId,
    required String newProductId,
    required String newPackageDealId,
    required String newPackageName,
    required int newQuantity,
    required int newPaidQuantity,
    required int newFreeQuantity,
    required double newBasePrice,
    required double newTotalAmount,
    required String actorName,
    required String actorRole,
    required String transferReason,
  }) async =>
      {'success': true};

  @override
  Future<OrderConversationMessageEntity?> toggleMessageReaction({
    required String messageId,
    required String emoji,
    required String userId,
    required String userName,
  }) async =>
      null;
}

class _FakeAuthRepository implements AuthRepositoryImpl {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const dcId = '22222222-2222-4222-8222-222222222222';
  const companyId = '11111111-1111-4111-8111-111111111111';

  const dispatchUser = UserEntity(
    id: 'usr-ops-1',
    email: 'ops@novaxpress.ng',
    phone: '08011110001',
    firstName: 'Ibrahim',
    lastName: 'Dispatcher',
    role: 'dc_operations',
    deliveryAgentCode: 'OPS-001',
    companyId: companyId,
    distributionCenterId: dcId,
    distributionCenterName: 'Central Command DC',
  );

  const dcManagerUser = UserEntity(
    id: 'usr-mgr-1',
    email: 'manager@novaxpress.ng',
    phone: '08011110002',
    firstName: 'Adekunle',
    lastName: 'Manager',
    role: 'dc_manager',
    companyId: companyId,
    distributionCenterId: dcId,
    distributionCenterName: 'Central Command DC',
  );

  const stockKeeperUser = UserEntity(
    id: 'usr-stk-1',
    email: 'stock@novaxpress.ng',
    phone: '08011110003',
    firstName: 'Sadiq',
    lastName: 'Keeper',
    role: 'dc_stock_admin',
    companyId: companyId,
    distributionCenterId: dcId,
    distributionCenterName: 'Central Command DC',
  );

  const financeOpsUser = UserEntity(
    id: 'usr-fin-1',
    email: 'finance@novaxpress.ng',
    phone: '08011110004',
    firstName: 'Zainab',
    lastName: 'Finance',
    role: 'dc_finance_admin',
    companyId: companyId,
    distributionCenterId: dcId,
    distributionCenterName: 'Central Command DC',
  );

  const generalAccountantUser = UserEntity(
    id: 'usr-acc-1',
    email: 'accountant@novaxpress.ng',
    phone: '08011110005',
    firstName: 'Chinedu',
    lastName: 'Accountant',
    role: 'general_accountant',
    companyId: companyId,
    distributionCenterId: dcId,
    distributionCenterName: 'Central Command DC',
  );

  const riderEntity = DCFleetDriver(
    id: 'rider-drv-01',
    driverCode: 'PDA-7001',
    name: 'Emeka Rider',
    phone: '08031234567',
    assignedZone: 'Wuse II',
    distributionCenterId: dcId,
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
    cashInCustody: 75000.0,
  );

  OrderEntity buildInTransitOrder({
    String id = 'ord-disp-1',
    String orderNumber = 'NVX-DISP-101',
    bool assigned = true,
  }) {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerName: 'Hauwa Musa',
      customerPhone: '08090001111',
      deliveryState: 'Federal Capital Territory',
      deliveryCity: 'Wuse II',
      deliveryAddress: '15 Adetokunbo Ademola, Wuse II',
      productId: 'prod-1',
      productName: 'Grazer Herbal Detox Tea',
      productSku: 'SKU-GRZ-01',
      quantity: 2,
      paidQuantity: 2,
      freeQuantity: 0,
      basePrice: 17500.0,
      upsellAmount: 0.0,
      totalAmount: 35000.0,
      status: assigned ? 'in_transit' : 'ready',
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      remittanceStatus: 'unremitted',
      financialSettlementStatus: 'pending_remittance',
      clientId: companyId,
      clientName: 'Novacare Limited',
      distributionCenterId: dcId,
      deliveryAgentId: assigned ? riderEntity.id : null,
      deliveryAgentName: assigned ? riderEntity.name : null,
      deliveryAgentCode: assigned ? riderEntity.driverCode : null,
      deliveryAgentPhone: assigned ? riderEntity.phone : null,
      createdAt: DateTime(2026, 11, 8, 9, 0),
    );
  }

  StockItemEntity buildStockItem() => const StockItemEntity(
        id: 'prod-1',
        sku: 'SKU-GRZ-01',
        name: 'Grazer Herbal Detox Tea',
        description: 'Herbal detox blend',
        price: 17500.0,
        ownerName: 'Novacare Limited',
        inventoryType: InventoryType.distributedInventory,
        totalInCustody: 30,
        assignedCount: 10,
        deliveredCount: 0,
        availableCount: 20,
        returnedCount: 0,
        lowStockThreshold: 5,
        category: 'Wellness',
      );

  RiderStockAllocation buildRiderAllocation() => RiderStockAllocation(
        id: 'alloc-1',
        riderId: riderEntity.id,
        riderName: riderEntity.name,
        riderCode: riderEntity.driverCode,
        productId: 'prod-1',
        productName: 'Grazer Herbal Detox Tea',
        sku: 'SKU-GRZ-01',
        clientName: 'Novacare Limited',
        allocatedUnits: 10,
        deliveredUnits: 0,
        inCustodyUnits: 10,
        unitPrice: 17500.0,
        allocatedAt: DateTime(2026, 11, 8, 8, 0),
      );

  ProviderContainer buildRealContainer({
    required UserEntity? activeUser,
    List<OrderEntity> initialOrders = const [],
    List<RemittanceEntity> initialRemittances = const [],
    List<DCFleetDriver> initialDrivers = const [riderEntity],
    List<StockItemEntity> initialStock = const [],
    List<RiderStockAllocation> initialAllocations = const [],
    List<OrderConversationEntity> conversations = const [],
  }) {
    final storage = LocalStorageServiceImpl();
    final fakeAuthRepo = _FakeAuthRepository();
    final fakeChatDataSource = _FakePipelineChatRemoteDataSource(
      conversations.isNotEmpty
          ? conversations.first
          : OrderConversationEntity(
              id: 'conv-1',
              orderId: initialOrders.isNotEmpty ? initialOrders.first.id : 'ord-1',
              orderNumber:
                  initialOrders.isNotEmpty ? initialOrders.first.orderNumber : 'NVX-1',
              customerName: 'Hauwa Musa',
              customerPhone: '08090001111',
              clientId: companyId,
              clientName: 'Novacare Limited',
              distributionCenterId: dcId,
              deliveryAgentId: riderEntity.id,
              deliveryAgentName: riderEntity.name,
              lastMessageAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        loginUseCaseProvider.overrideWithValue(LoginUseCase(fakeAuthRepo)),
        logoutUseCaseProvider.overrideWithValue(LogoutUseCase(fakeAuthRepo)),
        getCurrentUserUseCaseProvider.overrideWithValue(GetCurrentUserUseCase(fakeAuthRepo)),
        localStorageServiceProvider.overrideWithValue(storage),
        authProvider.overrideWith((ref) => _TestAuthNotifier(activeUser)),
        notificationsProvider.overrideWith((ref) => _FakeNotificationsNotifier()),
        dcConsoleProvider.overrideWith((ref) {
          final notifier = DCConsoleNotifier(storage, _FakeDCConsoleRepository(), ref);
          notifier.state = DCConsoleState(
            activeHubId: dcId,
            activeHubName: 'Central Command DC',
            activeHubCode: 'DC-CMD-01',
            drivers: initialDrivers,
            financeSettings: const DCFinanceSettings(
              posChargeMode: 'flat',
              posFlatRate: 350.0,
              defaultCommissionRate: 1000.0,
              defaultTransportAllowance: 1500.0,
            ),
          );
          return notifier;
        }),
        stockProvider.overrideWith((ref) {
          final notifier = StockNotifier(
            repository: _FakeStockRepository(),
            storageService: storage,
            ref: ref,
          );
          notifier.state = StockState(
            isLoading: false,
            stockItems: initialStock,
            riderAllocations: initialAllocations,
          );
          return notifier;
        }),
        ordersProvider.overrideWith((ref) {
          final notifier = OrdersNotifier(
            _FakeOrdersRepository(),
            null,
            storage,
            ref,
          );
          notifier.state = OrdersState(isLoading: false, orders: initialOrders);
          return notifier;
        }),
        financeProvider.overrideWith((ref) {
          final notifier = FinanceNotifier(
            _FakeFinanceRepository(),
            storageService: storage,
            ref: ref,
          );
          notifier.state = FinanceState(
            isLoading: false,
            remittances: initialRemittances,
          );
          return notifier;
        }),
        pipelineChatDataSourceProvider.overrideWithValue(fakeChatDataSource),
        pipelineChatProvider.overrideWith((ref) {
          return PipelineChatNotifier(fakeChatDataSource, ref)
            ..state = PipelineChatState(
              recentConversations: conversations,
              activeConversation: conversations.isNotEmpty ? conversations.first : null,
            );
        }),
      ],
    );
  }

  group('Capability 1: Dispatch Operator Order Delivery Marking', () {
    test('1.1 dc_operations marks Cash POD order delivered for rider and reconciles rider custody without double-deducting warehouse shelf', () async {
      final order = buildInTransitOrder();
      final container = buildRealContainer(
        activeUser: dispatchUser,
        initialOrders: [order],
        initialStock: [buildStockItem()],
        initialAllocations: [buildRiderAllocation()],
      );
      addTearDown(container.dispose);

      final result = await container.read(ordersProvider.notifier).markOrderDeliveredByDispatch(
            orderId: order.id,
            fulfillingRider: riderEntity,
            paymentMethod: 'cash',
            amountCollected: 35000.0,
            reasonOrNote: 'Rider phone battery dead',
          );

      expect(result['success'], isTrue);
      final updatedOrder = container.read(ordersProvider).orders.first;
      expect(updatedOrder.status, 'delivered');
      expect(updatedOrder.paymentType, 'pay_on_delivery');
      expect(updatedOrder.paymentStatus, 'collected');
      expect(updatedOrder.remittanceStatus, 'unremitted');
      expect(updatedOrder.financialSettlementStatus, 'pending_remittance');
      expect(updatedOrder.deliveryAgentId, riderEntity.id);
      expect(updatedOrder.deliveryNotes, contains('DELIVERED BY DISPATCH OPS'));
      expect(updatedOrder.deliveryNotes, contains('Rider phone battery dead'));

      // Stock: rider custody reduced by 2 (10 -> 8), warehouse availableCount stays 20 (no double deduction!)
      final stockState = container.read(stockProvider);
      expect(stockState.riderAllocations.first.inCustodyUnits, 8);
      expect(stockState.riderAllocations.first.deliveredUnits, 2);
      expect(stockState.stockItems.first.availableCount, 20);
      expect(stockState.stockItems.first.assignedCount, 8);
      expect(stockState.stockItems.first.deliveredCount, 2);
    });

    test('1.2 dc_manager marks unassigned order delivered via Direct DC Counter Handover & Direct Transfer', () async {
      final order = buildInTransitOrder(id: 'ord-counter-1', orderNumber: 'NVX-CNT-102', assigned: false);
      final container = buildRealContainer(
        activeUser: dcManagerUser,
        initialOrders: [order],
        initialStock: [buildStockItem()],
        initialAllocations: [buildRiderAllocation()],
      );
      addTearDown(container.dispose);

      final result = await container.read(ordersProvider.notifier).markOrderDeliveredByDispatch(
            orderId: order.id,
            directDcHandover: true,
            paymentMethod: 'direct_transfer',
            amountCollected: 35000.0,
            transferReference: 'NIP-998877',
            bankName: 'Titan Trust Bank',
            reasonOrNote: 'DC counter customer pickup',
          );

      expect(result['success'], isTrue);
      final updatedOrder = container.read(ordersProvider).orders.first;
      expect(updatedOrder.status, 'delivered');
      expect(updatedOrder.deliveryAgentId, isNull);
      expect(updatedOrder.paymentType, 'direct_transfer');
      expect(updatedOrder.paymentStatus, 'paid');
      expect(updatedOrder.remittanceStatus, 'direct_transfer');
      expect(updatedOrder.financialSettlementStatus, 'direct_transfer_settled');
      expect(updatedOrder.deliveryNotes, contains('Direct DC Counter Handover'));
      expect(updatedOrder.deliveryNotes, contains('NIP-998877'));

      // Direct DC Counter decrements warehouse availableCount (20 -> 18) and leaves rider custody (10) untouched
      final stockState = container.read(stockProvider);
      expect(stockState.stockItems.first.availableCount, 18);
      expect(stockState.stockItems.first.deliveredCount, 2);
      expect(stockState.riderAllocations.first.inCustodyUnits, 10);
    });

    test('1.3 Strict Role Boundary: Stock Keeper and Rider are rejected by markOrderDeliveredByDispatch', () async {
      final order = buildInTransitOrder();
      for (final unauthorizedUser in [
        stockKeeperUser,
        const UserEntity(
          id: 'rider-usr-1',
          email: 'rider@novaxpress.ng',
          phone: '08031234567',
          firstName: 'Emeka',
          lastName: 'Rider',
          role: 'delivery_agent',
          deliveryAgentId: 'rider-drv-01',
        ),
      ]) {
        final container = buildRealContainer(
          activeUser: unauthorizedUser,
          initialOrders: [order],
          initialStock: [buildStockItem()],
          initialAllocations: [buildRiderAllocation()],
        );

        final result = await container.read(ordersProvider.notifier).markOrderDeliveredByDispatch(
              orderId: order.id,
              fulfillingRider: riderEntity,
              paymentMethod: 'cash',
            );

        expect(result['success'], isFalse);
        expect(container.read(ordersProvider).orders.first.status, 'in_transit');
        expect(container.read(stockProvider).riderAllocations.first.inCustodyUnits, 10);
        container.dispose();
      }
    });

    testWidgets('1.4 DCOrderDetailModal shows Mark Delivered for dc_operations and completes delivery through MarkOrderDeliveredModal', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order = buildInTransitOrder();
      final container = buildRealContainer(
        activeUser: dispatchUser,
        initialOrders: [order],
        initialStock: [buildStockItem()],
        initialAllocations: [buildRiderAllocation()],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: order),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mark Delivered'), findsOneWidget);
      await tester.tap(find.text('Mark Delivered'));
      await tester.pumpAndSettle();

      expect(find.byType(MarkOrderDeliveredModal), findsOneWidget);
      expect(find.text('Mark Order Delivered'), findsOneWidget);

      await tester.tap(find.text('Confirm Delivery'));
      await tester.pumpAndSettle();

      expect(container.read(ordersProvider).orders.first.status, 'delivered');
    });

    testWidgets('1.5 DCOrderDetailModal & OrderPipelineChatSheet block Stock Keeper while Dispatch Ops sees Mark Delivered', (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order = buildInTransitOrder();
      final conv = OrderConversationEntity(
        id: 'conv-disp-1',
        orderId: order.id,
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        clientId: companyId,
        clientName: 'Novacare Limited',
        distributionCenterId: dcId,
        deliveryAgentId: riderEntity.id,
        deliveryAgentName: riderEntity.name,
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Stock Keeper in DCOrderDetailModal: no Mark Delivered
      final stockContainer = buildRealContainer(
        activeUser: stockKeeperUser,
        initialOrders: [order],
        conversations: [conv],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: stockContainer,
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: order),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mark Delivered'), findsNothing);
      stockContainer.dispose();

      // Stock Keeper in OrderPipelineChatSheet: no Mark Delivered quick action
      final stockChatContainer = buildRealContainer(
        activeUser: stockKeeperUser,
        initialOrders: [order],
        conversations: [conv],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: stockChatContainer,
          child: MaterialApp(
            home: Scaffold(
              body: OrderPipelineChatSheet(
                orderId: order.id,
                orderNumber: order.orderNumber,
                customerName: order.customerName,
                customerPhone: order.customerPhone,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Mark Delivered'), findsNothing);
      stockChatContainer.dispose();

      // Dispatch Ops in OrderPipelineChatSheet: sees Mark Delivered quick action
      final opsChatContainer = buildRealContainer(
        activeUser: dispatchUser,
        initialOrders: [order],
        conversations: [conv],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: opsChatContainer,
          child: MaterialApp(
            home: Scaffold(
              body: OrderPipelineChatSheet(
                orderId: order.id,
                orderNumber: order.orderNumber,
                customerName: order.customerName,
                customerPhone: order.customerPhone,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Mark Delivered'), findsOneWidget);
      opsChatContainer.dispose();
    });
  });

  group('Capability 2: Finance Ops Proactive Direct Clearance of Unrequested Remittances', () {
    OrderEntity buildDeliveredCashOrder({
      String id = 'ord-cash-1',
      String orderNumber = 'NVX-CASH-201',
      double amount = 45000.0,
      String remittanceStatus = 'unremitted',
      String paymentStatus = 'collected',
    }) {
      return OrderEntity(
        id: id,
        orderNumber: orderNumber,
        customerName: 'Bala Sani',
        customerPhone: '08023334444',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Garki',
        deliveryAddress: '12 Gimbiya Street',
        productName: 'Grazer Herbal Detox Tea',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: amount,
        upsellAmount: 0.0,
        totalAmount: amount,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentStatus: paymentStatus,
        remittanceStatus: remittanceStatus,
        financialSettlementStatus:
            remittanceStatus == 'cleared' ? 'cash_remitted_verified' : 'pending_remittance',
        clientId: companyId,
        clientName: 'Novacare Limited',
        distributionCenterId: dcId,
        deliveryAgentId: riderEntity.id,
        deliveryAgentName: riderEntity.name,
        deliveryAgentCode: riderEntity.driverCode,
        deliveryAgentPhone: riderEntity.phone,
        deliveredAt: DateTime(2026, 11, 9, 10, 0),
        createdAt: DateTime(2026, 11, 9, 8, 30),
      );
    }

    test('2.1 dc_finance_admin & general_accountant directly clear unrequested remittances, reconcile COD custody, and prevent double clearance', () async {
      final order1 = buildDeliveredCashOrder(id: 'ord-c-1', orderNumber: 'NVX-C-1', amount: 45000.0);
      final order2 = buildDeliveredCashOrder(id: 'ord-c-2', orderNumber: 'NVX-C-2', amount: 30000.0);
      final container = buildRealContainer(
        activeUser: financeOpsUser,
        initialOrders: [order1, order2],
        initialDrivers: [riderEntity], // 75,000 cashInCustody
      );
      addTearDown(container.dispose);

      // Direct clearance by Finance Ops without any prior rider request
      final res = await container.read(financeProvider.notifier).clearUnrequestedRemittanceDirectly(
            riderId: riderEntity.id,
            riderName: riderEntity.name,
            riderCode: riderEntity.driverCode,
            netAmount: 71150.0,
            grossAmount: 75000.0,
            commissionDeducted: 2000.0,
            transportAllowanceDeducted: 1500.0,
            posFee: 350.0,
            paymentMethod: 'cash_to_dc',
            orders: [order1, order2],
          );

      expect(res['success'], isTrue);
      expect(res['clearedOrderCount'], 2);

      // Finance state updated with verified remittance and ledger transaction
      final financeState = container.read(financeProvider);
      expect(financeState.remittances.length, 1);
      expect(financeState.remittances.first.isVerified, isTrue);
      expect(financeState.remittances.first.amount, 71150.0);
      expect(financeState.remittances.first.paymentMethod, 'dc_handover');
      expect(financeState.transactions.length, 1);

      // Orders marked remitted/cleared
      final updatedOrders = container.read(ordersProvider).orders;
      expect(updatedOrders.every((o) => o.isRemitted), isTrue);
      expect(updatedOrders.every((o) => o.paymentStatus == 'remitted'), isTrue);

      // Rider cashInCustody zeroed out cleanly
      expect(container.read(dcConsoleProvider).drivers.first.cashInCustody, 0.0);

      // Attempting a second clearance on already-cleared orders must fail safely
      final duplicateRes = await container
          .read(financeProvider.notifier)
          .clearUnrequestedRemittanceDirectly(
            riderId: riderEntity.id,
            riderName: riderEntity.name,
            riderCode: riderEntity.driverCode,
            netAmount: 71150.0,
            grossAmount: 75000.0,
            orders: updatedOrders,
          );
      expect(duplicateRes['success'], isFalse);

      // Also verify general_accountant has permission on another unrequested batch
      final order3 = buildDeliveredCashOrder(id: 'ord-c-3', orderNumber: 'NVX-C-3', amount: 25000.0);
      final acctContainer = buildRealContainer(
        activeUser: generalAccountantUser,
        initialOrders: [order3],
        initialDrivers: [riderEntity.copyWith(cashInCustody: 25000.0)],
      );
      addTearDown(acctContainer.dispose);
      final acctRes = await acctContainer
          .read(financeProvider.notifier)
          .clearUnrequestedRemittanceDirectly(
            riderId: riderEntity.id,
            riderName: riderEntity.name,
            riderCode: riderEntity.driverCode,
            netAmount: 22150.0,
            grossAmount: 25000.0,
            paymentMethod: 'pos_deposit',
            orders: [order3],
          );
      expect(acctRes['success'], isTrue);
      expect(acctContainer.read(financeProvider).remittances.first.paymentMethod, 'pos_settlement');
    });

    test('2.2 Partial direct clearance excludes orders attached to pending remittance request and decrements remaining rider custody', () async {
      final requestedOrder = buildDeliveredCashOrder(
        id: 'ord-req-1',
        orderNumber: 'NVX-REQ-1',
        amount: 35000.0,
      );
      final unrequestedOrder = buildDeliveredCashOrder(
        id: 'ord-unreq-2',
        orderNumber: 'NVX-UNREQ-2',
        amount: 40000.0,
      );
      final existingPendingRem = RemittanceEntity(
        id: 'rem-pending-1',
        referenceNumber: 'RMT-PEND-01',
        companyId: companyId,
        deliveryAgentId: riderEntity.id,
        amount: 32150.0,
        grossCollections: 35000.0,
        paymentMethod: 'bank_transfer',
        status: 'pending',
        associatedOrders: [
          RemittanceOrderItem(
            orderId: requestedOrder.id,
            orderNumber: requestedOrder.orderNumber,
            customerName: requestedOrder.customerName,
            status: 'delivered',
            paymentType: 'pay_on_delivery',
            cashCollected: 35000.0,
            date: DateTime(2026, 11, 9, 10, 0),
          ),
        ],
        createdAt: DateTime(2026, 11, 9, 11, 0),
      );

      final container = buildRealContainer(
        activeUser: financeOpsUser,
        initialOrders: [requestedOrder, unrequestedOrder],
        initialRemittances: [existingPendingRem],
        initialDrivers: [riderEntity], // 75,000 cashInCustody
      );
      addTearDown(container.dispose);

      // Direct clearance ONLY on unrequestedOrder succeeds and leaves requestedOrder untouched
      final res = await container.read(financeProvider.notifier).clearUnrequestedRemittanceDirectly(
            riderId: riderEntity.id,
            riderName: riderEntity.name,
            riderCode: riderEntity.driverCode,
            netAmount: 37150.0,
            grossAmount: 40000.0,
            commissionDeducted: 1000.0,
            transportAllowanceDeducted: 1500.0,
            posFee: 350.0,
            orders: [requestedOrder, unrequestedOrder],
          );

      expect(res['success'], isTrue);
      expect(res['clearedOrderCount'], 1);

      final orders = container.read(ordersProvider).orders;
      final stillRequested = orders.firstWhere((o) => o.id == requestedOrder.id);
      final nowCleared = orders.firstWhere((o) => o.id == unrequestedOrder.id);
      expect(stillRequested.isRemitted, isFalse);
      expect(nowCleared.isRemitted, isTrue);

      // Rider cashInCustody still positive for remaining unremitted requested order
      expect(container.read(dcConsoleProvider).drivers.first.cashInCustody, greaterThan(0.0));
    });

    test('2.3 Strict Role Boundary: Stock Keeper and Dispatch Ops cannot clear unrequested remittances', () async {
      final order = buildDeliveredCashOrder();
      for (final unauthorizedUser in [stockKeeperUser, dispatchUser]) {
        final container = buildRealContainer(
          activeUser: unauthorizedUser,
          initialOrders: [order],
          initialDrivers: [riderEntity.copyWith(cashInCustody: 45000.0)],
        );

        final res = await container
            .read(financeProvider.notifier)
            .clearUnrequestedRemittanceDirectly(
              riderId: riderEntity.id,
              riderName: riderEntity.name,
              netAmount: 42150.0,
              grossAmount: 45000.0,
              orders: [order],
            );

        expect(res['success'], isFalse);
        expect(container.read(financeProvider).remittances, isEmpty);
        expect(container.read(ordersProvider).orders.first.isRemitted, isFalse);
        container.dispose();
      }
    });

    testWidgets('2.4 DCRemittanceDetailModal allows Finance Ops to verify & clear unrequested cash directly with channel selection, while blocking Stock Keeper', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order1 = buildDeliveredCashOrder(id: 'ord-ui-1', orderNumber: 'NVX-UI-1', amount: 45000.0);
      final unrequestedItem = DCRemittanceLifecycleItem(
        id: 'unrequested-${riderEntity.id}',
        referenceNumber: 'UNREQ-${riderEntity.driverCode}',
        riderId: riderEntity.id,
        riderName: riderEntity.name,
        riderCode: riderEntity.driverCode,
        riderPhone: riderEntity.phone,
        type: 'cash_pod',
        status: 'unrequested',
        openingDate: order1.createdAt,
        grossAmount: 45000.0,
        commissionAmount: 1000.0,
        transportAllowance: 1500.0,
        posFee: 350.0,
        netAmount: 42150.0,
        orders: [order1],
      );

      // 1. Authorized Finance Ops flow
      final finContainer = buildRealContainer(
        activeUser: financeOpsUser,
        initialOrders: [order1],
        initialDrivers: [riderEntity.copyWith(cashInCustody: 45000.0)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: const ValueKey('fin-remittance-modal-scope'),
          container: finContainer,
          child: MaterialApp(
            key: const ValueKey('fin-remittance-modal-app'),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => DCRemittanceDetailModal.show(ctx, unrequestedItem),
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Verify & Clear'), findsOneWidget);
      await tester.tap(find.textContaining('Verify & Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Verify & Clear Remittance'), findsOneWidget);
      expect(find.text('Clearance Channel'), findsOneWidget);
      expect(find.text('Confirm & Clear'), findsOneWidget);

      await tester.tap(find.text('Confirm & Clear'));
      await tester.pumpAndSettle();

      expect(finContainer.read(financeProvider).remittances.length, 1);
      expect(finContainer.read(financeProvider).remittances.first.isVerified, isTrue);
      expect(finContainer.read(ordersProvider).orders.first.isRemitted, isTrue);
      expect(finContainer.read(dcConsoleProvider).drivers.first.cashInCustody, 0.0);
      finContainer.dispose();

      // 2. Unauthorized Stock Keeper sees Read-Only
      final stkContainer = buildRealContainer(
        activeUser: stockKeeperUser,
        initialOrders: [order1],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: const ValueKey('stk-remittance-modal-scope'),
          container: stkContainer,
          child: MaterialApp(
            key: const ValueKey('stk-remittance-modal-app'),
            home: Scaffold(
              body: DCRemittanceDetailModal(remittance: unrequestedItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read-Only • Finance Only'), findsOneWidget);
      stkContainer.dispose();
    });

    testWidgets('2.5 DCFinanceOperationsPage Rider Liabilities dossier replaces UNREQUESTED FOR CLEARANCE blocker with Clear Remittance Directly CTA', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final order1 = buildDeliveredCashOrder(id: 'ord-fin-1', orderNumber: 'NVX-FIN-1', amount: 45000.0);
      final container = buildRealContainer(
        activeUser: financeOpsUser,
        initialOrders: [order1],
        initialDrivers: [riderEntity.copyWith(cashInCustody: 45000.0)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DCFinanceOperationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Rider Cash tab
      await tester.tap(find.text('Rider Cash'));
      await tester.pumpAndSettle();

      expect(find.text(riderEntity.name), findsOneWidget);
      await tester.tap(find.text(riderEntity.name));
      await tester.pumpAndSettle();

      // Verify old policy blocker text is gone and direct clearance UI is active
      expect(find.textContaining('UNREQUESTED FOR CLEARANCE'), findsNothing);
      expect(find.textContaining('NO CLEARANCE ACTION is permitted'), findsNothing);
      expect(find.text('🟡 FIELD CASH • DIRECT CLEARABLE'), findsOneWidget);
      expect(find.text('Clear Remittance Directly'), findsOneWidget);

      await tester.tap(find.text('Clear Remittance Directly'));
      await tester.pumpAndSettle();

      expect(find.byType(DCRemittanceDetailModal), findsOneWidget);
      expect(find.textContaining('Verify & Clear'), findsOneWidget);
    });
  });
}
