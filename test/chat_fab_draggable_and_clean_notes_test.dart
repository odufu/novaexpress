import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/core/widgets/user_avatar_widget.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_fab_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _FakeLocalStorageService extends Fake implements LocalStorageService {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> saveJsonObject(String key, Map<String, dynamic> item) async {
    _store[key] = item;
  }

  @override
  Future<Map<String, dynamic>?> getJsonObject(String key) async {
    return _store[key] as Map<String, dynamic>?;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}

class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier([List<OrderEntity> orders = const []])
      : super(OrdersState(orders: orders, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier([List<StockItemEntity> items = const []])
      : super(StockState(stockItems: items, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  _MockDCConsoleNotifier(DCFleetDriver driver)
      : super(DCConsoleState(drivers: [driver], isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(UserModel user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPipelineChatNotifier extends StateNotifier<PipelineChatState> implements PipelineChatNotifier {
  _MockPipelineChatNotifier(List<OrderConversationEntity> convs)
      : super(PipelineChatState(recentConversations: convs));

  @override
  Future<void> loadScopedConversations({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Order Notes Sanitization & Package Deal Extraction Tests', () {
    test('readableDeliveryNotes strips [PACKAGE_DEAL: {...}] and technical metadata tags', () {
      final orderWithJsonNotes = OrderEntity(
        id: 'ord-test-101',
        orderNumber: 'ORD-101',
        customerName: 'Amina Yusuf',
        customerPhone: '08012345678',
        deliveryState: 'FCT',
        deliveryCity: 'Abuja',
        deliveryAddress: 'Wuse 2',
        productName: 'Respira Herbal Tea',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        basePrice: 55000,
        upsellAmount: 0,
        totalAmount: 55000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Novacale',
        status: 'pending',
        createdAt: DateTime.now(),
        deliveryNotes:
            '[PACKAGE_DEAL: {"id": "pkg_123", "name": "4 Respira + 1 Free", "quantity": 5, "price": 55000}]',
      );

      expect(orderWithJsonNotes.readableDeliveryNotes, isEmpty);
    });

    test('readableDeliveryNotes preserves genuine customer notes while stripping internal tags', () {
      final orderWithMixedNotes = OrderEntity(
        id: 'ord-test-102',
        orderNumber: 'ORD-102',
        customerName: 'Amina Yusuf',
        customerPhone: '08012345678',
        deliveryState: 'FCT',
        deliveryCity: 'Abuja',
        deliveryAddress: 'Wuse 2',
        productName: 'Respira Herbal Tea',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        basePrice: 55000,
        upsellAmount: 0,
        totalAmount: 55000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Novacale',
        status: 'pending',
        createdAt: DateTime.now(),
        deliveryNotes:
            'Please deliver before 3pm at the gate [PACKAGE_DEAL: {"id": "pkg_123"}] [Audit Gate PIN: GT-7182]',
      );

      expect(orderWithMixedNotes.readableDeliveryNotes, 'Please deliver before 3pm at the gate');
    });
  });

  group('DCOrderDetailModal Notes & Rider Avatar Tests', () {
    testWidgets('Displays clean human note and UserAvatarWidget for assigned rider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testOrder = OrderEntity(
        id: 'ord-avatar-test',
        orderNumber: 'ORD-AV-01',
        customerName: 'Chidi Nwosu',
        customerPhone: '08033334444',
        deliveryState: 'Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Area 11, Garki',
        productName: 'Respira Herbal Tea',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        basePrice: 55000,
        upsellAmount: 0,
        totalAmount: 55000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Novacale',
        status: 'in_transit',
        deliveryAgentId: 'drv-emeka-1',
        deliveryAgentName: 'Emeka Rider',
        deliveryAgentCode: 'PDA-7000',
        deliveryAgentPhone: '08012345678',
        packageDealName: '4 Respira + 1 Free',
        createdAt: DateTime.now(),
        deliveryNotes:
            '[PACKAGE_DEAL: {"id": "pkg_789382", "name": "4 Respira + 1 Free", "quantity": 5, "price": 55000}]',
      );

      final testDriver = DCFleetDriver(
        id: 'drv-emeka-1',
        name: 'Emeka Rider',
        phone: '08012345678',
        driverCode: 'PDA-7000',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        vehicleModel: 'Motorcycle',
        vehiclePlate: 'ABJ-884-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Abuja Municipal (AMAC)',
        totalAssignedOrders: 10,
        completedOrders: 8,
        routeProgressPercent: 80.0,
        efficiencyRating: 4.8,
        cashInCustody: 25000,
        itemsInCustody: 5,
      );

      final container = ProviderContainer(
        overrides: [
          ordersProvider.overrideWith((ref) => _MockOrdersNotifier([testOrder])),
          stockProvider.overrideWith((ref) => _MockStockNotifier([])),
          dcConsoleProvider.overrideWith((ref) => _MockDCConsoleNotifier(testDriver)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: testOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify raw JSON is NOT rendered
      expect(find.textContaining('[PACKAGE_DEAL:'), findsNothing);
      expect(find.text('Standard doorstep delivery (No special customer notes)'), findsOneWidget);

      // 2. Verify Verified Package Configuration cleanly shows the deal
      expect(find.textContaining('Deal: 4 Respira + 1 Free'), findsOneWidget);

      // 3. Verify Rider section renders UserAvatarWidget
      expect(find.byType(UserAvatarWidget), findsWidgets);
      expect(find.text('Emeka Rider'), findsOneWidget);
      expect(find.text('PDA-7000'), findsOneWidget);
    });
  });

  group('Draggable Pipeline Chat FAB Tests', () {
    testWidgets('PipelineChatFloatingActionButton renders unread badge and responds to drag gesture',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const testUser = UserModel(
        id: 'user-1',
        email: 'agent@novexps.com',
        phone: '08012345678',
        role: 'delivery_agent',
        firstName: 'Test',
        lastName: 'Rider',
      );

      final fakeStorage = _FakeLocalStorageService();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(testUser)),
          localStorageServiceProvider.overrideWithValue(fakeStorage),
          pipelineChatProvider.overrideWith(
            (ref) => _MockPipelineChatNotifier([
              OrderConversationEntity(
                id: 'c1',
                orderId: 'o1',
                orderNumber: 'ORD-1',
                customerName: 'Customer 1',
                clientId: 'cl-1',
                clientName: 'Client 1',
                unreadRiderCount: 1,
                lastMessageAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ]),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  floatingActionButton: const PipelineChatFloatingActionButton(),
                  floatingActionButtonLocation: ref.watch(pipelineChatFabLocationProvider),
                  body: const Center(child: Text('Main Content')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Renders FAB and unread badge '1'
      expect(find.byType(PipelineChatFloatingActionButton), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // 2. Perform a drag gesture on the FAB
      final fabFinder = find.byType(PipelineChatFloatingActionButton);
      final initialCenter = tester.getCenter(fabFinder);
      await tester.drag(fabFinder, const Offset(-100, -150));
      await tester.pumpAndSettle();

      final newCenter = tester.getCenter(fabFinder);
      expect(newCenter.dx, lessThan(initialCenter.dx));
      expect(newCenter.dy, lessThan(initialCenter.dy));
    });
  });
}
