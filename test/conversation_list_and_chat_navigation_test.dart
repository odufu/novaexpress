import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/conversation_list_modal.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';

class FakePipelineChatRemoteDataSource implements PipelineChatRemoteDataSource {
  final OrderConversationEntity conversation;

  FakePipelineChatRemoteDataSource(this.conversation);

  @override
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId) async {
    return conversation;
  }

  @override
  Future<List<OrderConversationEntity>> fetchConversations({String? clientId, String? distributionCenterId, String? deliveryAgentId}) async {
    return [conversation];
  }

  @override
  Future<List<OrderConversationEntity>> fetchConversationsScoped({required String userRole, required String userId, String? clientId, String? distributionCenterId, String? deliveryAgentId, String? closerId}) async {
    return [conversation];
  }

  @override
  Future<void> markConversationAsRead({required String conversationId, required String userRole}) async {}

  @override
  Future<List<OrderConversationMessageEntity>> fetchMessages(String conversationId) async => [];

  @override
  Stream<List<OrderConversationMessageEntity>> streamMessages(String conversationId) => const Stream.empty();

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
  }) async => {'success': true};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Conversation List & In-Modal Chat Navigation Suite', () {
    final now = DateTime.now();
    final testConversation = OrderConversationEntity(
      id: 'conv-test-1',
      orderId: 'ord-test-101',
      orderNumber: 'ORD-NOV-1002',
      customerName: 'Mrs. Fatima Aliyu',
      clientId: 'client-1',
      clientName: 'Novacare',
      deliveryAgentName: 'Emeka Rider',
      distributionCenterName: 'Wuse DC',
      orderStatus: 'delivered',
      currentProductName: 'Respira Tea',
      currentPackageName: 'Standard',
      currentTotalAmount: 22000,
      unreadClientCount: 1,
      lastMessageText: 'i think he is back',
      lastMessageSenderName: 'Dr. Chuka',
      lastMessageAt: now,
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now,
    );

    const testUser = UserEntity(
      id: 'user-merchant-1',
      email: 'merchant@novacare.com',
      firstName: 'Merchant',
      lastName: 'Novacare',
      phone: '08012345678',
      role: 'client',
    );

    testWidgets('Tapping conversation card switches to chat, and back button returns to list without closing modal', (tester) async {
      // Set test screen size to mobile dimensions (SM-A750F approx 360x740)
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDataSource = FakePipelineChatRemoteDataSource(testConversation);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pipelineChatDataSourceProvider.overrideWithValue(fakeDataSource),
            authProvider.overrideWith((ref) => AuthNotifier(
                  loginUseCase: ref.read(loginUseCaseProvider),
                  logoutUseCase: ref.read(logoutUseCaseProvider),
                  getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
                )..state = const AuthState(user: testUser)),
            pipelineChatProvider.overrideWith(
              (ref) => PipelineChatNotifier(
                fakeDataSource,
                ref,
              )..state = PipelineChatState(
                  recentConversations: [testConversation],
                  activeConversation: testConversation,
                  messages: const [],
                ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ConversationListModal.show(context),
                  child: const Text('Open Chats'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Open Chats'));
      await tester.pumpAndSettle();

      // Verify Conversation List view is visible
      expect(find.text('Order Pipeline Chats'), findsOneWidget);
      expect(find.text('Mrs. Fatima Aliyu'), findsOneWidget);
      expect(find.text('Order #ORD-NOV-1002'), findsOneWidget);

      // Tap the conversation card to open the chat
      await tester.tap(find.text('Mrs. Fatima Aliyu'));
      await tester.pumpAndSettle();

      // Verify Chat View is now visible within the modal
      expect(find.byType(OrderPipelineChatSheet), findsOneWidget);
      expect(find.text('Customer: Mrs. Fatima Aliyu'), findsOneWidget);
      expect(find.text('ORD-NOV-1002'), findsOneWidget);

      // Verify Back button exists
      final backButton = find.byTooltip('Back to Conversations');
      expect(backButton, findsOneWidget);

      // Tap Back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we are back on the Conversation List and the modal was NOT closed!
      expect(find.text('Order Pipeline Chats'), findsOneWidget);
      expect(find.text('Mrs. Fatima Aliyu'), findsOneWidget);
      expect(find.byType(OrderPipelineChatSheet), findsNothing);
    });
  });
}
