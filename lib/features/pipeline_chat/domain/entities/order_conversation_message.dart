/// Role of sender in conversation
enum ChatSenderRole {
  client,
  closer,
  dcManager,
  deliveryAgent,
  system,
}

/// Message types including automated pipeline events
enum ChatMessageType {
  text,
  statusChange,
  riderAssigned,
  productChanged,
  ownershipTransferred,
  deliveryCompleted,
  deliveryFailed,
  rescheduled,
}

/// A message or automated milestone in the Order Conversation
class OrderConversationMessageEntity {
  final String id;
  final String conversationId;
  final String orderId;

  final String? senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final ChatSenderRole senderRole;
  final ChatMessageType messageType;
  final String messageBody;
  final Map<String, dynamic> metadata;

  final bool readByClient;
  final bool readByDc;
  final bool readByRider;

  final DateTime createdAt;

  const OrderConversationMessageEntity({
    required this.id,
    required this.conversationId,
    required this.orderId,
    this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.senderRole,
    this.messageType = ChatMessageType.text,
    required this.messageBody,
    this.metadata = const {},
    this.readByClient = false,
    this.readByDc = false,
    this.readByRider = false,
    required this.createdAt,
  });

  bool get isSystem => senderRole == ChatSenderRole.system;
  bool get isStatusEvent =>
      messageType != ChatMessageType.text;
}

typedef OrderConversationMessage = OrderConversationMessageEntity;
