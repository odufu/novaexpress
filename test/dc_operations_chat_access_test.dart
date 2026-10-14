import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_operations_mobile_portal_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  MockStockNotifier() : super(const StockState());

  @override
  Future<void> fetchStockItems([String? clientId, String? dcId]) async {}

  @override
  Future<void> fetchStockTransfers({
    String? dcId,
    String? clientId,
    String? riderId,
    String? status,
    String? transferType,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Operations Chat Widget & Access Suite', () {
    const testOfficer = UserEntity(
      id: 'c3333333-3333-4333-8333-333333333333',
      email: 'abigail@novaxpress.ng',
      firstName: 'Abigail',
      lastName: 'Kooyon',
      phone: '+234 803 987 6543',
      role: 'dc_operations',
      deliveryAgentCode: 'OPS-WUSE-01-748',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      distributionCenterName: 'Wuse Grand Central Distribution Center',
    );

    final wuseDc = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Wuse Grand Central Distribution Center',
      code: 'DC-WUSE-01',
      state: 'Federal Capital Territory',
      city: 'Wuse 2',
      address: 'Plot 104, Aminu Kano Crescent, Wuse 2, Abuja',
      isGrandDc: true,
      operatingZones: const ['AMAC', 'Wuse 2', 'Maitama', 'Garki'],
    );

    final now = DateTime.now();
    final sampleOrder = OrderEntity(
      id: 'ord-wuse-01',
      orderNumber: 'NOV-2026-5837',
      customerName: 'Michael Sule',
      customerPhone: '08012345678',
      deliveryAddress: 'Back of hakimi palace, Dutse, abuja',
      deliveryState: 'Federal Capital Territory',
      deliveryCity: 'Abuja Municipal (AMAC)',
      productName: 'Compression vest',
      quantity: 5,
      basePrice: 13760,
      upsellAmount: 0,
      totalAmount: 68800,
      status: 'in_transit',
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      distributionCenterName: 'Wuse Grand Central Distribution Center',
      deliveryAgentId: 'rider-501',
      deliveryAgentName: 'Oladele Omowaye',
      deliveryAgentCode: 'RDR-501',
      closerName: 'Caroline Onoja',
      createdAt: now,
    );

    final sampleConversation = OrderConversationEntity(
      id: 'conv-5837',
      orderId: 'ord-wuse-01',
      orderNumber: 'NOV-2026-5837',
      customerName: 'Michael Sule',
      clientId: 'client-1',
      clientName: 'Novacare Ltd',
      closerName: 'Caroline Onoja',
      deliveryAgentName: 'Oladele Omowaye',
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      unreadDcCount: 2,
      unreadClientCount: 0,
      unreadRiderCount: 0,
      lastMessageText: 'Rider on the way to Dutse',
      lastMessageSenderName: 'Oladele Omowaye',
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    test('PipelineChatState computes correct unread counts for dc_operations role', () {
      final state = PipelineChatState(
        recentConversations: [sampleConversation],
      );

      expect(state.getUnreadCountForRole('dc_operations'), equals(1));
      expect(state.getUnreadCountForRole('operations_officer'), equals(1));
      expect(state.getUnreadCountForRole('dispatcher'), equals(1));
      expect(state.getUnreadCountForRole('dc_manager'), equals(1));
      expect(state.getUnreadCountForRole('closer'), equals(0));
    });

    testWidgets('DCOperationsMobilePortalPage displays floating chat widget and order chat button with badges', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(
                  loginUseCase: ref.read(loginUseCaseProvider),
                  logoutUseCase: ref.read(logoutUseCaseProvider),
                  getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
                )..state = const AuthState(user: testOfficer)),
            dcConsoleProvider.overrideWith(
              (ref) => DCConsoleNotifier()
                ..state = DCConsoleState(
                  distributionCenters: [wuseDc],
                  activeHubId: wuseDc.id,
                ),
            ),
            ordersProvider.overrideWith(
              (ref) => OrdersNotifier(ref.read(ordersRepositoryProvider))
                ..state = OrdersState(orders: [sampleOrder]),
            ),
            stockProvider.overrideWith((ref) => MockStockNotifier()),
            pipelineChatProvider.overrideWith(
              (ref) => PipelineChatNotifier(
                ref.read(pipelineChatDataSourceProvider),
                ref,
              )..state = PipelineChatState(recentConversations: [sampleConversation]),
            ),
          ],
          child: const MaterialApp(
            home: DCOperationsMobilePortalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Floating Action Button is present on DCOperationsMobilePortalPage
      expect(find.byType(PipelineChatFloatingActionButton), findsOneWidget);

      // 2. Unread badge '1' is displayed on the floating action button
      expect(find.text('1'), findsWidgets);

      // 3. Order Pipeline Chats button is in the AppBar
      expect(find.byTooltip('Order Pipeline Chats (1 unread)'), findsOneWidget);

      // 4. Order card has order pipeline chat button with unread count badge
      expect(find.byTooltip('Order Pipeline Chat (2 unread)'), findsOneWidget);
    });
  });
}
