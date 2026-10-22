class UpgRequest {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? deliveryAddress;
  final String closerId;
  final String closerName;
  final String closerCode;
  final String originalProduct;
  final int originalQuantity;
  final double originalAmount;
  final String upgradedProduct;
  final int upgradedQuantity;
  final double upgradedAmount;
  final double upsellDelta;
  final String reason;
  final String status; // "pending", "approved", "rejected"
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;

  const UpgRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    this.deliveryAddress,
    required this.closerId,
    required this.closerName,
    required this.closerCode,
    required this.originalProduct,
    required this.originalQuantity,
    required this.originalAmount,
    required this.upgradedProduct,
    required this.upgradedQuantity,
    required this.upgradedAmount,
    required this.upsellDelta,
    required this.reason,
    this.status = "pending",
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
  });

  bool get isPending => status.toLowerCase() == "pending";
  bool get isApproved => status.toLowerCase() == "approved";
  bool get isRejected => status.toLowerCase() == "rejected";

  double get upsellPercentage => originalAmount > 0
      ? ((upsellDelta / originalAmount) * 100).clamp(0.0, 500.0)
      : 0.0;

  factory UpgRequest.fromJson(Map<String, dynamic> json) {
    return UpgRequest(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? 'TRK-UPG',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: json['customer_phone']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString(),
      closerId: json['closer_id']?.toString() ?? '',
      closerName: json['closer_name']?.toString() ?? 'Sales Rep',
      closerCode: json['closer_code']?.toString() ?? 'CLS',
      originalProduct: json['original_product']?.toString() ?? 'Original Package',
      originalQuantity: (json['original_quantity'] as num?)?.toInt() ?? 1,
      originalAmount: (json['original_amount'] as num?)?.toDouble() ?? 0.0,
      upgradedProduct: json['upgraded_product']?.toString() ?? 'Upgraded Package',
      upgradedQuantity: (json['upgraded_quantity'] as num?)?.toInt() ?? 1,
      upgradedAmount: (json['upgraded_amount'] as num?)?.toDouble() ?? 0.0,
      upsellDelta: (json['upsell_delta'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? 'Customer opted for higher treatment course.',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      approvedBy: json['approved_by']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'closer_id': closerId,
      'closer_name': closerName,
      'closer_code': closerCode,
      'original_product': originalProduct,
      'original_quantity': originalQuantity,
      'original_amount': originalAmount,
      'upgraded_product': upgradedProduct,
      'upgraded_quantity': upgradedQuantity,
      'upgraded_amount': upgradedAmount,
      'upsell_delta': upsellDelta,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'rejection_reason': rejectionReason,
    };
  }

  UpgRequest copyWith({
    String? id,
    String? orderId,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? closerId,
    String? closerName,
    String? closerCode,
    String? originalProduct,
    int? originalQuantity,
    double? originalAmount,
    String? upgradedProduct,
    int? upgradedQuantity,
    double? upgradedAmount,
    double? upsellDelta,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
  }) {
    return UpgRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      closerId: closerId ?? this.closerId,
      closerName: closerName ?? this.closerName,
      closerCode: closerCode ?? this.closerCode,
      originalProduct: originalProduct ?? this.originalProduct,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      originalAmount: originalAmount ?? this.originalAmount,
      upgradedProduct: upgradedProduct ?? this.upgradedProduct,
      upgradedQuantity: upgradedQuantity ?? this.upgradedQuantity,
      upgradedAmount: upgradedAmount ?? this.upgradedAmount,
      upsellDelta: upsellDelta ?? this.upsellDelta,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
