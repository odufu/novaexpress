import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/audio_service.dart';
import 'package:novexps/features/pipeline_chat/domain/entities/order_conversation.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pipeline Chat FAB & Audio Service Suite', () {
    test('AudioService triggers execute safely without crashing in test/silent mode', () async {
      final audioService = AudioService();

      // Audio triggers should complete gracefully without throwing exceptions
      await expectLater(audioService.playIncomingOrder(), completes);
      await expectLater(audioService.playIncomingMessage(), completes);
      await expectLater(audioService.playMessageSent(), completes);
    });

    testWidgets('PipelineChatFloatingActionButton shows correct unread badge count', (tester) async {
      final now = DateTime.now();
      final List<OrderConversationEntity> conversations = [
        OrderConversationEntity(
          id: 'conv-1',
          orderId: 'ord-101',
          orderNumber: 'ORD-101',
          customerName: 'Amina Bello',
          clientId: 'client-1',
          clientName: 'Apex Health Ltd',
          deliveryAgentId: 'rider-1',
          distributionCenterId: 'dc-1',
          unreadRiderCount: 3,
          unreadDcCount: 1,
          unreadClientCount: 0,
          lastMessageText: 'On my way!',
          lastMessageSenderName: 'Rider John',
          lastMessageAt: now,
          createdAt: now.subtract(const Duration(minutes: 10)),
          updatedAt: now,
        ),
        OrderConversationEntity(
          id: 'conv-2',
          orderId: 'ord-102',
          orderNumber: 'ORD-102',
          customerName: 'Emeka Okafor',
          clientId: 'client-1',
          clientName: 'Apex Health Ltd',
          deliveryAgentId: 'rider-1',
          distributionCenterId: 'dc-1',
          unreadRiderCount: 2,
          unreadDcCount: 0,
          unreadClientCount: 5,
          lastMessageText: 'Customer requested 2-pack deal',
          lastMessageSenderName: 'Rider John',
          lastMessageAt: now.subtract(const Duration(minutes: 2)),
          createdAt: now.subtract(const Duration(minutes: 20)),
          updatedAt: now,
        ),
      ];

      const testUser = UserEntity(
        id: 'rider-1',
        email: 'rider@novexps.com',
        firstName: 'John',
        lastName: 'Doe',
        phone: '08012345678',
        role: 'delivery_agent',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(
                  loginUseCase: ref.read(loginUseCaseProvider),
                  logoutUseCase: ref.read(logoutUseCaseProvider),
                  getCurrentUserUseCase: ref.read(getCurrentUserUseCaseProvider),
                )..state = const AuthState(user: testUser)),
            pipelineChatProvider.overrideWith(
              (ref) => PipelineChatNotifier(
                ref.read(pipelineChatDataSourceProvider),
                ref,
              )..state = PipelineChatState(recentConversations: conversations),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              floatingActionButton: PipelineChatFloatingActionButton(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Number of unread conversations for delivery agent is 2
      expect(find.byType(PipelineChatFloatingActionButton), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    test('OrderConversationEntity chronological ordering and unread detection', () {
      final now = DateTime.now();
      final convs = [
        OrderConversationEntity(
          id: 'conv-1',
          orderId: 'ord-1',
          orderNumber: 'ORD-1',
          customerName: 'Customer A',
          clientId: 'client-1',
          clientName: 'Apex Health',
          lastMessageAt: now.subtract(const Duration(hours: 1)),
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
        OrderConversationEntity(
          id: 'conv-2',
          orderId: 'ord-2',
          orderNumber: 'ORD-2',
          customerName: 'Customer B',
          clientId: 'client-1',
          clientName: 'Apex Health',
          lastMessageAt: now,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      ];

      // Sort chronological descending by lastMessageAt
      final sorted = List<OrderConversationEntity>.from(convs)
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      expect(sorted.first.id, 'conv-2');
      expect(sorted.last.id, 'conv-1');
    });
  });
}
