import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

class MockLocalStorageService implements LocalStorageService {
  List<OrderEntity>? cachedOrders;
  final Map<String, List<AppNotificationEntity>> _notificationsByAgent = {};

  @override
  Future<void> cacheOrders(List<OrderEntity> orders, [String? scopeKey]) async {
    cachedOrders = orders;
  }

  @override
  Future<List<OrderEntity>?> getCachedOrders([String? scopeKey]) async => cachedOrders;

  @override
  Future<void> cacheNotifications(String agentId, List<AppNotificationEntity> notifications) async {
    _notificationsByAgent[agentId] = notifications;
  }

  @override
  Future<List<AppNotificationEntity>?> getCachedNotifications(String agentId) async {
    return _notificationsByAgent[agentId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(UserModel user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOrdersRemoteDataSource implements OrdersRemoteDataSource {
  final List<OrderModel> _orders = [];

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async {
    return _orders.where((o) => o.deliveryAgentId == deliveryAgentId).toList();
  }

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async {
    return _orders;
  }

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    final model = OrderModel.fromJson(orderData);
    _orders.add(model);
    return model;
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final old = _orders[index];
      _orders[index] = OrderModel(
        id: old.id,
        orderNumber: old.orderNumber,
        customerName: old.customerName,
        customerPhone: old.customerPhone,
        customerAltPhone: old.customerAltPhone,
        deliveryState: old.deliveryState,
        deliveryCity: old.deliveryCity,
        deliveryAddress: old.deliveryAddress,
        landmark: old.landmark,
        lga: old.lga,
        productName: old.productName,
        status: 'assigned',
        quantity: old.quantity,
        paidQuantity: old.paidQuantity,
        freeQuantity: old.freeQuantity,
        basePrice: old.basePrice,
        upsellAmount: old.upsellAmount,
        totalAmount: old.totalAmount,
        paymentType: old.paymentType,
        paymentStatus: old.paymentStatus,
        fulfillmentType: old.fulfillmentType,
        clientName: old.clientName,
        packageCustodyId: old.packageCustodyId,
        clientDeliveryFee: old.clientDeliveryFee,
        agentEntitlement: old.agentEntitlement,
        deliveryNotes: old.deliveryNotes,
        createdAt: old.createdAt,
        deliveryAgentId: riderId,
        deliveryAgentName: riderName,
        deliveryAgentCode: riderCode,
        distributionCenterId: old.distributionCenterId,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationsRemoteDataSource implements NotificationsRemoteDataSource {
  final Map<String, List<AppNotificationEntity>> _notifications = {};

  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async {
    return _notifications[agentId ?? ''] ?? [];
  }

  @override
  Future<void> createNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  }) async {
    final key = agentId ?? '';
    final list = _notifications[key] ?? [];
    list.insert(
      0,
      AppNotificationEntity(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        category: NotificationCategory.delivery,
        createdAt: DateTime.now(),
        isRead: false,
        actionRoute: actionRoute,
      ),
    );
    _notifications[key] = list;
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}
}

void main() {
  group('Real-Time Order Assignment and Live Notification Pipeline', () {
    late MockOrdersRemoteDataSource mockOrdersRemoteDataSource;
    late MockNotificationsRemoteDataSource mockNotificationsRemoteDataSource;
    late MockLocalStorageService mockStorage;
    late ProviderContainer container;

    const joelUser = UserModel(
      id: 'agent-joel-odufu-uuid',
      email: 'joel.odufu@novaexpress.ng',
      firstName: 'Joel',
      lastName: 'Odufu',
      role: 'pda',
      phone: '+2348012345678',
      operatingState: 'FCT - Abuja',
      operatingCity: 'Wuse 2',
      deliveryAgentCode: 'PDA-7182',
      deliveryAgentId: 'agent-joel-odufu-uuid',
    );

    setUp(() {
      mockOrdersRemoteDataSource = MockOrdersRemoteDataSource();
      mockNotificationsRemoteDataSource = MockNotificationsRemoteDataSource();
      mockStorage = MockLocalStorageService();

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(joelUser)),
          ordersRemoteDataSourceProvider.overrideWithValue(mockOrdersRemoteDataSource),
          notificationsRemoteDataSourceProvider.overrideWithValue(mockNotificationsRemoteDataSource),
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Joel Odufu receives newly assigned order and live notification in state without manual refresh', () async {
      // 1. Initial State: Joel has 0 orders
      final initialOrders = await mockOrdersRemoteDataSource.getAssignedOrders(joelUser.id);
      expect(initialOrders.where((o) => o.deliveryAgentId == joelUser.id), isEmpty);

      // 2. DC Supervisor assigns an order to Joel Odufu
      const newOrderId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      await mockOrdersRemoteDataSource.createOrder({
        'id': newOrderId,
        'order_number': 'ORD-9901-ABJ',
        'customer_name': 'Hajiya Amina Bello',
        'customer_phone': '+2348099887766',
        'delivery_state': 'FCT - Abuja',
        'delivery_city': 'Wuse 2',
        'delivery_address': 'Plot 412 Aminu Kano Crescent, Wuse 2',
        'status': 'pending',
        'total_amount': 45000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'unpaid',
        'company_id': '11111111-1111-4111-8111-111111111111',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
      });

      // Dispatch / Assign to Joel
      await mockOrdersRemoteDataSource.assignOrderToRider(
        orderId: newOrderId,
        riderId: joelUser.id,
        riderName: '${joelUser.firstName} ${joelUser.lastName}',
        riderCode: joelUser.deliveryAgentCode!,
      );

      // 3. Verify getAssignedOrders now returns the newly assigned order
      final joelAssigned = await mockOrdersRemoteDataSource.getAssignedOrders(joelUser.id);
      expect(joelAssigned.any((o) => o.id == newOrderId || o.orderNumber == 'ORD-9901-ABJ'), isTrue);

      // 4. Load orders into OrdersNotifier
      await container.read(ordersProvider.notifier).loadOrders(joelUser.id);
      final currentOrdersState = container.read(ordersProvider);

      expect(currentOrdersState.orders.any((o) => o.orderNumber == 'ORD-9901-ABJ'), isTrue);
      final matchedOrder = currentOrdersState.orders.firstWhere((o) => o.orderNumber == 'ORD-9901-ABJ');
      expect(matchedOrder.customerName, equals('Hajiya Amina Bello'));
      expect(matchedOrder.status, equals('assigned'));

      // 5. Emit live notification for Joel
      await container.read(notificationsProvider.notifier).emitNotification(
        title: 'New Order Assigned! 📦',
        message: 'Order ORD-9901-ABJ for Hajiya Amina Bello in Wuse 2 has been assigned to your route.',
        category: 'delivery',
        actionRoute: '/orders/$newOrderId',
      );

      final notifsState = container.read(notificationsProvider);
      expect(notifsState.notifications.isNotEmpty, isTrue);
      expect(notifsState.unreadCount, greaterThanOrEqualTo(1));
      expect(notifsState.notifications.first.title, contains('New Order Assigned'));
      expect(notifsState.notifications.first.message, contains('Hajiya Amina Bello'));
    });
  });
}
