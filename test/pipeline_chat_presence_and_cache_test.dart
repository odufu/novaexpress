import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/chat_presence_info.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';

void main() {
  group('ChatPresenceInfo Entity & Display Formatting Tests', () {
    test('Formats Rider typing status correctly', () {
      final info = ChatPresenceInfo(
        senderId: 'rider-01',
        senderName: 'Samuel Okon',
        senderRole: 'rider',
        status: 'typing',
        timestamp: DateTime.now(),
      );

      expect(info.isTyping, isTrue);
      expect(info.isRecording, isFalse);
      expect(info.isActive, isTrue);
      expect(info.displayRole, 'Rider');
      expect(info.displayLabel, 'Rider is typing...');
    });

    test('Formats Dispatch Ops voice recording status correctly', () {
      final info = ChatPresenceInfo(
        senderId: 'dc-01',
        senderName: 'Chinedu Eze',
        senderRole: 'operations_officer',
        status: 'recording_voice_note',
        timestamp: DateTime.now(),
      );

      expect(info.isTyping, isFalse);
      expect(info.isRecording, isTrue);
      expect(info.isActive, isTrue);
      expect(info.displayRole, 'Dispatch Ops');
      expect(info.displayLabel, 'Dispatch Ops is recording audio...');
    });

    test('Formats Closer typing status correctly', () {
      final info = ChatPresenceInfo(
        senderId: 'closer-01',
        senderName: 'Amina Bello',
        senderRole: 'sales_closer',
        status: 'typing',
        timestamp: DateTime.now(),
      );

      expect(info.isTyping, isTrue);
      expect(info.isRecording, isFalse);
      expect(info.isActive, isTrue);
      expect(info.displayRole, 'Closer');
      expect(info.displayLabel, 'Closer is typing...');
    });

    test('Idle status is not active', () {
      final info = ChatPresenceInfo(
        senderId: 'rider-01',
        senderName: 'Samuel Okon',
        senderRole: 'rider',
        status: 'idle',
        timestamp: DateTime.now(),
      );

      expect(info.isTyping, isFalse);
      expect(info.isRecording, isFalse);
      expect(info.isActive, isFalse);
    });

    test('Serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final original = ChatPresenceInfo(
        senderId: 'user-123',
        senderName: 'Test User',
        senderRole: 'finance_ops',
        status: 'recording_voice_note',
        timestamp: now,
      );

      final json = original.toJson();
      final restored = ChatPresenceInfo.fromJson(json);

      expect(restored.senderId, original.senderId);
      expect(restored.senderName, original.senderName);
      expect(restored.senderRole, original.senderRole);
      expect(restored.status, original.status);
      expect(restored.displayRole, 'Finance Ops');
      expect(restored.displayLabel, 'Finance Ops is recording audio...');
    });
  });

  group('PipelineChatState Multi-Order Message Caching Tests', () {
    test('State caches and retrieves messages by orderId cleanly without clearing', () {
      final now = DateTime.now();
      final msg1 = OrderConversationMessageEntity(
        id: 'msg-1',
        conversationId: 'conv-1',
        orderId: 'order-101',
        senderId: 'user-1',
        senderName: 'Sender 1',
        senderRole: ChatSenderRole.dcManager,
        messageBody: 'Hello Order 101',
        metadata: const {},
        createdAt: now,
      );

      final msg2 = OrderConversationMessageEntity(
        id: 'msg-2',
        conversationId: 'conv-2',
        orderId: 'order-202',
        senderId: 'user-2',
        senderName: 'Sender 2',
        senderRole: ChatSenderRole.deliveryAgent,
        messageBody: 'Hello Order 202',
        metadata: const {},
        createdAt: now,
      );

      final state = PipelineChatState(
        messagesByOrderId: {
          'order-101': [msg1],
          'order-202': [msg2],
        },
      );

      // Verify retrieval for order-101
      final order101Messages = state.getMessagesForOrder('order-101');
      expect(order101Messages.length, 1);
      expect(order101Messages.first.messageBody, 'Hello Order 101');

      // Verify retrieval for order-202
      final order202Messages = state.getMessagesForOrder('order-202');
      expect(order202Messages.length, 1);
      expect(order202Messages.first.messageBody, 'Hello Order 202');

      // Verify empty retrieval for uncached order
      final unknownMessages = state.getMessagesForOrder('order-999');
      expect(unknownMessages, isEmpty);
    });

    test('copyWith sentinel clears activePresence when requested', () {
      final info = ChatPresenceInfo(
        senderId: 'rider-01',
        senderName: 'Samuel Okon',
        senderRole: 'rider',
        status: 'typing',
        timestamp: DateTime.now(),
      );

      final stateWithPresence = PipelineChatState(activePresence: info);
      expect(stateWithPresence.activePresence, isNotNull);

      // Clear presence using copyWith(activePresence: null)
      final clearedState = stateWithPresence.copyWith(activePresence: null);
      expect(clearedState.activePresence, isNull);
    });
  });
}

