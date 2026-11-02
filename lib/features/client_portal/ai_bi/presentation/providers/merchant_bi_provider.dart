import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/merchant_bi_chat_session.dart';
import '../../domain/entities/merchant_bi_message.dart';
import '../../data/services/merchant_bi_storage_service.dart';
import '../../data/services/merchant_bi_engine.dart';
import '../../data/services/gemini_ai_service.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';

class MerchantBIState {
  final MerchantBIChatSession? currentSession;
  final List<MerchantBIChatSession> sessions;
  final List<MerchantBIMessage> messages;
  final bool isLoading;
  final List<Map<String, dynamic>> customKnowledge;
  final List<String> defaultSuggestions;

  const MerchantBIState({
    this.currentSession,
    this.sessions = const [],
    this.messages = const [],
    this.isLoading = false,
    this.customKnowledge = const [],
    this.defaultSuggestions = const [
      'How much sales have we made for Respia?',
      'What is our overall delivery success rate?',
      'Show order fulfillment flowchart',
      'What happens when a delivery fails?',
      'Show warehouse stock in hubs',
      'Show 7-day revenue velocity trend',
    ],
  });

  MerchantBIState copyWith({
    MerchantBIChatSession? currentSession,
    List<MerchantBIChatSession>? sessions,
    List<MerchantBIMessage>? messages,
    bool? isLoading,
    List<Map<String, dynamic>>? customKnowledge,
    List<String>? defaultSuggestions,
  }) {
    return MerchantBIState(
      currentSession: currentSession ?? this.currentSession,
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      customKnowledge: customKnowledge ?? this.customKnowledge,
      defaultSuggestions: defaultSuggestions ?? this.defaultSuggestions,
    );
  }
}

class MerchantBINotifier extends StateNotifier<MerchantBIState> {
  final Ref ref;
  final MerchantBIStorageService _storageService;
  String? _initializedClientId;

  MerchantBINotifier(this.ref, {MerchantBIStorageService? storageService})
      : _storageService = storageService ?? MerchantBIStorageService(),
        super(const MerchantBIState());

  /// Initialize and load sessions for active merchant
  Future<void> initialize(String clientId) async {
    if (_initializedClientId == clientId && state.currentSession != null) return;
    _initializedClientId = clientId;

    state = state.copyWith(isLoading: true);

    try {
      final sessions = await _storageService.getSessions(clientId);
      final knowledge = await _storageService.getCustomKnowledge(clientId);

      MerchantBIChatSession activeSession;
      if (sessions.isNotEmpty) {
        activeSession = sessions.first;
      } else {
        activeSession = MerchantBIChatSession(
          id: 'chat-${DateTime.now().millisecondsSinceEpoch}',
          clientId: clientId,
          title: 'Executive Intelligence',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        sessions.insert(0, activeSession);
        await _storageService.saveSession(activeSession);
      }

      final messages = await _storageService.getMessages(
        clientId,
        activeSession.id,
      );

      state = state.copyWith(
        currentSession: activeSession,
        sessions: sessions,
        messages: messages,
        customKnowledge: knowledge,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[MERCHANT_BI_NOTIFIER] Error initializing: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Create a fresh new chat session
  Future<void> createNewSession() async {
    final client = ref.read(clientPortalProvider).clientProfile;
    final newSession = MerchantBIChatSession(
      id: 'chat-${DateTime.now().millisecondsSinceEpoch}',
      clientId: client.id,
      title: 'Business Analysis #${state.sessions.length + 1}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updatedSessions = [newSession, ...state.sessions];
    await _storageService.saveSession(newSession);

    state = state.copyWith(
      currentSession: newSession,
      sessions: updatedSessions,
      messages: [],
    );
  }

  /// Switch active session
  Future<void> switchSession(String sessionId) async {
    final target = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => state.currentSession!,
    );

    state = state.copyWith(isLoading: true);
    final msgs = await _storageService.getMessages(target.clientId, target.id);

    state = state.copyWith(
      currentSession: target,
      messages: msgs,
      isLoading: false,
    );
  }

  /// Ask the AI a question
  Future<void> askQuestion(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final portalState = ref.read(clientPortalProvider);
    final client = portalState.clientProfile;

    if (state.currentSession == null) {
      await initialize(client.id);
    }

    final session = state.currentSession!;

    // 1. Create and append User Message
    final userMsg = MerchantBIMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      chatId: session.id,
      clientId: client.id,
      sender: MerchantBISender.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    final newMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: newMessages, isLoading: true);

    await _storageService.saveMessage(userMsg);

    // 2. Process query via Gemini AI Service (with automatic fallback to on-device engine)
    final aiResponse = await GeminiAIService.instance.generateBIResponse(
      query: trimmed,
      chatId: session.id,
      state: portalState,
      customKnowledge: state.customKnowledge,
    );

    final updatedMessages = [...newMessages, aiResponse];
    state = state.copyWith(messages: updatedMessages, isLoading: false);

    await _storageService.saveMessage(aiResponse);
  }

  /// Clear messages for current session
  Future<void> clearCurrentChat() async {
    if (state.currentSession == null) return;
    final session = state.currentSession!;
    await _storageService.clearChat(session.clientId, session.id);
    state = state.copyWith(messages: []);
  }

  /// Save or add custom merchant knowledge
  Future<void> addCustomKnowledge({
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final client = ref.read(clientPortalProvider).clientProfile;
    final item = {
      'id': 'know-${DateTime.now().millisecondsSinceEpoch}',
      'client_id': client.id,
      'title': title,
      'content': content,
      'tags': tags,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    final updated = [...state.customKnowledge, item];
    state = state.copyWith(customKnowledge: updated);
    await _storageService.saveCustomKnowledge(client.id, updated);
  }
}

final merchantBIStorageServiceProvider = Provider<MerchantBIStorageService>((ref) {
  return MerchantBIStorageService();
});

final merchantBIProvider =
    StateNotifierProvider<MerchantBINotifier, MerchantBIState>((ref) {
  final storage = ref.watch(merchantBIStorageServiceProvider);
  return MerchantBINotifier(ref, storageService: storage);
});
