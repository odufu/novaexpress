import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/pipeline_chat/data/datasources/pipeline_chat_remote_datasource.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation_message.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Order Pipeline Chat Lifecycle Integration Suite (Live Remote Supabase)', () {
    late SupabaseClient client;
    late PipelineChatRemoteDataSourceImpl chatDataSource;
    String? testOrderId;

    setUp(() async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      chatDataSource = PipelineChatRemoteDataSourceImpl(client);

      // Fetch a real active order from remote Supabase orders table
      final orders = await client
          .from(SupabaseConstants.ordersTable)
          .select('id, order_number, customer_name, client_id, client_name')
          .limit(1);

      if ((orders as List).isNotEmpty) {
        testOrderId = orders.first['id'].toString();
      }
    });

    tearDown(() {
      client.dispose();
    });

    test('1. Get or auto-initialize conversation pipeline for an order', () async {
      expect(testOrderId, isNotNull, reason: 'Remote database must have at least one order');

      final conversation = await chatDataSource.getConversationByOrderId(testOrderId!);
      expect(conversation, isNotNull);
      expect(conversation!.orderId, equals(testOrderId));
      expect(conversation.orderNumber.isNotEmpty, isTrue);
      expect(conversation.customerName.isNotEmpty, isTrue);
    });

    test('2. Send and persist messages from Delivery Agent and Client roles', () async {
      final conversation = await chatDataSource.getConversationByOrderId(testOrderId!);
      expect(conversation, isNotNull);

      final uniqueRiderText = 'Rider at customer gate - verification test ${DateTime.now().millisecondsSinceEpoch}';
      final riderMsg = await chatDataSource.sendMessage(
        conversationId: conversation!.id,
        orderId: testOrderId!,
        senderName: 'Emeka Rider (PDA-7000)',
        senderRole: ChatSenderRole.deliveryAgent,
        messageBody: uniqueRiderText,
      );

      expect(riderMsg.id.isNotEmpty, isTrue);
      expect(riderMsg.messageBody, equals(uniqueRiderText));
      expect(riderMsg.senderRole, equals(ChatSenderRole.deliveryAgent));

      final uniqueClientText = 'Noted Emeka, customer requested to call before buzzer.';
      final clientMsg = await chatDataSource.sendMessage(
        conversationId: conversation.id,
        orderId: testOrderId!,
        senderName: 'Merchant Operations',
        senderRole: ChatSenderRole.client,
        messageBody: uniqueClientText,
      );

      expect(clientMsg.id.isNotEmpty, isTrue);
      expect(clientMsg.messageBody, equals(uniqueClientText));
      expect(clientMsg.senderRole, equals(ChatSenderRole.client));
    });

    test('3. Fetch chronological messages and verify latest preview sync', () async {
      final conversation = await chatDataSource.getConversationByOrderId(testOrderId!);
      expect(conversation, isNotNull);

      final messages = await chatDataSource.fetchMessages(conversation!.id);
      expect(messages.isNotEmpty, isTrue);
      expect(messages.length, greaterThanOrEqualTo(2));

      // Verify chronological order
      for (int i = 0; i < messages.length - 1; i++) {
        expect(
          messages[i].createdAt.isBefore(messages[i + 1].createdAt) ||
              messages[i].createdAt.isAtSameMomentAs(messages[i + 1].createdAt),
          isTrue,
        );
      }

      // Verify parent conversation preview was updated
      final refreshedConv = await chatDataSource.getConversationByOrderId(testOrderId!);
      expect(refreshedConv!.lastMessageText, isNotNull);
      expect(refreshedConv.lastMessageSenderName, isNotNull);
    });

    test('4. Fetch conversations scoped by client or distribution center', () async {
      final conversations = await chatDataSource.fetchConversations();
      expect(conversations.isNotEmpty, isTrue);
      expect(conversations.any((c) => c.orderId == testOrderId), isTrue);
    });
  });
}
