import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/merchant_bi_chat_session.dart';
import '../../domain/entities/merchant_bi_message.dart';

class MerchantBIStorageService {
  static const String _sessionsPrefix = 'novexps_merchant_bi_sessions_';
  static const String _messagesPrefix = 'novexps_merchant_bi_msgs_';
  static const String _customKnowledgePrefix = 'novexps_merchant_bi_knowledge_';

  /// Fetch all chat sessions for the given merchant (client)
  Future<List<MerchantBIChatSession>> getSessions(String clientId) async {
    final localSessions = await _getLocalSessions(clientId);

    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        // Attempt Supabase fetch if initialized
      }
      final client = Supabase.instance.client;
      final response = await client
          .from('merchant_bi_chats')
          .select()
          .eq('client_id', clientId)
          .order('updated_at', ascending: false);

      if (response is List && response.isNotEmpty) {
        final remoteSessions = response
            .map((e) => MerchantBIChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveLocalSessions(clientId, remoteSessions);
        return remoteSessions;
      }
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase getSessions fallback to local: $e');
    }

    return localSessions;
  }

  /// Save or update a session
  Future<void> saveSession(MerchantBIChatSession session) async {
    final current = await _getLocalSessions(session.clientId);
    final index = current.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      current[index] = session;
    } else {
      current.insert(0, session);
    }
    await _saveLocalSessions(session.clientId, current);

    try {
      final client = Supabase.instance.client;
      await client.from('merchant_bi_chats').upsert(session.toJson());
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase saveSession fallback to local: $e');
    }
  }

  /// Get messages for a specific chat
  Future<List<MerchantBIMessage>> getMessages(
    String clientId,
    String chatId,
  ) async {
    final localMsgs = await _getLocalMessages(chatId);

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('merchant_bi_messages')
          .select()
          .eq('chat_id', chatId)
          .eq('client_id', clientId)
          .order('created_at', ascending: true);

      if (response is List && response.isNotEmpty) {
        final remoteMsgs = response
            .map((e) => MerchantBIMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveLocalMessages(chatId, remoteMsgs);
        return remoteMsgs;
      }
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase getMessages fallback to local: $e');
    }

    return localMsgs;
  }

  /// Save a message
  Future<void> saveMessage(MerchantBIMessage message) async {
    final current = await _getLocalMessages(message.chatId);
    current.add(message);
    await _saveLocalMessages(message.chatId, current);

    // Update parent session last message
    final sessions = await _getLocalSessions(message.clientId);
    final sIndex = sessions.indexWhere((s) => s.id == message.chatId);
    if (sIndex >= 0) {
      final updated = sessions[sIndex].copyWith(
        lastMessage: message.content,
        updatedAt: DateTime.now(),
      );
      sessions[sIndex] = updated;
      await _saveLocalSessions(message.clientId, sessions);
    }

    try {
      final client = Supabase.instance.client;
      await client.from('merchant_bi_messages').insert(message.toJson());
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase saveMessage fallback to local: $e');
    }
  }

  /// Clear messages for a chat session
  Future<void> clearChat(String clientId, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_messagesPrefix$chatId');

    try {
      final client = Supabase.instance.client;
      await client
          .from('merchant_bi_messages')
          .delete()
          .eq('chat_id', chatId)
          .eq('client_id', clientId);
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase clearChat fallback: $e');
    }
  }

  /// Fetch custom knowledge stored in Supabase for this merchant
  Future<List<Map<String, dynamic>>> getCustomKnowledge(String clientId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('merchant_bi_custom_knowledge')
          .select()
          .eq('client_id', clientId)
          .eq('is_active', true);

      if (response is List && response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase getCustomKnowledge notice: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_customKnowledgePrefix$clientId');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        return List<Map<String, dynamic>>.from(decoded);
      } catch (_) {}
    }
    return [];
  }

  /// Save custom knowledge locally and remotely
  Future<void> saveCustomKnowledge(
    String clientId,
    List<Map<String, dynamic>> knowledge,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_customKnowledgePrefix$clientId',
      jsonEncode(knowledge),
    );

    try {
      final client = Supabase.instance.client;
      for (final item in knowledge) {
        await client.from('merchant_bi_custom_knowledge').upsert({
          ...item,
          'client_id': clientId,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[MERCHANT_BI] ℹ️ Supabase saveCustomKnowledge: $e');
    }
  }

  // --- Private Local Storage Helpers ---

  Future<List<MerchantBIChatSession>> _getLocalSessions(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_sessionsPrefix$clientId');
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MerchantBIChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[MERCHANT_BI] ⚠️ Failed parsing local sessions: $e');
      return [];
    }
  }

  Future<void> _saveLocalSessions(
    String clientId,
    List<MerchantBIChatSession> sessions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString('$_sessionsPrefix$clientId', encoded);
  }

  Future<List<MerchantBIMessage>> _getLocalMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_messagesPrefix$chatId');
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MerchantBIMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[MERCHANT_BI] ⚠️ Failed parsing local messages: $e');
      return [];
    }
  }

  Future<void> _saveLocalMessages(
    String chatId,
    List<MerchantBIMessage> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString('$_messagesPrefix$chatId', encoded);
  }
}

