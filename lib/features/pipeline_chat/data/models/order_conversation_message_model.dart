import '../../domain/entities/order_conversation_message.dart';

class OrderConversationMessageModel extends OrderConversationMessageEntity {
  const OrderConversationMessageModel({
    required super.id,
    required super.conversationId,
    required super.orderId,
    super.senderId,
    required super.senderName,
    super.senderAvatarUrl,
    required super.senderRole,
    super.messageType,
    required super.messageBody,
    super.metadata,
    super.readByClient,
    super.readByDc,
    super.readByRider,
    required super.createdAt,
  });

  factory OrderConversationMessageModel.fromJson(Map<String, dynamic> json) {
    ChatSenderRole role = ChatSenderRole.system;
    final rStr = json['sender_role']?.toString().toLowerCase();
    if (rStr == 'client') {
      role = ChatSenderRole.client;
    } else if (rStr == 'closer' || rStr == 'client_closer') {
      role = ChatSenderRole.closer;
    } else if (rStr == 'dc_manager' || rStr == 'dc') {
      role = ChatSenderRole.dcManager;
    } else if (rStr == 'delivery_agent' || rStr == 'rider') {
      role = ChatSenderRole.deliveryAgent;
    }

    ChatMessageType type = ChatMessageType.text;
    final tStr = json['message_type']?.toString().toLowerCase();
    switch (tStr) {
      case 'status_change':
        type = ChatMessageType.statusChange;
        break;
      case 'rider_assigned':
        type = ChatMessageType.riderAssigned;
        break;
      case 'product_changed':
        type = ChatMessageType.productChanged;
        break;
      case 'ownership_transferred':
        type = ChatMessageType.ownershipTransferred;
        break;
      case 'delivery_completed':
        type = ChatMessageType.deliveryCompleted;
        break;
      case 'delivery_failed':
        type = ChatMessageType.deliveryFailed;
        break;
      case 'rescheduled':
        type = ChatMessageType.rescheduled;
        break;
      default:
        type = ChatMessageType.text;
    }

    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};

    final avatar = json['sender_avatar_url']?.toString() ??
        (meta['avatar_url']?.toString());

    return OrderConversationMessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      senderName: json['sender_name']?.toString() ?? 'User',
      senderAvatarUrl: avatar,
      senderRole: role,
      messageType: type,
      messageBody: json['message_body']?.toString() ?? '',
      metadata: meta,
      readByClient: json['read_by_client'] == true,
      readByDc: json['read_by_dc'] == true,
      readByRider: json['read_by_rider'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory OrderConversationMessageModel.fromEntity(OrderConversationMessage entity) {
    return OrderConversationMessageModel(
      id: entity.id,
      conversationId: entity.conversationId,
      orderId: entity.orderId,
      senderId: entity.senderId,
      senderName: entity.senderName,
      senderAvatarUrl: entity.senderAvatarUrl,
      senderRole: entity.senderRole,
      messageType: entity.messageType,
      messageBody: entity.messageBody,
      metadata: entity.metadata,
      readByClient: entity.readByClient,
      readByDc: entity.readByDc,
      readByRider: entity.readByRider,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
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
      default:
        rStr = 'system';
    }

    String tStr = 'text';
    switch (messageType) {
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
      default:
        tStr = 'text';
    }

    return {
      'id': id,
      'conversation_id': conversationId,
      'order_id': orderId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'sender_role': rStr,
      'message_type': tStr,
      'message_body': messageBody,
      'metadata': metadata,
      'read_by_client': readByClient,
      'read_by_dc': readByDc,
      'read_by_rider': readByRider,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

