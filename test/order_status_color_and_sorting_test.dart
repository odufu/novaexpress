import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/pages/orders_list_page.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';

class MockOrdersRepository implements OrdersRepository {
  List<OrderEntity> orders = [];

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => orders;

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => orders;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalStorageService implements LocalStorageService {
  List<OrderEntity>? cached;

  @override
  Future<void> cacheOrders(List<OrderEntity> orders, [String? scopeKey]) async {
    cached = orders;
  }

  @override
  Future<List<OrderEntity>?> getCachedOrders([String? scopeKey]) async => cached;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AuthState(user: user, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationsNotifier extends StateNotifier<NotificationsState> implements NotificationsNotifier {
  FakeNotificationsNotifier() : super(const NotificationsState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('OrdersNotifier and UI sort active orders to the top and delivered orders to the bottom', () async {
    final now = DateTime.now();
    final List<OrderEntity> testOrders = [
      OrderEntity(
        id: 'ord-del-1',
        orderNumber: 'ORD-DEL-01',
        customerName: 'Customer Emeka (Delivered)',
        customerPhone: '08011111111',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '5 Aba Road',
        productName: 'Alpha Man Vitality',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        createdAt: now.subtract(const Duration(minutes: 50)),
      ),
      OrderEntity(
        id: 'ord-prog-1',
        orderNumber: 'ORD-PROG-01',
        customerName: 'Customer Chidi (In Progress)',
        customerPhone: '08022222222',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: '10 Zaria Road',
        productName: 'Respira Vitality',
        status: 'in_transit',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 26000.0,
        upsellAmount: 0.0,
        totalAmount: 26000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      OrderEntity(
        id: 'ord-pend-1',
        orderNumber: 'ORD-PEND-01',
        customerName: 'Customer Aisha (Pending)',
        customerPhone: '08033333333',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: '25 Ring Road',
        productName: 'Grazer Herbal Tea',
        status: 'pending',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 24000.0,
        upsellAmount: 0.0,
        totalAmount: 24000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
    ];

    final mockRepo = MockOrdersRepository();
    mockRepo.orders = testOrders;
    final mockStorage = MockLocalStorageService();

    final notifier = OrdersNotifier(mockRepo, null, mockStorage);
    await notifier.loadOrders('agent-1');

    final sorted = notifier.state.orders;

    // Verify: In-transit is #1 (top), Pending is #2, Delivered is #3 (bottom)
    expect(sorted[0].status, equals('in_transit'), reason: 'In-progress active order must be at the top');
    expect(sorted[1].status, equals('pending'), reason: 'Pending active order must precede completed ones');
    expect(sorted[2].status, equals('delivered'), reason: 'Delivered order must move down the column');
  });

  testWidgets('OrdersListPage renders WhatsApp green styling for delivered orders', (tester) async {
    final now = DateTime.now();
    final List<OrderEntity> testOrders = [
      OrderEntity(
        id: 'ord-del-1',
        orderNumber: 'ORD-DEL-01',
        customerName: 'Customer Emeka Delivered',
        customerPhone: '08011111111',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '5 Aba Road',
        productName: 'Alpha Man Vitality',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        createdAt: now.subtract(const Duration(minutes: 50)),
      ),
      OrderEntity(
        id: 'ord-prog-1',
        orderNumber: 'ORD-PROG-01',
        customerName: 'Customer Chidi In Progress',
        customerPhone: '08022222222',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: '10 Zaria Road',
        productName: 'Respira Vitality',
        status: 'in_transit',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 26000.0,
        upsellAmount: 0.0,
        totalAmount: 26000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];

    final mockRepo = MockOrdersRepository();
    mockRepo.orders = testOrders;
    final mockStorage = MockLocalStorageService();

    const testUser = UserModel(
      id: 'agent-1',
      email: 'joel.odufu@novaexpress.ng',
      firstName: 'Joel',
      lastName: 'Odufu',
      phone: '08031234567',
      role: 'delivery_agent',
      deliveryAgentId: 'agent-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          ordersProvider.overrideWith((ref) => OrdersNotifier(mockRepo, null, mockStorage, ref)),
          notificationsProvider.overrideWith((ref) => FakeNotificationsNotifier()),
        ],
        child: const MaterialApp(
          home: OrdersListPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Delivered text, In Progress text and double check icon
    expect(find.text('DELIVERED'), findsWidgets);
    expect(find.text('IN PROGRESS'), findsWidgets);
    expect(find.byIcon(Icons.done_all_rounded), findsWidgets);
  });
}
