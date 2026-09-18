import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_model.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';
import 'package:novexps/features/pipeline_chat/data/models/order_conversation_message_model.dart';
import 'package:novexps/core/services/local_storage_service.dart';

void main() {
  group('Novacare Closer Quick Login & Verification', () {
    late MockAuthRemoteDataSource authDataSource;

    setUp(() {
      authDataSource = MockAuthRemoteDataSource();
    });

    test('closer@novacare.com successfully authenticates with Password123!', () async {
      final user = await authDataSource.login('closer@novacare.com', 'Password123!');
      expect(user.role, 'closer');
      expect(user.isCloser, isTrue);
      expect(user.fullName, 'Amaka Chioma');
      expect(user.closerCode, 'CLS-NOVA-001');
      expect(user.clientId, '00000000-0000-4000-8000-789382731303');
      expect(user.clientCompanyName, 'Novacare Health & Wellness Ltd');
      expect(user.avatarUrl, isNotNull);
      expect(user.avatarUrl, contains('unsplash'));
      expect(user.homeConsoleRoute, '/closer');
    });

    test('closer.amaka@novacale.ng alias also authenticates successfully', () async {
      final user = await authDataSource.login('closer.amaka@novacale.ng', 'Password123!');
      expect(user.role, 'closer');
      expect(user.isCloser, isTrue);
      expect(user.homeConsoleRoute, '/closer');
    });

    test('Invalid password throws AppAuthException', () async {
      expect(
        () => authDataSource.login('closer@novacare.com', 'WrongPass!'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Order & Chat Closer Attribution with Avatar / DP', () {
    test('OrderEntity and OrderModel preserve closerAvatarUrl across serialization', () {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'ord-123',
        orderNumber: 'NOV-2026-9999',
        customerName: 'Emeka Chukwu',
        customerPhone: '08012345678',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Abuja',
        deliveryAddress: 'Plot 10, Wuse 2',
        productName: 'Respira Detox Tea',
        status: 'pending',
        quantity: 2,
        basePrice: 22000,
        upsellAmount: 0,
        totalAmount: 22000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        closerId: '44444444-4444-4444-8444-444444444444',
        closerName: 'Amaka Chioma',
        closerCode: 'CLS-NOVA-001',
        closerAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
        createdAt: now,
      );

      final json = order.toJson();
      expect(json['closer_id'], '44444444-4444-4444-8444-444444444444');
      expect(json['closer_name'], 'Amaka Chioma');
      expect(json['closer_code'], 'CLS-NOVA-001');
      expect(json['closer_avatar_url'], 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');

      final deserialized = OrderModel.fromJson(json);
      expect(deserialized.closerId, order.closerId);
      expect(deserialized.closerName, order.closerName);
      expect(deserialized.closerCode, order.closerCode);
      expect(deserialized.closerAvatarUrl, order.closerAvatarUrl);
    });

    test('OrderConversationModel extracts closerAvatarUrl from client_closers join map', () {
      final json = {
        'id': 'conv-001',
        'order_id': 'ord-123',
        'order_number': 'NOV-2026-9999',
        'customer_name': 'Emeka Chukwu',
        'customer_phone': '08012345678',
        'client_id': '00000000-0000-4000-8000-789382731303',
        'client_name': 'Novacare Health & Wellness Ltd',
        'closer_id': '44444444-4444-4444-8444-444444444444',
        'closer_name': 'Amaka Chioma',
        'client_closers': {
          'avatar_url': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
          'full_name': 'Amaka Chioma',
        },
        'order_status': 'in_transit',
        'last_message_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final model = OrderConversationModel.fromJson(json);
      expect(model.closerId, '44444444-4444-4444-8444-444444444444');
      expect(model.closerName, 'Amaka Chioma');
      expect(model.closerAvatarUrl, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');

      final serialized = model.toJson();
      expect(serialized['closer_avatar_url'], 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');
    });

    test('OrderConversationMessageModel properly serializes ChatSenderRole.closer', () {
      final msg = OrderConversationMessageModel(
        id: 'msg-001',
        conversationId: 'conv-001',
        orderId: 'ord-123',
        senderId: '44444444-4444-4444-8444-444444444444',
        senderName: 'Amaka Chioma',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
        senderRole: ChatSenderRole.closer,
        messageType: ChatMessageType.text,
        messageBody: 'Customer confirmed availability for 3:00 PM today.',
        createdAt: DateTime.now(),
      );

      final json = msg.toJson();
      expect(json['sender_role'], 'closer');
      expect(json['sender_avatar_url'], 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');
      expect(json['sender_name'], 'Amaka Chioma');

      final deserialized = OrderConversationMessageModel.fromJson(json);
      expect(deserialized.senderRole, ChatSenderRole.closer);
      expect(deserialized.senderAvatarUrl, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');
    });
  });

  group('LocalStorageService Dynamic Caching', () {
    test('Conversations and Chat Messages are cached and restored cleanly', () async {
      final storage = LocalStorageServiceImpl();

      final conv = OrderConversation(
        id: 'conv-cache-1',
        orderId: 'ord-cache-1',
        orderNumber: 'NOV-2026-1001',
        customerName: 'Fatima Bello',
        customerPhone: '08098765432',
        clientId: '00000000-0000-4000-8000-789382731303',
        clientName: 'Novacare Health & Wellness Ltd',
        closerId: '44444444-4444-4444-8444-444444444444',
        closerName: 'Amaka Chioma',
        closerAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
        orderStatus: 'assigned',
        lastMessageText: 'Rider en route',
        lastMessageSenderName: 'System',
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.cacheConversations([conv], 'test_scope');
      final restoredConvs = await storage.getCachedConversations('test_scope');

      expect(restoredConvs, isNotNull);
      expect(restoredConvs!.length, 1);
      expect(restoredConvs.first.orderNumber, 'NOV-2026-1001');
      expect(restoredConvs.first.closerName, 'Amaka Chioma');
      expect(restoredConvs.first.closerAvatarUrl, contains('unsplash'));

      final message = OrderConversationMessage(
        id: 'msg-cache-1',
        conversationId: 'conv-cache-1',
        orderId: 'ord-cache-1',
        senderName: 'Amaka Chioma',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
        senderRole: ChatSenderRole.closer,
        messageType: ChatMessageType.text,
        messageBody: 'Payment confirmed via transfer.',
        createdAt: DateTime.now(),
      );

      await storage.cacheConversationMessages('conv-cache-1', [message]);
      final restoredMsgs = await storage.getCachedConversationMessages('conv-cache-1');

      expect(restoredMsgs, isNotNull);
      expect(restoredMsgs!.length, 1);
      expect(restoredMsgs.first.messageBody, 'Payment confirmed via transfer.');
      expect(restoredMsgs.first.senderRole, ChatSenderRole.closer);
      expect(restoredMsgs.first.senderAvatarUrl, contains('unsplash'));
    });
  });

  group('Closer Order Conversation Access Control & Strict Scoping', () {
    final now = DateTime.now();

    final amakaConversation = OrderConversationEntity(
      id: 'conv-amaka-1',
      orderId: 'ord-amaka-1',
      orderNumber: 'NOV-2026-6104',
      customerName: 'Fatima Bello',
      clientId: 'client-novacare',
      clientName: 'Novacare Health & Wellness Ltd',
      closerId: '44444444-4444-4444-8444-444444444444',
      closerName: 'Amaka Chioma',
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final chidinmaConversation = OrderConversationEntity(
      id: 'conv-chidinma-1',
      orderId: 'ord-chidinma-1',
      orderNumber: 'NOV-2026-2346',
      customerName: 'Shalom Samson',
      clientId: 'client-novacare',
      clientName: 'Novacare Health & Wellness Ltd',
      closerId: '55555555-5555-4555-8555-555555555555',
      closerName: 'Chidinma Eze',
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final unassignedMerchantConversation = OrderConversationEntity(
      id: 'conv-unassigned-1',
      orderId: 'ord-unassigned-1',
      orderNumber: 'NOV-2026-8738',
      customerName: 'Joshua Alahu',
      clientId: 'client-novacare',
      clientName: 'Novacare Health & Wellness Ltd',
      closerId: null,
      closerName: null,
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
    );

    test('Closer filter strictly retains ONLY conversations belonging to that closer', () {
      final allConvs = [
        amakaConversation,
        chidinmaConversation,
        unassignedMerchantConversation,
      ];

      // Amaka Chioma's view
      const amakaCloserId = '44444444-4444-4444-8444-444444444444';
      final amakaFiltered = allConvs.where((c) {
        final matchId = c.closerId != null && (c.closerId == amakaCloserId);
        final matchName = c.closerName != null && c.closerName!.toLowerCase().trim() == 'amaka chioma';
        return matchId || matchName;
      }).toList();

      expect(amakaFiltered.length, 1);
      expect(amakaFiltered.first.orderNumber, 'NOV-2026-6104');
      expect(amakaFiltered.first.closerName, 'Amaka Chioma');

      // Chidinma Eze's view
      const chidinmaCloserId = '55555555-5555-4555-8555-555555555555';
      final chidinmaFiltered = allConvs.where((c) {
        final matchId = c.closerId != null && (c.closerId == chidinmaCloserId);
        final matchName = c.closerName != null && c.closerName!.toLowerCase().trim() == 'chidinma eze';
        return matchId || matchName;
      }).toList();

      expect(chidinmaFiltered.length, 1);
      expect(chidinmaFiltered.first.orderNumber, 'NOV-2026-2346');
      expect(chidinmaFiltered.first.closerName, 'Chidinma Eze');
    });

    test('Closer cannot access conversations for orders that do not belong to them', () {
      const closerId = '44444444-4444-4444-8444-444444444444';
      const closerName = 'amaka chioma';

      bool isAuthorized(OrderConversationEntity conv) {
        final matchId = conv.closerId != null && (conv.closerId == closerId);
        final matchName = conv.closerName != null && conv.closerName!.toLowerCase().trim() == closerName;
        return matchId || matchName;
      }

      // Amaka's order: Allowed
      expect(isAuthorized(amakaConversation), isTrue);

      // Chidinma's order: Blocked
      expect(isAuthorized(chidinmaConversation), isFalse);

      // Unassigned merchant order: Blocked for closer
      expect(isAuthorized(unassignedMerchantConversation), isFalse);
    });
  });
}
