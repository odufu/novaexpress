import '../../domain/entities/order_conversation.dart';

class OrderConversationModel extends OrderConversationEntity {
  const OrderConversationModel({
    required super.id,
    required super.orderId,
    required super.orderNumber,
    required super.customerName,
    super.customerPhone,
    required super.clientId,
    required super.clientName,
    super.distributionCenterId,
    super.distributionCenterName,
    super.deliveryAgentId,
    super.deliveryAgentName,
    super.closerId,
    super.closerName,
    super.closerAvatarUrl,
    super.orderStatus,
    super.currentProductName,
    super.currentPackageName,
    super.currentTotalAmount,
    super.lastMessageText,
    super.lastMessageSenderName,
    required super.lastMessageAt,
    super.unreadClientCount,
    super.unreadDcCount,
    super.unreadRiderCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OrderConversationModel.fromJson(Map<String, dynamic> json) {
    return OrderConversationModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: json['customer_phone']?.toString(),
      clientId: json['client_id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      distributionCenterId: json['distribution_center_id']?.toString(),
      distributionCenterName: json['distribution_center_name']?.toString(),
      deliveryAgentId: json['delivery_agent_id']?.toString(),
      deliveryAgentName: json['delivery_agent_name']?.toString(),
      closerId: json['closer_id']?.toString(),
      closerName: json['closer_name']?.toString() ??
          (json['client_closers'] is Map ? json['client_closers']['full_name']?.toString() : null),
      closerAvatarUrl: json['closer_avatar_url']?.toString() ??
          (json['client_closers'] is Map ? json['client_closers']['avatar_url']?.toString() : null),
      orderStatus: json['order_status']?.toString() ?? 'pending',
      currentProductName: json['current_product_name']?.toString(),
      currentPackageName: json['current_package_name']?.toString(),
      currentTotalAmount: (json['current_total_amount'] as num?)?.toDouble() ?? 0.0,
      lastMessageText: json['last_message_text']?.toString(),
      lastMessageSenderName: json['last_message_sender_name']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadClientCount: (json['unread_client_count'] as num?)?.toInt() ?? 0,
      unreadDcCount: (json['unread_dc_count'] as num?)?.toInt() ?? 0,
      unreadRiderCount: (json['unread_rider_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory OrderConversationModel.fromEntity(OrderConversation entity) {
    return OrderConversationModel(
      id: entity.id,
      orderId: entity.orderId,
      orderNumber: entity.orderNumber,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      clientId: entity.clientId,
      clientName: entity.clientName,
      distributionCenterId: entity.distributionCenterId,
      distributionCenterName: entity.distributionCenterName,
      deliveryAgentId: entity.deliveryAgentId,
      deliveryAgentName: entity.deliveryAgentName,
      closerId: entity.closerId,
      closerName: entity.closerName,
      closerAvatarUrl: entity.closerAvatarUrl,
      orderStatus: entity.orderStatus,
      currentProductName: entity.currentProductName,
      currentPackageName: entity.currentPackageName,
      currentTotalAmount: entity.currentTotalAmount,
      lastMessageText: entity.lastMessageText,
      lastMessageSenderName: entity.lastMessageSenderName,
      lastMessageAt: entity.lastMessageAt,
      unreadClientCount: entity.unreadClientCount,
      unreadDcCount: entity.unreadDcCount,
      unreadRiderCount: entity.unreadRiderCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'client_id': clientId,
      'client_name': clientName,
      'distribution_center_id': distributionCenterId,
      'distribution_center_name': distributionCenterName,
      'delivery_agent_id': deliveryAgentId,
      'delivery_agent_name': deliveryAgentName,
      'closer_id': closerId,
      'closer_name': closerName,
      'closer_avatar_url': closerAvatarUrl,
      'order_status': orderStatus,
      'current_product_name': currentProductName,
      'current_package_name': currentPackageName,
      'current_total_amount': currentTotalAmount,
      'last_message_text': lastMessageText,
      'last_message_sender_name': lastMessageSenderName,
      'last_message_at': lastMessageAt.toIso8601String(),
      'unread_client_count': unreadClientCount,
      'unread_dc_count': unreadDcCount,
      'unread_rider_count': unreadRiderCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
