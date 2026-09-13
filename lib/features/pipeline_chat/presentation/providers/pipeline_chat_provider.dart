import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/entities/order_conversation.dart';
import '../../domain/entities/order_conversation_message.dart';
import '../../data/datasources/pipeline_chat_remote_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/audio_service.dart';

final pipelineChatDataSourceProvider = Provider<PipelineChatRemoteDataSource>((ref) {
  return PipelineChatRemoteDataSourceImpl();
});

class PipelineChatState {
  final OrderConversationEntity? activeConversation;
  final List<OrderConversationMessageEntity> messages;
  final List<OrderConversationEntity> recentConversations;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  const PipelineChatState({
    this.activeConversation,
    this.messages = const [],
    this.recentConversations = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  int getUnreadCountForRole(String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda') || r.contains('driver')) {
      return recentConversations.where((c) => c.unreadRiderCount > 0).length;
    } else if (r.contains('client') || r.contains('merchant') || r.contains('closer')) {
      return recentConversations.where((c) => c.unreadClientCount > 0).length;
    } else if (r.contains('dc') || r.contains('manager') || r.contains('operations')) {
      return recentConversations.where((c) => c.unreadDcCount > 0).length;
    }
    return 0;
  }

  PipelineChatState copyWith({
    OrderConversationEntity? activeConversation,
    List<OrderConversationMessageEntity>? messages,
    List<OrderConversationEntity>? recentConversations,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
  }) {
    return PipelineChatState(
      activeConversation: activeConversation ?? this.activeConversation,
      messages: messages ?? this.messages,
      recentConversations: recentConversations ?? this.recentConversations,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}

class PipelineChatNotifier extends StateNotifier<PipelineChatState> {
  final PipelineChatRemoteDataSource _dataSource;
  final Ref _ref;
  StreamSubscription<List<OrderConversationMessageEntity>>? _streamSub;
  RealtimeChannel? _globalChatMessagesChannel;
  RealtimeChannel? _conversationsChannel;

  PipelineChatNotifier(this._dataSource, this._ref)
      : super(const PipelineChatState()) {
    _setupGlobalChatSubscriptions();

    // Listen for auth state changes to auto-load conversations
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null) {
        loadScopedConversations(silent: true);
      }
    });

    // Initial load if already authenticated
    final user = _ref.read(authProvider).user;
    if (user != null) {
      loadScopedConversations(silent: true);
    }
  }

  void _setupGlobalChatSubscriptions() {
    try {
      final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) return;
      if (!kIsWeb &&
          (Platform.environment.containsKey('FLUTTER_TEST') ||
              Platform.environment.containsKey('TEST_PLATFORM'))) {
        return;
      }

      _globalChatMessagesChannel = Supabase.instance.client
          .channel('public_global_chat_messages_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'order_conversation_messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final authUser = _ref.read(authProvider).user;
              final currentUserId = authUser?.id;
              final senderId = newRecord['sender_id']?.toString();

              // Only play incoming audio chime if sent by someone else
              if (currentUserId == null || senderId != currentUserId) {
                AudioService().playIncomingMessage();
              }

              // Auto-refresh conversation list
              loadScopedConversations(silent: true);
            },
          )
          .subscribe();

      _conversationsChannel = Supabase.instance.client
          .channel('public_conversations_realtime_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_conversations',
            callback: (_) {
              loadScopedConversations(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] ℹ️ Global channels notice: $e');
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _globalChatMessagesChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();
    super.dispose();
  }

  /// Load only the conversations that the currently logged-in account strictly belongs to
  Future<void> loadScopedConversations({bool silent = false}) async {
    final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
    if (binding.contains('test') || binding.contains('automated')) return;

    final authUser = _ref.read(authProvider).user;
    if (authUser == null) {
      state = state.copyWith(recentConversations: const []);
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final convs = await _dataSource.fetchConversationsScoped(
        userRole: authUser.role,
        userId: authUser.id,
        clientId: authUser.clientId,
        distributionCenterId: authUser.distributionCenterId,
        deliveryAgentId: authUser.deliveryAgentId,
        closerId: authUser.closerId,
      );

      if (mounted) {
        state = state.copyWith(
          recentConversations: convs,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Open or load an order conversation by its Order ID
  Future<void> openOrderConversation(String orderId) async {
    _streamSub?.cancel();
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final conv = await _dataSource.getConversationByOrderId(orderId);
      if (conv == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No active chat pipeline found for this order.',
        );
        return;
      }

      final initialMsgs = await _dataSource.fetchMessages(conv.id);

      state = state.copyWith(
        activeConversation: conv,
        messages: initialMsgs,
        isLoading: false,
      );

      // Auto-mark as read for current user role
      final authUser = _ref.read(authProvider).user;
      if (authUser != null) {
        markConversationAsRead(conv.id, authUser.role);
      }

      // Start realtime stream
      _streamSub = _dataSource.streamMessages(conv.id).listen(
        (updatedMsgs) {
          final previousMsgs = state.messages;
          if (previousMsgs.isNotEmpty && updatedMsgs.length > previousMsgs.length) {
            final authUser = _ref.read(authProvider).user;
            final latestMsg = updatedMsgs.last;
            final isMyMsg = (authUser?.id != null && latestMsg.senderId == authUser!.id);
            if (!isMyMsg) {
              AudioService().playIncomingMessage();
            }
          }
          state = state.copyWith(messages: updatedMsgs);
        },
        onError: (err) {
          // Keep current messages if stream drops
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Mark conversation as read for the current role
  Future<void> markConversationAsRead(String conversationId, [String? role]) async {
    final authUser = _ref.read(authProvider).user;
    final userRole = role ?? authUser?.role ?? 'client';

    try {
      await _dataSource.markConversationAsRead(
        conversationId: conversationId,
        userRole: userRole,
      );

      // Optimistic update in state
      final updatedList = state.recentConversations.map((c) {
        if (c.id == conversationId) {
          final r = userRole.toLowerCase();
          if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda')) {
            return c.copyWith(unreadRiderCount: 0);
          } else if (r.contains('dc') || r.contains('manager') || r.contains('operations')) {
            return c.copyWith(unreadDcCount: 0);
          } else {
            return c.copyWith(unreadClientCount: 0);
          }
        }
        return c;
      }).toList();

      state = state.copyWith(recentConversations: updatedList);
    } catch (_) {}
  }

  /// Send a text message in the active conversation
  Future<bool> sendTextMessage(String body) async {
    final conv = state.activeConversation;
    if (conv == null || body.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);
    try {
      final authState = _ref.read(authProvider);
      final user = authState.user;

      String senderName = 'User';
      String? senderId = user?.id;
      String? senderAvatar = user?.avatarUrl;
      ChatSenderRole role = ChatSenderRole.system;

      if (user != null) {
        senderName = user.fullName.trim().isNotEmpty
            ? user.fullName
            : (user.email.split('@').first);

        final rStr = user.role.toLowerCase();
        if (rStr.contains('client')) {
          role = ChatSenderRole.client;
        } else if (rStr.contains('dc') || rStr.contains('admin') || rStr.contains('manager')) {
          role = ChatSenderRole.dcManager;
        } else if (rStr.contains('agent') || rStr.contains('rider')) {
          role = ChatSenderRole.deliveryAgent;
        }
      }

      await _dataSource.sendMessage(
        conversationId: conv.id,
        orderId: conv.orderId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatar,
        senderRole: role,
        messageBody: body.trim(),
      );

      state = state.copyWith(isSending: false);
      AudioService().playMessageSent();
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Transfer Product & Order Ownership
  Future<Map<String, dynamic>> transferProductAndOwnership({
    required String orderId,
    required String newProductId,
    required String newPackageDealId,
    required String newPackageName,
    required int newQuantity,
    required int newPaidQuantity,
    required int newFreeQuantity,
    required double newBasePrice,
    required double newTotalAmount,
    required String transferReason,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final authState = _ref.read(authProvider);
      final user = authState.user;
      final actorName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Operator';
      final actorRole = user?.role ?? 'dc_manager';

      final res = await _dataSource.transferOrderProductAndOwnership(
        orderId: orderId,
        newProductId: newProductId,
        newPackageDealId: newPackageDealId,
        newPackageName: newPackageName,
        newQuantity: newQuantity,
        newPaidQuantity: newPaidQuantity,
        newFreeQuantity: newFreeQuantity,
        newBasePrice: newBasePrice,
        newTotalAmount: newTotalAmount,
        actorName: actorName,
        actorRole: actorRole,
        transferReason: transferReason,
      );

      // Reload active conversation if it matches this order
      if (state.activeConversation?.orderId == orderId) {
        await openOrderConversation(orderId);
      }

      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final pipelineChatProvider =
    StateNotifierProvider<PipelineChatNotifier, PipelineChatState>((ref) {
  final ds = ref.watch(pipelineChatDataSourceProvider);
  return PipelineChatNotifier(ds, ref);
});
