import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../domain/entities/order_conversation.dart';
import '../../domain/entities/order_conversation_message.dart';
import '../models/order_conversation_model.dart';
import '../models/order_conversation_message_model.dart';

abstract class PipelineChatRemoteDataSource {
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId);
  Future<List<OrderConversationEntity>> fetchConversations({
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
  });
  Future<List<OrderConversationEntity>> fetchConversationsScoped({
    required String userRole,
    required String userId,
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
    String? closerId,
  });
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userRole,
  });
  Future<List<OrderConversationMessageEntity>> fetchMessages(String conversationId);
  Stream<List<OrderConversationMessageEntity>> streamMessages(String conversationId);
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
  });
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
  });
}

class PipelineChatRemoteDataSourceImpl implements PipelineChatRemoteDataSource {
  final SupabaseClient? _client;

  PipelineChatRemoteDataSourceImpl([this._client]);

  SupabaseClient _getDbClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
    }
  }

  SupabaseClient _getAdminClient() {
    return SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );
  }

  @override
  Future<OrderConversationEntity?> getConversationByOrderId(String orderId) async {
    try {
      final db = _getAdminClient();
      final res = await db
          .from('order_conversations')
          .select('*,client_closers(avatar_url,full_name)')
          .eq('order_id', orderId)
          .maybeSingle();

      if (res != null) {
        return OrderConversationModel.fromJson(res);
      }

      // Auto-initialize conversation if the order exists in orders table
      final orderRow = await db.from('orders').select().eq('id', orderId).maybeSingle();
      if (orderRow != null && orderRow['client_id'] != null) {
        final newConv = await db.from('order_conversations').insert({
          'order_id': orderRow['id'],
          'order_number': orderRow['order_number'] ?? 'ORD-${orderRow['id'].toString().substring(0, 8)}',
          'customer_name': orderRow['customer_name'] ?? 'Customer',
          'customer_phone': orderRow['customer_phone'],
          'client_id': orderRow['client_id'],
          'client_name': orderRow['client_name'] ?? 'Merchant',
          'distribution_center_id': orderRow['distribution_center_id'],
          'distribution_center_name': orderRow['distribution_center_name'],
          'delivery_agent_id': orderRow['delivery_agent_id'],
          'delivery_agent_name': orderRow['delivery_agent_name'],
          'closer_id': orderRow['closer_id'],
          'closer_name': orderRow['closer_name'],
          'order_status': orderRow['status'] ?? 'pending',
          'current_product_name': orderRow['product_name'],
          'current_package_name': orderRow['package_deal_name'],
          'current_total_amount': orderRow['total_amount'] ?? 0,
          'last_message_text': 'Order chat pipeline initialized.',
          'last_message_sender_name': 'System',
          'last_message_at': DateTime.now().toIso8601String(),
        }).select('*,client_closers(avatar_url,full_name)').maybeSingle();

        if (newConv != null) {
          return OrderConversationModel.fromJson(newConv);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Error getting conversation for order $orderId: $e');
      return null;
    }
  }

  @override
  Future<List<OrderConversationEntity>> fetchConversations({
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
  }) async {
    try {
      final db = _getAdminClient();
      var query = db.from('order_conversations').select();

      if (clientId != null && clientId.isNotEmpty) {
        query = query.eq('client_id', clientId);
      }
      if (distributionCenterId != null && distributionCenterId.isNotEmpty) {
        query = query.eq('distribution_center_id', distributionCenterId);
      }
      if (deliveryAgentId != null && deliveryAgentId.isNotEmpty) {
        query = query.eq('delivery_agent_id', deliveryAgentId);
      }

      final res = await query.order('last_message_at', ascending: false);
      return (res as List)
          .map((e) => OrderConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Error fetching conversations: $e');
      return [];
    }
  }

  @override
  Future<List<OrderConversationEntity>> fetchConversationsScoped({
    required String userRole,
    required String userId,
    String? clientId,
    String? distributionCenterId,
    String? deliveryAgentId,
    String? closerId,
  }) async {
    try {
      final db = _getAdminClient();
      var query = db.from('order_conversations').select('*,client_closers(avatar_url,full_name)');
      final r = userRole.toLowerCase().trim();

      if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda') || r.contains('driver')) {
        final targetRiderId = (deliveryAgentId != null && deliveryAgentId.isNotEmpty) ? deliveryAgentId : userId;
        query = query.eq('delivery_agent_id', targetRiderId);
      } else if (r.contains('client') || r.contains('merchant')) {
        final targetClientId = (clientId != null && clientId.isNotEmpty) ? clientId : userId;
        query = query.eq('client_id', targetClientId);
      } else if (r.contains('dc') || r.contains('manager') || r.contains('operations')) {
        if (distributionCenterId != null && distributionCenterId.isNotEmpty) {
          query = query.eq('distribution_center_id', distributionCenterId);
        } else {
          return [];
        }
      } else if (r.contains('closer')) {
        final targetCloserId = (closerId != null && closerId.isNotEmpty) ? closerId : userId;
        if (targetCloserId.isNotEmpty) {
          if (closerId != null && closerId.isNotEmpty && closerId != userId) {
            query = query.or('closer_id.eq.$closerId,closer_id.eq.$userId');
          } else {
            query = query.eq('closer_id', targetCloserId);
          }
        } else {
          return [];
        }
      } else if (r.contains('super_admin') || r.contains('admin')) {
        if (distributionCenterId != null && distributionCenterId.isNotEmpty) {
          query = query.eq('distribution_center_id', distributionCenterId);
        }
        if (clientId != null && clientId.isNotEmpty) {
          query = query.eq('client_id', clientId);
        }
      } else {
        // Unknown role: empty list to avoid leaking conversations
        return [];
      }

      final res = await query.order('last_message_at', ascending: false);
      return (res as List)
          .map((e) => OrderConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Error fetching scoped conversations: $e');
      return [];
    }
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userRole,
  }) async {
    try {
      final db = _getAdminClient();
      await db.rpc('fn_mark_conversation_read', params: {
        'p_conversation_id': conversationId,
        'p_role': userRole,
      });
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] ℹ️ Notice marking conversation read: $e');
    }
  }

  @override
  Future<List<OrderConversationMessageEntity>> fetchMessages(String conversationId) async {
    try {
      final db = _getAdminClient();
      final res = await db
          .from('order_conversation_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (res as List)
          .map((e) => OrderConversationMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PIPELINE_CHAT] Error fetching messages for $conversationId: $e');
      return [];
    }
  }

  @override
  Stream<List<OrderConversationMessageEntity>> streamMessages(String conversationId) {
    final client = _getDbClient();
    return client
        .from('order_conversation_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => data
            .map((json) => OrderConversationMessageModel.fromJson(json))
            .toList());
  }

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
    final db = _getAdminClient();
    String rStr = 'system';
    switch (senderRole) {
      case ChatSenderRole.client:
        rStr = 'client';
        break;
      case ChatSenderRole.closer:
        rStr = 'closer';
        break;
      case ChatSenderRole.dcManager:
        rStr = 'dc_manager';
        break;
      case ChatSenderRole.deliveryAgent:
        rStr = 'delivery_agent';
        break;
      case ChatSenderRole.system:
        rStr = 'system';
        break;
    }

    String tStr = 'text';
    switch (messageType) {
      case ChatMessageType.text:
        tStr = 'text';
        break;
      case ChatMessageType.statusChange:
        tStr = 'status_change';
        break;
      case ChatMessageType.riderAssigned:
        tStr = 'rider_assigned';
        break;
      case ChatMessageType.productChanged:
        tStr = 'product_changed';
        break;
      case ChatMessageType.ownershipTransferred:
        tStr = 'ownership_transferred';
        break;
      case ChatMessageType.deliveryCompleted:
        tStr = 'delivery_completed';
        break;
      case ChatMessageType.deliveryFailed:
        tStr = 'delivery_failed';
        break;
      case ChatMessageType.rescheduled:
        tStr = 'rescheduled';
        break;
    }

    final payload = {
      'conversation_id': conversationId,
      'order_id': orderId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'sender_role': rStr,
      'message_type': tStr,
      'message_body': messageBody.trim(),
      'metadata': metadata ?? {},
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await db
        .from('order_conversation_messages')
        .insert(payload)
        .select()
        .single();

    // Note: trg_on_order_message_inserted automatically updates order_conversations preview
    // and increments unread counters for recipients!

    return OrderConversationMessageModel.fromJson(res);
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
  }) async {
    String normalizedRole = 'system';
    final lowerRole = actorRole.toLowerCase().trim();
    if (lowerRole == 'rider' || lowerRole == 'delivery_agent' || lowerRole == 'pda') {
      normalizedRole = 'delivery_agent';
    } else if (lowerRole == 'client' || lowerRole == 'merchant' || lowerRole == 'closer') {
      normalizedRole = 'client';
    } else if (lowerRole == 'dc_manager' || lowerRole == 'manager' || lowerRole == 'admin' || lowerRole == 'supervisor') {
      normalizedRole = 'dc_manager';
    }

    final db = _getAdminClient();
    final res = await db.rpc('transfer_order_product_and_ownership', params: {
      'p_order_id': orderId,
      'p_new_product_id': newProductId,
      'p_new_package_deal_id': newPackageDealId,
      'p_new_package_name': newPackageName,
      'p_new_quantity': newQuantity,
      'p_new_paid_quantity': newPaidQuantity,
      'p_new_free_quantity': newFreeQuantity,
      'p_new_base_price': newBasePrice,
      'p_new_total_amount': newTotalAmount,
      'p_actor_name': actorName,
      'p_actor_role': normalizedRole,
      'p_transfer_reason': transferReason,
    });

    return res is Map<String, dynamic>
        ? res
        : {'success': true, 'data': res};
  }
}
