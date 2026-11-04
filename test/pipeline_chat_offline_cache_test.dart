import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/providers/network_provider.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_message_model.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';

class MockOfflineChatDataSource implements PipelineChatRemoteDataSource {
  final OrderConversationEntity conversation;
  final List<OrderConversationMessageEntity> remoteMessages = [];
  bool isOnline = true;
  int sendMessageCallCount = 0;

  MockOfflineChatDataSource({required this.conversation});

  @override
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId) async {
    if (!isOnline) throw Exception('No network connection');
    return conversation;
  }

  @override
  Future<List<OrderConversationEntity>> fetchConversations({
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
  }) async => [conversation];

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
  Future<List<OrderConversationMessageEntity>> fetchMessages(String conversationId) async {
    if (!isOnline) throw Exception('Offline: Failed host lookup');
    return List.from(remoteMessages);
  }

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
    String? clientMessageId,
  }) async {
    if (!isOnline) {
      throw Exception('NetworkException: Client is offline');
    }
    sendMessageCallCount++;
    final serverMsg = OrderConversationMessageModel(
      id: 'server_msg_${DateTime.now().millisecondsSinceEpoch}_$sendMessageCallCount',
      clientMessageId: clientMessageId,
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
      sendState: 'sent',
    );
    remoteMessages.add(serverMsg);
    return serverMsg;
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
  group('Pipeline Chat Offline Caching & Outbox Auto-Sync Suite', () {
    final now = DateTime.now();

    final testConversation = OrderConversationEntity(
      id: 'conv-cache-99',
      orderId: 'ord-cache-99',
      orderNumber: 'NOV-2026-9900',
      clientId: 'client-1',
      clientName: 'NOVACARE LIMITED',
      customerName: 'Madam Grace Okafor',
      customerPhone: '08098765432',
      distributionCenterId: 'dc-1',
      distributionCenterName: 'Central Command DC',
      deliveryAgentId: 'rider-1',
      deliveryAgentName: 'Test Courier Rider',
      closerName: 'Closer Agent',
      unreadDcCount: 0,
      unreadRiderCount: 0,
      unreadClientCount: 0,
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    const testUser = UserEntity(
      id: 'user-closer-1',
      email: 'closer@novacare.com',
      firstName: 'Closer',
      lastName: 'Agent',
      phone: '08011122233',
      role: 'closer',
    );

    test('Optimistic sending enqueues message in outbox with pending status', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final mockDs = MockOfflineChatDataSource(conversation: testConversation);
      mockDs.isOnline = false; // Simulate offline

      final container = ProviderContainer(
        overrides: [
          pipelineChatDataSourceProvider.overrideWithValue(mockDs),
          authProvider.overrideWith((ref) => AuthNotifier(
                loginUseCase: ref.read(loginUseCaseProvider),
                logoutUseCase: ref.read(logoutUseCaseProvider),
                getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
              )..state = const AuthState(user: testUser)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pipelineChatProvider.notifier);
      notifier.state = PipelineChatState(
        activeConversation: testConversation,
        recentConversations: [testConversation],
        messages: const [],
      );

      // Send text message while offline
      final sent = await notifier.sendTextMessage('Hello from offline closer desk!');
      expect(sent, isTrue);

      final state = container.read(pipelineChatProvider);
      expect(state.messages.length, equals(1));
      final pendingMsg = state.messages.first;
      expect(pendingMsg.messageBody, equals('Hello from offline closer desk!'));
      expect(pendingMsg.sendState, equals('pending'));
      expect(pendingMsg.isPending, isTrue);
      expect(pendingMsg.isSent, isFalse);
      expect(pendingMsg.clientMessageId, isNotNull);
      expect(state.pendingOutboxCount, equals(1));

      // Verify message is saved to local outbox storage
      final localStorage = container.read(localStorageServiceProvider);
      final outbox = await localStorage.getOutboxMessages(conversationId: testConversation.id);
      expect(outbox.length, equals(1));
      expect(outbox.first['client_message_id'], equals(pendingMsg.clientMessageId));
      expect(outbox.first['message_body'], equals('Hello from offline closer desk!'));

      // Now restore connection and trigger flushOutbox
      mockDs.isOnline = true;
      await notifier.flushOutbox(testConversation.id);

      // Verify outbox was dispatched and cleared
      final remainingOutbox = await localStorage.getOutboxMessages(conversationId: testConversation.id);
      expect(remainingOutbox.isEmpty, isTrue);

      final syncedState = container.read(pipelineChatProvider);
      expect(syncedState.pendingOutboxCount, equals(0));
      expect(syncedState.messages.length, equals(1));
      final syncedMsg = syncedState.messages.first;
      expect(syncedMsg.isSent, isTrue);
      expect(syncedMsg.sendState, equals('sent'));
      expect(mockDs.sendMessageCallCount, equals(1));
    });

    test('Offline Voice Note and Image Attachment queue with local data URIs and render', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final mockDs = MockOfflineChatDataSource(conversation: testConversation);
      mockDs.isOnline = false; // Offline

      final container = ProviderContainer(
        overrides: [
          pipelineChatDataSourceProvider.overrideWithValue(mockDs),
          authProvider.overrideWith((ref) => AuthNotifier(
                loginUseCase: ref.read(loginUseCaseProvider),
                logoutUseCase: ref.read(logoutUseCaseProvider),
                getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
              )..state = const AuthState(user: testUser)),
        ],
      );
      addTearDown(container.dispose);

      // Explicitly mark network as offline
      container.read(networkProvider.notifier).setOfflineManually(true);

      final notifier = container.read(pipelineChatProvider.notifier);
      notifier.state = PipelineChatState(
        activeConversation: testConversation,
        recentConversations: [testConversation],
        messages: const [],
      );

      // 1. Send offline voice note
      final dummyAudioBytes = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x02, 0x03]);
      final vnSent = await notifier.sendVoiceNote(
        audioBytes: dummyAudioBytes,
        duration: const Duration(seconds: 14),
        mimeType: 'audio/webm',
      );
      expect(vnSent, isTrue);

      // 2. Send offline image attachment
      final dummyImageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final imgSent = await notifier.sendFileAttachment(
        fileBytes: dummyImageBytes,
        fileName: 'waybill_proof.png',
        mimeType: 'image/png',
        caption: 'Package proof photo',
        isImage: true,
      );
      expect(imgSent, isTrue);

      final state = container.read(pipelineChatProvider);
      expect(state.messages.length, equals(2));

      final vnMsg = state.messages.first;
      expect(vnMsg.isVoiceNote, isTrue);
      expect(vnMsg.isPending, isTrue);
      expect(vnMsg.voiceNoteUrl, startsWith('data:audio/webm;base64,'));
      expect(vnMsg.voiceNoteDuration, equals(14));

      final imgMsg = state.messages.last;
      expect(imgMsg.isImage, isTrue);
      expect(imgMsg.isPending, isTrue);
      expect(imgMsg.fileUrl, startsWith('data:image/png;base64,'));
      expect(imgMsg.fileName, equals('waybill_proof.png'));

      // Check persistent outbox queue holds both items with base64_media
      final localStorage = container.read(localStorageServiceProvider);
      final outbox = await localStorage.getOutboxMessages(conversationId: testConversation.id);
      expect(outbox.length, equals(2));
      expect(outbox[0]['base64_media'], equals(base64Encode(dummyAudioBytes)));
      expect(outbox[1]['base64_media'], equals(base64Encode(dummyImageBytes)));
    });

    testWidgets('UI renders pending clock icon, double checks for sent, and outbox sync banner', (tester) async {
      final mockDs = MockOfflineChatDataSource(conversation: testConversation);

      final pendingMsg = OrderConversationMessageEntity(
        id: 'msg-pending-1',
        clientMessageId: 'cmsg-123',
        conversationId: testConversation.id,
        orderId: testConversation.orderId,
        senderId: testUser.id,
        senderName: 'Closer Agent',
        senderRole: ChatSenderRole.closer,
        messageBody: 'Customer agreed to deliver at 3:00 PM today.',
        sendState: 'pending',
        createdAt: DateTime.now(),
      );

      final sentMsg = OrderConversationMessageEntity(
        id: 'msg-sent-2',
        clientMessageId: 'cmsg-456',
        conversationId: testConversation.id,
        orderId: testConversation.orderId,
        senderId: testUser.id,
        senderName: 'Closer Agent',
        senderRole: ChatSenderRole.closer,
        messageBody: 'Confirmed address is Plot 44 Central Area.',
        sendState: 'sent',
        readByDc: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pipelineChatDataSourceProvider.overrideWithValue(mockDs),
            authProvider.overrideWith((ref) => AuthNotifier(
                  loginUseCase: ref.read(loginUseCaseProvider),
                  logoutUseCase: ref.read(logoutUseCaseProvider),
                  getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
                )..state = const AuthState(user: testUser)),
            pipelineChatProvider.overrideWith(
              (ref) => PipelineChatNotifier(
                mockDs,
                ref,
              )..state = PipelineChatState(
                  recentConversations: [testConversation],
                  activeConversation: testConversation,
                  messages: [sentMsg, pendingMsg],
                  pendingOutboxCount: 1,
                ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderPipelineChatSheet(
                orderId: 'ord-cache-99',
                orderNumber: 'NOV-2026-9900',
                customerName: 'Madam Grace Okafor',
                customerPhone: '08098765432',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Outbox Sync Banner displays pending count
      expect(find.text('1 message queued • Auto-syncing when online'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);

      // 2. Verify Pending Message renders clock icon
      final clockIconFinder = find.byIcon(Icons.access_time_rounded);
      expect(clockIconFinder, findsOneWidget);

      // 3. Verify Sent Message renders double checkmarks
      final checkmarksFinder = find.byIcon(Icons.done_all_rounded);
      expect(checkmarksFinder, findsWidgets);
    });
  });
}
