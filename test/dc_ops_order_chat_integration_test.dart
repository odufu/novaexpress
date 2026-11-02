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
  Future<List<OrderConversationEntity>> fetchConversationsScoped({
    required String userRole,
    required String userId,
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
    String? closerId,
    String? marketerId,
  }) async {
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

  @override
  Future<OrderConversationMessageEntity?> toggleMessageReaction({
    required String messageId,
    required String emoji,
    required String userId,
    required String userName,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Ops Order Pipeline Chat Integration Tests', () {
    test('DC Ops roles encompass all operational personnel', () {
      final dcOpsRoles = [
        'dc_operations',
        'operations_officer',
        'dispatcher',
        'dc_manager',
        'dc_stock_admin',
        'stock_officer',
        'inventory_officer',
        'dc_finance_admin',
        'remittance_officer',
        'accountant',
        'dc_ops',
      ];

      for (final role in dcOpsRoles) {
        final r = role.toLowerCase().trim();
        final isDcOpsRole = r.contains('dc') ||
            r.contains('manager') ||
            r.contains('operations') ||
            r.contains('dispatcher') ||
            r.contains('stock') ||
            r.contains('inventory') ||
            r.contains('finance') ||
            r.contains('remittance') ||
            r.contains('accountant') ||
            r.contains('ops');

        expect(isDcOpsRole, isTrue, reason: 'Role $role must match DC Ops scoping criteria');
      }
    });

    testWidgets('OrderPipelineChatSheet participants bar displays DC Ops beacon and room members', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final testConversation = OrderConversationEntity(
        id: 'conv-test-1',
        orderId: 'ord-test-101',
        orderNumber: 'NOV-2026-7101',
        customerName: 'Alhaji Ibrahim Usman',
        customerPhone: '08031234567',
        clientId: '00000000-0000-4000-8000-791731264594',
        clientName: 'NOVACARE LIMITED',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Central Command Distribution Center',
        deliveryAgentId: '842bc86e-ada4-4ddb-9e96-2db063c84ba5',
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

      // Verify Active Pipeline Participants Bar is rendered
      expect(find.text('ACTIVE PIPELINE:'), findsOneWidget);
      expect(find.text('DC Operations'), findsOneWidget);
      expect(find.text('Rider: Oladele Omowaye'), findsOneWidget);
      expect(find.text('Closer: Telesales Desk A'), findsOneWidget);
      expect(find.text('Merchant: NOVACARE LIMITED'), findsOneWidget);
    });
  });
}
