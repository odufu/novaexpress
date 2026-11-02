import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';

class EnhancementsFakeChatDataSource implements PipelineChatRemoteDataSource {
  final OrderConversationEntity conversation;
  final List<OrderConversationMessageEntity> messages;

  EnhancementsFakeChatDataSource({required this.conversation, required this.messages});

  @override
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId) async => conversation;

  @override
  Future<List<OrderConversationEntity>> fetchConversations({String? clientId, String? distributionCenterId, String? deliveryAgentId}) async => [conversation];

  @override
  Future<List<OrderConversationEntity>> fetchConversationsScoped({
    required String userRole,
    required String userId,
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
    String? closerId,
    String? marketerId,
  }) async => [conversation];

  @override
  Future<void> markConversationAsRead({required String conversationId, required String userRole}) async {}

  @override
  Future<List<OrderConversationMessageEntity>> fetchMessages(String conversationId) async => messages;

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
      id: 'new-msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      orderId: orderId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      senderRole: senderRole,
      messageType: messageType,
      messageBody: messageBody,
      metadata: metadata ?? {},
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

  @override
  Future<OrderConversationMessageEntity?> toggleMessageReaction({
    required String messageId,
    required String emoji,
    required String userId,
    required String userName,
  }) async => null;
}

void main() {
  group('WhatsApp Chat Experience Enhancements Test Suite', () {
    final now = DateTime.now();

    final testConversation = OrderConversationEntity(
      id: 'conv-test-101',
      orderId: 'ord-test-101',
      orderNumber: 'NOV-2026-7101',
      clientId: 'client-1',
      clientName: 'NOVACARE LIMITED',
      customerName: 'Alhaji Ibrahim Usman',
      customerPhone: '08031234567',
      distributionCenterId: 'dc-1',
      distributionCenterName: 'Central Command DC',
      deliveryAgentId: 'rider-1',
      deliveryAgentName: 'Oladele Omowaye',
      closerName: 'Telesales Desk A',
      unreadDcCount: 0,
      unreadRiderCount: 0,
      unreadClientCount: 0,
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    const testUser = UserEntity(
      id: 'user-dc-1',
      email: 'dc.operations@novexps.com',
      firstName: 'DC',
      lastName: 'Operations',
      phone: '08012345678',
      role: 'operations_officer',
    );

    final testMessages = [
      OrderConversationMessageEntity(
        id: 'msg-1',
        conversationId: 'conv-test-101',
        orderId: 'ord-test-101',
        senderId: 'rider-1',
        senderName: 'Oladele Omowaye',
        senderRole: ChatSenderRole.deliveryAgent,
        messageBody: 'Hello @Oladele Omowaye package has arrived at customer gate',
        metadata: const {},
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      OrderConversationMessageEntity(
        id: 'msg-2',
        conversationId: 'conv-test-101',
        orderId: 'ord-test-101',
        senderId: 'user-dc-1',
        senderName: 'DC Operations',
        senderRole: ChatSenderRole.dcManager,
        messageBody: 'Understood, proceed with delivery confirmation.',
        metadata: const {
          'reply_to_id': 'msg-1',
          'reply_to_sender': 'Oladele Omowaye',
          'reply_to_body': 'Hello @Oladele Omowaye package has arrived at customer gate',
          'reply_to_type': 'text',
        },
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];

    testWidgets('Verifies borderless input, inline micro profile mention, and quoted reply box', (tester) async {
      final fakeDataSource = EnhancementsFakeChatDataSource(
        conversation: testConversation,
        messages: testMessages,
      );

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
                  messages: testMessages,
                ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderPipelineChatSheet(
                orderId: 'ord-test-101',
                orderNumber: 'NOV-2026-7101',
                customerName: 'Alhaji Ibrahim Usman',
                customerPhone: '08031234567',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Message Input is completely borderless (no OutlineInputBorder)
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.border, equals(InputBorder.none));
      expect(textField.decoration?.enabledBorder, equals(InputBorder.none));
      expect(textField.decoration?.focusedBorder, equals(InputBorder.none));
      expect(textField.decoration?.filled, isFalse);

      // 2. Verify Inline Micro Profile Mention element with bold deep green color
      final mentionFinder = find.text('@Oladele Omowaye');
      expect(mentionFinder, findsWidgets);
      final mentionText = tester.widget<Text>(mentionFinder.first);
      expect(mentionText.style?.fontWeight, equals(FontWeight.w700));
      expect(mentionText.style?.color, equals(const Color(0xFF008069)));

      // 3. Verify Quoted Reply Box inside reply message
      expect(find.text('Oladele Omowaye'), findsWidgets);
      expect(find.text('Hello @Oladele Omowaye package has arrived at customer gate'), findsWidgets);

      // 4. Verify Swipe Right to Reply triggers Replying to banner
      // Fling the first message to the right
      final dismissibleFinder = find.byKey(const ValueKey('swipe_reply_msg-1'));
      expect(dismissibleFinder, findsOneWidget);
      await tester.fling(dismissibleFinder, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();

      // Verify the Replying to banner appeared above the composer
      expect(find.text('Replying to Oladele Omowaye'), findsOneWidget);

      // 5. Verify Long Press triggers WhatsApp Reaction Popup
      final secondMessage = find.text('Understood, proceed with delivery confirmation.');
      await tester.longPress(secondMessage);
      await tester.pumpAndSettle();

      // Verify the 6 WhatsApp reaction emojis and '+' button appear in the floating bar
      expect(find.text('👍'), findsWidgets);
      expect(find.text('❤️'), findsWidgets);
      expect(find.text('😂'), findsWidgets);
      expect(find.text('😮'), findsWidgets);
      expect(find.text('😢'), findsWidgets);
      expect(find.text('🙏'), findsWidgets);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Tap ❤️ reaction to react to the message
      await tester.tap(find.text('❤️').last);
      await tester.pumpAndSettle();

      // Verify reaction badge appears with ❤️ on the message bubble
      expect(find.text('❤️'), findsWidgets);
    });
  });
}
