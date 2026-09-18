/// Represents an Order-level communication pipeline between:
/// - The Client (Merchant)
/// - The Handling Distribution Center (DC Manager)
/// - The Assigned Dispatch Rider
class OrderConversationEntity {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;

  // Multi-tenant participants
  final String clientId;
  final String clientName;
  final String? distributionCenterId;
  final String? distributionCenterName;
  final String? deliveryAgentId;
  final String? deliveryAgentName;
  final String? closerId;
  final String? closerName;
  final String? closerAvatarUrl;

  // Order state snapshot
  final String orderStatus;
  final String? currentProductName;
  final String? currentPackageName;
  final double currentTotalAmount;

  // WhatsApp-style conversation preview
  final String? lastMessageText;
  final String? lastMessageSenderName;
  final DateTime lastMessageAt;

  // Unread badge counters
  final int unreadClientCount;
  final int unreadDcCount;
  final int unreadRiderCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderConversationEntity({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.customerPhone,
    required this.clientId,
    required this.clientName,
    this.distributionCenterId,
    this.distributionCenterName,
    this.deliveryAgentId,
    this.deliveryAgentName,
    this.closerId,
    this.closerName,
    this.closerAvatarUrl,
    this.orderStatus = 'pending',
    this.currentProductName,
    this.currentPackageName,
    this.currentTotalAmount = 0.0,
    this.lastMessageText,
    this.lastMessageSenderName,
    required this.lastMessageAt,
    this.unreadClientCount = 0,
    this.unreadDcCount = 0,
    this.unreadRiderCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  OrderConversationEntity copyWith({
    String? id,
    String? orderId,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? clientId,
    String? clientName,
    String? distributionCenterId,
    String? distributionCenterName,
    String? deliveryAgentId,
    String? deliveryAgentName,
    String? closerId,
    String? closerName,
    String? closerAvatarUrl,
    String? orderStatus,
    String? currentProductName,
    String? currentPackageName,
    double? currentTotalAmount,
    String? lastMessageText,
    String? lastMessageSenderName,
    DateTime? lastMessageAt,
    int? unreadClientCount,
    int? unreadDcCount,
    int? unreadRiderCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderConversationEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      distributionCenterName: distributionCenterName ?? this.distributionCenterName,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      deliveryAgentName: deliveryAgentName ?? this.deliveryAgentName,
      closerId: closerId ?? this.closerId,
      closerName: closerName ?? this.closerName,
      closerAvatarUrl: closerAvatarUrl ?? this.closerAvatarUrl,
      orderStatus: orderStatus ?? this.orderStatus,
      currentProductName: currentProductName ?? this.currentProductName,
      currentPackageName: currentPackageName ?? this.currentPackageName,
      currentTotalAmount: currentTotalAmount ?? this.currentTotalAmount,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadClientCount: unreadClientCount ?? this.unreadClientCount,
      unreadDcCount: unreadDcCount ?? this.unreadDcCount,
      unreadRiderCount: unreadRiderCount ?? this.unreadRiderCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderConversationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

typedef OrderConversation = OrderConversationEntity;
