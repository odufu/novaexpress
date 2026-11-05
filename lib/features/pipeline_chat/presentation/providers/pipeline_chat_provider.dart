import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/entities/order_conversation.dart';
import '../../domain/entities/order_conversation_message.dart';
import '../../domain/entities/chat_presence_info.dart';
import '../../data/models/order_conversation_message_model.dart';
import '../../data/services/chat_storage_service.dart';
import '../../data/datasources/pipeline_chat_remote_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/providers/network_provider.dart';

final pipelineChatDataSourceProvider = Provider<PipelineChatRemoteDataSource>((ref) {
  return PipelineChatRemoteDataSourceImpl();
});

class PipelineChatState {
  static const Object _unset = Object();

  final OrderConversationEntity? activeConversation;
  final List<OrderConversationMessageEntity> messages;
  final List<OrderConversationEntity> recentConversations;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final int pendingOutboxCount;
  final ChatPresenceInfo? activePresence;
  final Map<String, List<OrderConversationMessageEntity>> messagesByOrderId;

  const PipelineChatState({
    this.activeConversation,
    this.messages = const [],
    this.recentConversations = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.pendingOutboxCount = 0,
    this.activePresence,
    this.messagesByOrderId = const {},
  });

  List<OrderConversationMessageEntity> getMessagesForOrder(String orderId) {
    if (activeConversation?.orderId == orderId && messages.isNotEmpty) {
      return messages;
    }
    return messagesByOrderId[orderId] ??
        (activeConversation?.id != null ? messagesByOrderId[activeConversation!.id] : null) ??
        const [];
  }

  int getUnreadCountForRole(String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda') || r.contains('driver')) {
      return recentConversations.where((c) => c.unreadRiderCount > 0).length;
    } else if (r.contains('client') || r.contains('merchant') || r.contains('closer') || r.contains('marketer')) {
      return recentConversations.where((c) => c.unreadClientCount > 0).length;
    } else if (r.contains('dc') ||
        r.contains('manager') ||
        r.contains('operations') ||
        r.contains('dispatcher') ||
        r.contains('stock') ||
        r.contains('inventory') ||
        r.contains('finance') ||
        r.contains('remittance') ||
        r.contains('accountant') ||
        r.contains('ops')) {
      return recentConversations.where((c) => c.unreadDcCount > 0).length;
    }
    return 0;
  }

  int get totalUnreadCount => recentConversations.fold<int>(0, (sum, c) => sum + c.unreadClientCount);

  PipelineChatState copyWith({
    OrderConversationEntity? activeConversation,
    List<OrderConversationMessageEntity>? messages,
    List<OrderConversationEntity>? recentConversations,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    int? pendingOutboxCount,
    Object? activePresence = _unset,
    Map<String, List<OrderConversationMessageEntity>>? messagesByOrderId,
  }) {
    return PipelineChatState(
      activeConversation: activeConversation ?? this.activeConversation,
      messages: messages ?? this.messages,
      recentConversations: recentConversations ?? this.recentConversations,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      activePresence: identical(activePresence, _unset)
          ? this.activePresence
          : (activePresence as ChatPresenceInfo?),
      messagesByOrderId: messagesByOrderId ?? this.messagesByOrderId,
    );
  }
}

class PipelineChatNotifier extends StateNotifier<PipelineChatState> {
  final PipelineChatRemoteDataSource _dataSource;
  final Ref _ref;
  StreamSubscription<List<OrderConversationMessageEntity>>? _streamSub;
  RealtimeChannel? _globalChatMessagesChannel;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _conversationPresenceChannel;
  ChatPresenceInfo? _activePresence;
  Timer? _presenceExpireTimer;
  DateTime? _lastTypingBroadcast;
  Timer? _outboxFlushTimer;
  bool _isFlushingOutbox = false;

  ChatPresenceInfo? get activePresence => _activePresence;

  PipelineChatNotifier(this._dataSource, this._ref)
      : super(const PipelineChatState()) {
    _setupGlobalChatSubscriptions();

    // Listen for auth state changes to auto-load conversations
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null) {
        loadScopedConversations(silent: true);
      }
    });

    // Listen for network connectivity to auto-flush outbox queue upon reconnecting
    _ref.listen<NetworkState>(networkProvider, (previous, next) {
      if (next.isOnline && (previous?.isOnline == false || previous == null)) {
        debugPrint('[PIPELINE_CHAT] 🌐 Internet connectivity restored. Initiating automatic outbox sync...');
        flushOutbox();
      }
    });

    // Periodic background sync timer (every 15s) when online
    if (!const bool.fromEnvironment('flutter.test')) {
      _outboxFlushTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _ref.read(networkProvider).isOnline) {
          flushOutbox();
        }
      });
    }

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

  void _setupConversationPresenceChannel(String conversationId) {
    _conversationPresenceChannel?.unsubscribe();
    _activePresence = null;
    _presenceExpireTimer?.cancel();
    state = state.copyWith(activePresence: null);

    try {
      final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) return;

      final channelName = 'presence_chat_$conversationId';
      _conversationPresenceChannel = Supabase.instance.client.channel(channelName);

      _conversationPresenceChannel!
          .onBroadcast(
            event: 'user_presence',
            callback: (payload) {
              final authUser = _ref.read(authProvider).user;
              final currentUserId = authUser?.id;
              final senderId = payload['sender_id']?.toString();

              if (senderId != null && senderId == currentUserId) return;

              final status = payload['status']?.toString() ?? 'idle';
              final senderName = payload['sender_name']?.toString() ?? 'Participant';
              final senderRole = payload['sender_role']?.toString() ?? 'user';

              if (status == 'idle') {
                _presenceExpireTimer?.cancel();
                _activePresence = null;
                state = state.copyWith(activePresence: null);
              } else {
                final info = ChatPresenceInfo(
                  senderId: senderId ?? '',
                  senderName: senderName,
                  senderRole: senderRole,
                  status: status,
                  timestamp: DateTime.now(),
                );

                _presenceExpireTimer?.cancel();
                _activePresence = info;
                state = state.copyWith(activePresence: info);

                // Auto-expire after 4 seconds if no heartbeat received
                _presenceExpireTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted && _activePresence?.senderId == senderId) {
                    _activePresence = null;
                    state = state.copyWith(activePresence: null);
                  }
                });
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Presence channel notice: $e');
    }
  }

  void broadcastUserPresence({
    required String conversationId,
    required String status,
  }) {
    final authUser = _ref.read(authProvider).user;
    if (authUser == null) return;

    if (status == 'typing') {
      final now = DateTime.now();
      if (_lastTypingBroadcast != null &&
          now.difference(_lastTypingBroadcast!).inMilliseconds < 1500) {
        return;
      }
      _lastTypingBroadcast = now;
    } else {
      _lastTypingBroadcast = null;
    }

    try {
      final channel = _conversationPresenceChannel ??
          Supabase.instance.client.channel('presence_chat_$conversationId');

      channel.sendBroadcastMessage(
        event: 'user_presence',
        payload: {
          'sender_id': authUser.id,
          'sender_name': authUser.fullName,
          'sender_role': authUser.isCloser ? 'closer' : authUser.role,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] broadcastUserPresence notice: $e');
    }
  }

  @override
  void dispose() {
    _presenceExpireTimer?.cancel();
    _conversationPresenceChannel?.unsubscribe();
    _outboxFlushTimer?.cancel();
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

    final isMarketer = authUser.role.toLowerCase().contains('marketer');
    String? targetDcId = authUser.distributionCenterId;
    if ((targetDcId == null || targetDcId.isEmpty) && (authUser.isDcOperations || authUser.isDcManager)) {
      try {
        final dcState = _ref.read(dcConsoleProvider);
        targetDcId = dcState.activeHubId;
        if (targetDcId.isEmpty) {
          targetDcId = dcState.distributionCenters.firstOrNull?.id;
        }
      } catch (_) {}
    }

    final scopeKey = authUser.isCloser
        ? 'closer_${authUser.closerId ?? authUser.id}'
        : (isMarketer
            ? 'marketer_${authUser.marketerId ?? authUser.id}'
            : (authUser.clientId ?? targetDcId ?? authUser.id));

    final localStorage = _ref.read(localStorageServiceProvider);

    // Fast-path: Load cached conversations instantly
    try {
      final cached = await localStorage.getCachedConversations(scopeKey);
      if (cached != null && cached.isNotEmpty && mounted) {
        state = state.copyWith(recentConversations: cached);
      }
    } catch (_) {}

    if (!silent && state.recentConversations.isEmpty) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final convs = await _dataSource.fetchConversationsScoped(
        userRole: authUser.role,
        userId: authUser.id,
        clientId: authUser.clientId,
        distributionCenterId: targetDcId,
        deliveryAgentId: authUser.deliveryAgentId,
        closerId: authUser.closerId ?? (authUser.isCloser ? authUser.id : null),
        marketerId: isMarketer ? (authUser.marketerId ?? authUser.id) : null,
      );

      // Defense-in-depth: Filter by closer or marketer ownership
      final filteredConvs = authUser.isCloser
          ? convs.where((c) {
              final closerId = authUser.closerId ?? authUser.id;
              final closerName = authUser.fullName.trim().toLowerCase();
              final matchId = c.closerId != null && (c.closerId == closerId || c.closerId == authUser.id);
              final matchName = closerName.isNotEmpty && c.closerName != null && c.closerName!.trim().toLowerCase() == closerName;
              return matchId || matchName;
            }).toList()
          : (isMarketer
              ? convs.where((c) {
                  final mId = authUser.marketerId ?? authUser.id;
                  final mName = authUser.fullName.trim().toLowerCase();
                  final matchId = c.marketerId != null && (c.marketerId == mId || c.marketerId == authUser.id);
                  final matchName = mName.isNotEmpty && c.marketerName != null && c.marketerName!.trim().toLowerCase() == mName;
                  return matchId || matchName;
                }).toList()
              : convs);

      if (mounted) {
        state = state.copyWith(
          recentConversations: filteredConvs,
          isLoading: false,
        );
        unawaited(localStorage.cacheConversations(filteredConvs, scopeKey));
      }
    } catch (e) {
      if (mounted && !silent) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  static ChatSenderRole _parseSenderRole(String? roleStr) {
    final rStr = roleStr?.toLowerCase() ?? '';
    if (rStr == 'client') return ChatSenderRole.client;
    if (rStr == 'closer' || rStr == 'client_closer') return ChatSenderRole.closer;
    if (rStr == 'marketer' || rStr == 'digital_marketer') return ChatSenderRole.marketer;
    if (rStr == 'dc_manager' || rStr == 'dc') return ChatSenderRole.dcManager;
    if (rStr == 'delivery_agent' || rStr == 'rider') return ChatSenderRole.deliveryAgent;
    return ChatSenderRole.system;
  }

  static String _roleToString(ChatSenderRole role) {
    switch (role) {
      case ChatSenderRole.client: return 'client';
      case ChatSenderRole.closer: return 'closer';
      case ChatSenderRole.marketer: return 'marketer';
      case ChatSenderRole.dcManager: return 'dc_manager';
      case ChatSenderRole.deliveryAgent: return 'delivery_agent';
      case ChatSenderRole.system: return 'system';
    }
  }

  static ChatMessageType _parseMessageType(String? tStr, Map<String, dynamic> meta) {
    final str = tStr?.toLowerCase() ?? '';
    switch (str) {
      case 'status_change': return ChatMessageType.statusChange;
      case 'rider_assigned': return ChatMessageType.riderAssigned;
      case 'product_changed': return ChatMessageType.productChanged;
      case 'ownership_transferred': return ChatMessageType.ownershipTransferred;
      case 'delivery_completed': return ChatMessageType.deliveryCompleted;
      case 'delivery_failed': return ChatMessageType.deliveryFailed;
      case 'rescheduled': return ChatMessageType.rescheduled;
      case 'voice_note': return ChatMessageType.voiceNote;
      case 'file_attachment': return ChatMessageType.fileAttachment;
      case 'image': return ChatMessageType.image;
      default:
        if (meta['type'] == 'voice_note' || meta['audio_url'] != null) return ChatMessageType.voiceNote;
        if (meta['type'] == 'image') return ChatMessageType.image;
        if (meta['type'] == 'file_attachment') return ChatMessageType.fileAttachment;
        return ChatMessageType.text;
    }
  }

  OrderConversationMessageModel _outboxItemToMessage(Map<String, dynamic> item) {
    final meta = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : <String, dynamic>{};
    return OrderConversationMessageModel(
      id: item['client_message_id']?.toString() ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clientMessageId: item['client_message_id']?.toString(),
      conversationId: item['conversation_id']?.toString() ?? '',
      orderId: item['order_id']?.toString() ?? '',
      senderId: item['sender_id']?.toString(),
      senderName: item['sender_name']?.toString() ?? 'User',
      senderAvatarUrl: item['sender_avatar_url']?.toString(),
      senderRole: _parseSenderRole(item['sender_role']?.toString()),
      messageType: _parseMessageType(item['message_type']?.toString(), meta),
      messageBody: item['message_body']?.toString() ?? '',
      metadata: meta,
      createdAt: item['created_at'] != null
          ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sendState: item['send_state']?.toString() ?? 'pending',
    );
  }

  List<OrderConversationMessageEntity> _mergeServerAndPendingMessages(
    List<OrderConversationMessageEntity> serverMsgs,
    List<OrderConversationMessageEntity> pendingMsgs,
  ) {
    final result = List<OrderConversationMessageEntity>.from(serverMsgs);
    for (final pending in pendingMsgs) {
      final alreadyPresent = serverMsgs.any((s) =>
          (s.clientMessageId != null && s.clientMessageId == pending.clientMessageId) ||
          (s.metadata['client_message_id'] != null && s.metadata['client_message_id'] == pending.clientMessageId) ||
          s.id == pending.id);
      if (!alreadyPresent) {
        result.add(pending);
      }
    }
    return result;
  }

  /// Open or load an order conversation by its Order ID (Offline-first with outbox support)
  Future<void> openOrderConversation(String orderId) async {
    _streamSub?.cancel();
    final localStorage = _ref.read(localStorageServiceProvider);

    // 1. Check local in-memory recentConversations or localStorage cached conversations
    OrderConversationEntity? existingConv = state.recentConversations.cast<OrderConversationEntity?>().firstWhere(
          (c) => c?.orderId == orderId,
          orElse: () => null,
        );

    if (existingConv == null) {
      try {
        final cachedConvs = await localStorage.getCachedConversations();
        existingConv = cachedConvs?.cast<OrderConversationEntity?>().firstWhere(
              (c) => c?.orderId == orderId,
              orElse: () => null,
            );
      } catch (_) {}
    }

    final convId = existingConv?.id ?? orderId;

    // 1. Check in-memory state.messagesByOrderId first for lightning-fast zero-latency display
    List<OrderConversationMessageEntity> cachedMsgs = state.messagesByOrderId[orderId] ??
        (existingConv != null ? state.messagesByOrderId[existingConv.id] : null) ??
        [];

    // 2. If not in memory, check localStorage for convId and orderId
    if (cachedMsgs.isEmpty) {
      cachedMsgs = (await localStorage.getCachedConversationMessages(convId)) ?? [];
      if (cachedMsgs.isEmpty && orderId != convId) {
        cachedMsgs = (await localStorage.getCachedConversationMessages(orderId)) ?? [];
      }
    }

    final outboxItems = await localStorage.getOutboxMessages(
      conversationId: existingConv?.id,
      orderId: orderId,
    );
    final pendingModels = outboxItems.map(_outboxItemToMessage).toList();
    final initialCombined = _mergeServerAndPendingMessages(cachedMsgs, pendingModels);

    final updatedMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
    if (initialCombined.isNotEmpty) {
      updatedMap[orderId] = initialCombined;
      if (existingConv != null) updatedMap[existingConv.id] = initialCombined;
    }

    if (existingConv != null) {
      state = state.copyWith(
        activeConversation: existingConv,
        messages: initialCombined,
        messagesByOrderId: updatedMap,
        pendingOutboxCount: outboxItems.length,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: initialCombined.isEmpty,
        messages: initialCombined,
        messagesByOrderId: updatedMap,
        pendingOutboxCount: outboxItems.length,
        errorMessage: null,
      );
    }

    try {
      OrderConversationEntity? conv;
      try {
        conv = await _dataSource.getConversationByOrderId(orderId);
      } catch (netErr) {
        debugPrint('[PIPELINE_CHAT] ℹ️ Network fetch for conversation $orderId failed (offline mode): $netErr');
        conv = existingConv;
      }
      conv ??= existingConv;

      if (conv == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No active chat pipeline found for this order.',
        );
        return;
      }

      // STRICT CLOSER ACCESS CONTROL: Closers can ONLY access conversations that concern them
      final authUser = _ref.read(authProvider).user;
      if (authUser?.isCloser == true) {
        final closerId = authUser?.closerId ?? authUser?.id;
        final closerName = authUser?.fullName.trim().toLowerCase();
        final matchId = conv.closerId != null && (conv.closerId == closerId || conv.closerId == authUser?.id);
        final matchName = closerName != null &&
            closerName.isNotEmpty &&
            conv.closerName != null &&
            conv.closerName!.trim().toLowerCase() == closerName;

        if (!matchId && !matchName) {
          debugPrint('[PIPELINE_CHAT] ⛔ Access Denied: Closer ${authUser?.email} attempted to open conversation for order ${conv.orderNumber} belonging to "${conv.closerName ?? "Unassigned"}"');
          state = state.copyWith(
            isLoading: false,
            activeConversation: null,
            messages: const [],
            errorMessage: 'Access Restricted: Closers only have access to chat pipelines for their own assigned orders.',
          );
          return;
        }
      }

      // STRICT MARKETER ACCESS CONTROL: Digital Marketers can ONLY access conversations for their lead form orders
      if (authUser != null && authUser.role.toLowerCase().contains('marketer')) {
        final mId = authUser.marketerId ?? authUser.id;
        final mName = authUser.fullName.trim().toLowerCase();
        final matchId = conv.marketerId != null && (conv.marketerId == mId || conv.marketerId == authUser.id);
        final matchName = mName.isNotEmpty && conv.marketerName != null && conv.marketerName!.trim().toLowerCase() == mName;

        if (conv.marketerId != null && !matchId && !matchName) {
          debugPrint('[PIPELINE_CHAT] ⛔ Access Denied: Marketer ${authUser.email} attempted to open conversation for order ${conv.orderNumber} belonging to "${conv.marketerName ?? "Other"}"');
          state = state.copyWith(
            isLoading: false,
            activeConversation: null,
            messages: const [],
            errorMessage: 'Access Restricted: Digital Marketers only have access to chat pipelines for orders from their forms.',
          );
          return;
        }
      }

      List<OrderConversationMessageEntity> remoteMsgs = [];
      try {
        remoteMsgs = await _dataSource.fetchMessages(conv.id);
      } catch (fetchErr) {
        debugPrint('[PIPELINE_CHAT] ℹ️ Fetch messages failed (using offline cached messages): $fetchErr');
        remoteMsgs = cachedMsgs;
      }

      final liveOutbox = await localStorage.getOutboxMessages(conversationId: conv.id);
      final livePending = liveOutbox.map(_outboxItemToMessage).toList();
      final finalMerged = _mergeServerAndPendingMessages(remoteMsgs, livePending);

      final nextMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
      nextMap[orderId] = finalMerged;
      nextMap[conv.id] = finalMerged;

      state = state.copyWith(
        activeConversation: conv,
        messages: finalMerged,
        messagesByOrderId: nextMap,
        pendingOutboxCount: liveOutbox.length,
        isLoading: false,
      );
      unawaited(localStorage.cacheConversationMessages(conv.id, finalMerged));
      if (conv.orderId.isNotEmpty && conv.orderId != conv.id) {
        unawaited(localStorage.cacheConversationMessages(conv.orderId, finalMerged));
      }

      // Auto-connect presence channel for this conversation
      _setupConversationPresenceChannel(conv.id);

      // Auto-mark as read for current user role
      if (authUser != null) {
        markConversationAsRead(conv.id, authUser.isCloser ? 'closer' : authUser.role);
      }

      // Start realtime stream
      _streamSub = _dataSource.streamMessages(conv.id).listen(
        (updatedMsgs) async {
          // DEFENSIVE SHIELD: If realtime stream emits an empty snapshot while we already have loaded messages,
          // do NOT wipe them out.
          if (updatedMsgs.isEmpty && state.messages.isNotEmpty) {
            debugPrint('[PIPELINE_CHAT] ℹ️ Stream emitted empty list while ${state.messages.length} messages are loaded. Preserving messages.');
            return;
          }

          final latestOutbox = await localStorage.getOutboxMessages(conversationId: conv!.id);
          final pending = latestOutbox.map(_outboxItemToMessage).toList();
          final streamMerged = _mergeServerAndPendingMessages(updatedMsgs, pending);

          final previousMsgs = state.messages;
          if (previousMsgs.isNotEmpty && updatedMsgs.length > previousMsgs.length) {
            final authUser = _ref.read(authProvider).user;
            final latestMsg = updatedMsgs.last;
            final isMyMsg = (authUser?.id != null && latestMsg.senderId == authUser!.id);
            if (!isMyMsg) {
              AudioService().playIncomingMessage();
            }
          }

          final streamMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
          streamMap[orderId] = streamMerged;
          streamMap[conv.id] = streamMerged;

          state = state.copyWith(
            messages: streamMerged,
            messagesByOrderId: streamMap,
            pendingOutboxCount: latestOutbox.length,
          );
          unawaited(localStorage.cacheConversationMessages(conv.id, streamMerged));
          if (conv.orderId.isNotEmpty && conv.orderId != conv.id) {
            unawaited(localStorage.cacheConversationMessages(conv.orderId, streamMerged));
          }
        },
        onError: (err) {
          // Keep current messages if stream drops
          debugPrint('[PIPELINE_CHAT] ⚠️ Messages stream notice: $err');
        },
      );

      // Trigger automatic outbox flush if online
      unawaited(flushOutbox(conv.id));
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

  /// Send a text message in the active conversation (Optimistic + Offline-First Outbox)
  Future<bool> sendTextMessage(String body, {Map<String, dynamic>? metadata}) async {
    final conv = state.activeConversation;
    if (conv == null || body.trim().isEmpty) return false;

    try {
      final authState = _ref.read(authProvider);
      final user = authState.user;

      if (user?.isCloser == true) {
        final closerId = user?.closerId ?? user?.id;
        final closerName = user?.fullName.trim().toLowerCase();
        final matchId = conv.closerId != null && (conv.closerId == closerId || conv.closerId == user?.id);
        final matchName = closerName != null &&
            closerName.isNotEmpty &&
            conv.closerName != null &&
            conv.closerName!.trim().toLowerCase() == closerName;
        if (!matchId && !matchName) {
          state = state.copyWith(
              isSending: false,
              errorMessage: 'Access Restricted: You cannot post in conversations for other orders.');
          return false;
        }
      }

      final sender = _resolveSender(user);
      final clientMsgId = 'cmsg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

      final optimisticMsg = OrderConversationMessageModel(
        id: clientMsgId,
        clientMessageId: clientMsgId,
        conversationId: conv.id,
        orderId: conv.orderId,
        senderId: sender.senderId,
        senderName: sender.senderName,
        senderAvatarUrl: sender.senderAvatar,
        senderRole: sender.role,
        messageType: ChatMessageType.text,
        messageBody: body.trim(),
        metadata: Map<String, dynamic>.from(metadata ?? {}),
        sendState: 'pending',
        createdAt: DateTime.now(),
      );

      final updatedMessages = [...state.messages, optimisticMsg];
      final sendMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
      sendMap[conv.orderId] = updatedMessages;
      sendMap[conv.id] = updatedMessages;

      state = state.copyWith(
        messages: updatedMessages,
        messagesByOrderId: sendMap,
        pendingOutboxCount: state.pendingOutboxCount + 1,
      );

      // Cancel typing presence immediately upon sending
      broadcastUserPresence(conversationId: conv.id, status: 'idle');

      final outboxItem = {
        'client_message_id': clientMsgId,
        'conversation_id': conv.id,
        'order_id': conv.orderId,
        'sender_id': sender.senderId,
        'sender_name': sender.senderName,
        'sender_avatar_url': sender.senderAvatar,
        'sender_role': _roleToString(sender.role),
        'message_type': 'text',
        'message_body': body.trim(),
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
        'send_state': 'pending',
        'retry_count': 0,
      };

      final localStorage = _ref.read(localStorageServiceProvider);
      await localStorage.saveOutboxMessage(outboxItem);
      await localStorage.cacheConversationMessages(conv.id, updatedMessages);

      AudioService().playMessageSent();

      // Trigger async background dispatch
      unawaited(_dispatchOutboxItem(outboxItem));
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      return false;
    }
  }

  ({String? senderId, String senderName, String? senderAvatar, ChatSenderRole role}) _resolveSender(dynamic user) {
    String senderName = 'User';
    String? senderId = user?.id;
    String? senderAvatar = user?.avatarUrl;
    ChatSenderRole role = ChatSenderRole.system;

    if (user != null) {
      senderName = user.fullName.trim().isNotEmpty
          ? user.fullName
          : (user.email.split('@').first);

      final rStr = user.role.toLowerCase();
      if (user.isCloser || rStr.contains('closer')) {
        role = ChatSenderRole.closer;
      } else if (rStr.contains('marketer')) {
        role = ChatSenderRole.marketer;
      } else if (rStr.contains('client')) {
        role = ChatSenderRole.client;
      } else if (rStr.contains('dc') ||
          rStr.contains('admin') ||
          rStr.contains('manager') ||
          rStr.contains('operations') ||
          rStr.contains('dispatcher') ||
          user.isDcOperations ||
          user.isDcManager) {
        role = ChatSenderRole.dcManager;
      } else if (rStr.contains('agent') || rStr.contains('rider')) {
        role = ChatSenderRole.deliveryAgent;
      }
    }
    return (senderId: senderId, senderName: senderName, senderAvatar: senderAvatar, role: role);
  }

  /// Send a voice note in active conversation (Optimistic + Offline-First Outbox)
  Future<bool> sendVoiceNote({
    required Uint8List audioBytes,
    required Duration duration,
    String mimeType = 'audio/webm',
    String fileExtension = 'webm',
  }) async {
    final conv = state.activeConversation;
    if (conv == null || audioBytes.isEmpty) return false;

    try {
      final authState = _ref.read(authProvider);
      final user = authState.user;

      if (user?.isCloser == true) {
        final closerId = user?.closerId ?? user?.id;
        final closerName = user?.fullName.trim().toLowerCase();
        final matchId = conv.closerId != null && (conv.closerId == closerId || conv.closerId == user?.id);
        final matchName = closerName != null &&
            closerName.isNotEmpty &&
            conv.closerName != null &&
            conv.closerName!.trim().toLowerCase() == closerName;
        if (!matchId && !matchName) {
          state = state.copyWith(
              isSending: false,
              errorMessage: 'Access Restricted: You cannot post in conversations for other orders.');
          return false;
        }
      }

      final sender = _resolveSender(user);
      final clientMsgId = 'cmsg_vn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      final base64Media = base64Encode(audioBytes);
      final localDataUri = 'data:$mimeType;base64,$base64Media';

      final seconds = duration.inSeconds;
      final minutes = duration.inMinutes;
      final remainingSec = seconds % 60;
      final durationStr = '${minutes.toString().padLeft(1, '0')}:${remainingSec.toString().padLeft(2, '0')}';
      final messageBody = '🎤 Voice note ($durationStr)';

      final meta = {
        'type': 'voice_note',
        'local_data_uri': localDataUri,
        'audio_url': localDataUri,
        'duration_seconds': seconds,
        'file_size': audioBytes.length,
        'mime_type': mimeType,
        'ext': fileExtension,
      };

      final optimisticMsg = OrderConversationMessageModel(
        id: clientMsgId,
        clientMessageId: clientMsgId,
        conversationId: conv.id,
        orderId: conv.orderId,
        senderId: sender.senderId,
        senderName: sender.senderName,
        senderAvatarUrl: sender.senderAvatar,
        senderRole: sender.role,
        messageType: ChatMessageType.voiceNote,
        messageBody: messageBody,
        metadata: meta,
        sendState: 'pending',
        createdAt: DateTime.now(),
      );

      final updatedMessages = [...state.messages, optimisticMsg];
      final sendMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
      sendMap[conv.orderId] = updatedMessages;
      sendMap[conv.id] = updatedMessages;

      state = state.copyWith(
        messages: updatedMessages,
        messagesByOrderId: sendMap,
        pendingOutboxCount: state.pendingOutboxCount + 1,
      );

      // Cancel typing presence immediately upon sending
      broadcastUserPresence(conversationId: conv.id, status: 'idle');

      final outboxItem = {
        'client_message_id': clientMsgId,
        'conversation_id': conv.id,
        'order_id': conv.orderId,
        'sender_id': sender.senderId,
        'sender_name': sender.senderName,
        'sender_avatar_url': sender.senderAvatar,
        'sender_role': _roleToString(sender.role),
        'message_type': 'voice_note',
        'message_body': messageBody,
        'metadata': meta,
        'base64_media': base64Media,
        'created_at': DateTime.now().toIso8601String(),
        'send_state': 'pending',
        'retry_count': 0,
      };

      final localStorage = _ref.read(localStorageServiceProvider);
      await localStorage.saveOutboxMessage(outboxItem);
      await localStorage.cacheConversationMessages(conv.id, updatedMessages);

      AudioService().playMessageSent();

      // Trigger async background dispatch
      unawaited(_dispatchOutboxItem(outboxItem));
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Send a document or image file attachment (Optimistic + Offline-First Outbox)
  Future<bool> sendFileAttachment({
    required Uint8List fileBytes,
    required String fileName,
    String? mimeType,
    String? caption,
    bool isImage = false,
    Map<String, dynamic>? metadata,
  }) async {
    final conv = state.activeConversation;
    if (conv == null || fileBytes.isEmpty) return false;

    try {
      final authState = _ref.read(authProvider);
      final user = authState.user;

      if (user?.isCloser == true) {
        final closerId = user?.closerId ?? user?.id;
        final closerName = user?.fullName.trim().toLowerCase();
        final matchId = conv.closerId != null && (conv.closerId == closerId || conv.closerId == user?.id);
        final matchName = closerName != null &&
            closerName.isNotEmpty &&
            conv.closerName != null &&
            conv.closerName!.trim().toLowerCase() == closerName;
        if (!matchId && !matchName) {
          state = state.copyWith(
              isSending: false,
              errorMessage: 'Access Restricted: You cannot post in conversations for other orders.');
          return false;
        }
      }

      final sender = _resolveSender(user);
      final clientMsgId = 'cmsg_file_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      final base64Media = base64Encode(fileBytes);
      final effectiveMime = mimeType ?? (isImage ? 'image/jpeg' : 'application/octet-stream');
      final localDataUri = 'data:$effectiveMime;base64,$base64Media';

      final defaultBody = isImage ? '📷 $fileName' : '📎 $fileName';
      final messageBody = (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : defaultBody;

      final meta = {
        'type': isImage ? 'image' : 'file_attachment',
        'local_data_uri': localDataUri,
        'file_url': localDataUri,
        if (isImage) 'image_url': localDataUri,
        'file_name': fileName,
        'file_size': fileBytes.length,
        'mime_type': effectiveMime,
        if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
        if (metadata != null) ...metadata,
      };

      final optimisticMsg = OrderConversationMessageModel(
        id: clientMsgId,
        clientMessageId: clientMsgId,
        conversationId: conv.id,
        orderId: conv.orderId,
        senderId: sender.senderId,
        senderName: sender.senderName,
        senderAvatarUrl: sender.senderAvatar,
        senderRole: sender.role,
        messageType: isImage ? ChatMessageType.image : ChatMessageType.fileAttachment,
        messageBody: messageBody,
        metadata: meta,
        sendState: 'pending',
        createdAt: DateTime.now(),
      );

      final updatedMessages = [...state.messages, optimisticMsg];
      final sendMap = Map<String, List<OrderConversationMessageEntity>>.from(state.messagesByOrderId);
      sendMap[conv.orderId] = updatedMessages;
      sendMap[conv.id] = updatedMessages;

      state = state.copyWith(
        messages: updatedMessages,
        messagesByOrderId: sendMap,
        pendingOutboxCount: state.pendingOutboxCount + 1,
      );

      // Cancel typing presence immediately upon sending
      broadcastUserPresence(conversationId: conv.id, status: 'idle');

      final outboxItem = {
        'client_message_id': clientMsgId,
        'conversation_id': conv.id,
        'order_id': conv.orderId,
        'sender_id': sender.senderId,
        'sender_name': sender.senderName,
        'sender_avatar_url': sender.senderAvatar,
        'sender_role': _roleToString(sender.role),
        'message_type': isImage ? 'image' : 'file_attachment',
        'message_body': messageBody,
        'metadata': meta,
        'base64_media': base64Media,
        'created_at': DateTime.now().toIso8601String(),
        'send_state': 'pending',
        'retry_count': 0,
      };

      final localStorage = _ref.read(localStorageServiceProvider);
      await localStorage.saveOutboxMessage(outboxItem);
      await localStorage.cacheConversationMessages(conv.id, updatedMessages);

      AudioService().playMessageSent();

      // Trigger async background dispatch
      unawaited(_dispatchOutboxItem(outboxItem));
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Dispatch an individual outbox item to Supabase Storage & Remote DB
  Future<bool> _dispatchOutboxItem(Map<String, dynamic> item) async {
    final clientMsgId = item['client_message_id']?.toString() ?? '';
    final convId = item['conversation_id']?.toString() ?? '';
    final orderId = item['order_id']?.toString() ?? '';
    final localStorage = _ref.read(localStorageServiceProvider);

    final net = _ref.read(networkProvider);
    if (net.isOffline) {
      debugPrint('[PIPELINE_CHAT] 📴 Offline: Keeping outbox message $clientMsgId in queue.');
      return false;
    }

    try {
      final base64Media = item['base64_media']?.toString();
      final meta = item['metadata'] is Map
          ? Map<String, dynamic>.from(item['metadata'] as Map)
          : <String, dynamic>{};
      final msgTypeStr = item['message_type']?.toString() ?? 'text';

      if (base64Media != null && base64Media.isNotEmpty) {
        final bytes = base64Decode(base64Media);
        if (msgTypeStr == 'voice_note') {
          final audioUrl = await ChatStorageService.uploadVoiceNote(
            bytes: bytes,
            conversationId: convId,
            ext: meta['ext']?.toString() ?? 'webm',
            mimeType: meta['mime_type']?.toString() ?? 'audio/webm',
          );
          meta['audio_url'] = audioUrl;
        } else if (msgTypeStr == 'image') {
          final imgUrl = await ChatStorageService.uploadImage(
            bytes: bytes,
            conversationId: convId,
            ext: meta['file_name']?.toString().split('.').last ?? 'jpg',
          );
          meta['image_url'] = imgUrl;
          meta['file_url'] = imgUrl;
        } else if (msgTypeStr == 'file_attachment') {
          final fileUrl = await ChatStorageService.uploadFileAttachment(
            bytes: bytes,
            conversationId: convId,
            originalFileName: meta['file_name']?.toString() ?? 'attachment',
            mimeType: meta['mime_type']?.toString(),
          );
          meta['file_url'] = fileUrl;
        }
      }

      final serverMsg = await _dataSource.sendMessage(
        conversationId: convId,
        orderId: orderId,
        senderId: item['sender_id']?.toString(),
        senderName: item['sender_name']?.toString() ?? 'User',
        senderAvatarUrl: item['sender_avatar_url']?.toString(),
        senderRole: _parseSenderRole(item['sender_role']?.toString()),
        messageType: _parseMessageType(msgTypeStr, meta),
        messageBody: item['message_body']?.toString() ?? '',
        metadata: meta,
        clientMessageId: clientMsgId,
      );

      // Remove dispatched item from local outbox queue
      await localStorage.removeOutboxMessage(clientMsgId);

      // Reconcile and merge into live state
      if (mounted && state.activeConversation?.id == convId) {
        final updated = state.messages.map((m) {
          if (m.clientMessageId == clientMsgId || m.id == clientMsgId) {
            return serverMsg.copyWith(
              clientMessageId: clientMsgId,
              sendState: 'sent',
              metadata: {
                ...serverMsg.metadata,
                if (m.metadata['local_data_uri'] != null)
                  'local_data_uri': m.metadata['local_data_uri'],
              },
            );
          }
          return m;
        }).toList();

        final remaining = await localStorage.getOutboxMessages(conversationId: convId);
        state = state.copyWith(
          messages: updated,
          pendingOutboxCount: remaining.length,
        );
        unawaited(localStorage.cacheConversationMessages(convId, updated));
      }

      return true;
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] ⚠️ Outbox dispatch failure for $clientMsgId: $e');
      final retryCount = (item['retry_count'] as num?)?.toInt() ?? 0;
      final updatedItem = Map<String, dynamic>.from(item)
        ..['retry_count'] = retryCount + 1
        ..['last_error'] = e.toString()
        ..['send_state'] = (retryCount >= 4) ? 'failed' : 'pending';

      await localStorage.saveOutboxMessage(updatedItem);

      if (mounted && state.activeConversation?.id == convId && retryCount >= 4) {
        final updated = state.messages.map((m) {
          if (m.clientMessageId == clientMsgId || m.id == clientMsgId) {
            return m.copyWith(sendState: 'failed');
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
      return false;
    }
  }

  /// Flush pending outbox messages in FIFO order (called on reconnect, timer, or manual trigger)
  Future<void> flushOutbox([String? conversationId]) async {
    if (_isFlushingOutbox) return;
    _isFlushingOutbox = true;
    try {
      final localStorage = _ref.read(localStorageServiceProvider);
      final targetConvId = conversationId ?? state.activeConversation?.id;
      final items = await localStorage.getOutboxMessages(conversationId: targetConvId);

      if (items.isEmpty) {
        if (mounted) state = state.copyWith(pendingOutboxCount: 0);
        return;
      }

      if (mounted) state = state.copyWith(pendingOutboxCount: items.length);

      for (final item in items) {
        final ok = await _dispatchOutboxItem(item);
        if (!ok) {
          // Pause flushing on network disconnection / failure
          break;
        }
      }

      final remaining = await localStorage.getOutboxMessages(conversationId: targetConvId);
      if (mounted) state = state.copyWith(pendingOutboxCount: remaining.length);
    } finally {
      _isFlushingOutbox = false;
    }
  }

  /// Retry an individual failed or pending outbox message
  Future<void> retryOutboxMessage(String clientMessageId) async {
    final localStorage = _ref.read(localStorageServiceProvider);
    final items = await localStorage.getOutboxMessages();
    final item = items.firstWhere(
      (m) => m['client_message_id']?.toString() == clientMessageId,
      orElse: () => {},
    );
    if (item.isNotEmpty) {
      item['send_state'] = 'pending';
      item['retry_count'] = 0;
      await localStorage.saveOutboxMessage(item);
      if (mounted) {
        final updated = state.messages.map((m) {
          if (m.clientMessageId == clientMessageId || m.id == clientMessageId) {
            return m.copyWith(sendState: 'pending');
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
      await _dispatchOutboxItem(item);
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

  /// Toggle or add an emoji reaction to a message (optimistic UI)
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final authUser = _ref.read(authProvider).user;
    if (authUser == null) return;

    final userId = authUser.id;
    final userName = authUser.fullName.trim().isNotEmpty
        ? authUser.fullName
        : (authUser.email.split('@').first);

    // Optimistic UI update
    final updatedMessages = state.messages.map((m) {
      if (m.id == messageId) {
        final currentMeta = Map<String, dynamic>.from(m.metadata);
        final rawReactions = currentMeta['reactions'] as List? ?? [];
        final reactions = rawReactions.map((r) => Map<String, dynamic>.from(r as Map)).toList();

        final existingIndex = reactions.indexWhere((r) => r['userId'] == userId);
        if (existingIndex != -1) {
          if (reactions[existingIndex]['emoji'] == emoji) {
            reactions.removeAt(existingIndex);
          } else {
            reactions[existingIndex] = {
              'emoji': emoji,
              'userId': userId,
              'userName': userName,
            };
          }
        } else {
          reactions.add({
            'emoji': emoji,
            'userId': userId,
            'userName': userName,
          });
        }
        currentMeta['reactions'] = reactions;

        return OrderConversationMessageEntity(
          id: m.id,
          conversationId: m.conversationId,
          orderId: m.orderId,
          senderId: m.senderId,
          senderName: m.senderName,
          senderAvatarUrl: m.senderAvatarUrl,
          senderRole: m.senderRole,
          messageType: m.messageType,
          messageBody: m.messageBody,
          metadata: currentMeta,
          readByClient: m.readByClient,
          readByDc: m.readByDc,
          readByRider: m.readByRider,
          createdAt: m.createdAt,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedMessages);

    try {
      await _dataSource.toggleMessageReaction(
        messageId: messageId,
        emoji: emoji,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Error toggling reaction: $e');
    }
  }
}

final pipelineChatProvider =
    StateNotifierProvider<PipelineChatNotifier, PipelineChatState>((ref) {
  final ds = ref.watch(pipelineChatDataSourceProvider);
  return PipelineChatNotifier(ds, ref);
});
