class CustomerLead {
  final String id;
  final String clientId;
  final String? assignedCloserId;
  final String? assignedCloserName;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String deliveryState;
  final String deliveryLga;
  final String productInterest;
  final String packageInterest;
  final String status; // 'new_lead', 'calling', 'call_back', 'confirmed', 'rejected', 'order_created'
  final String? callNotes;
  final String? convertedOrderId;
  final DateTime? lastCalledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerLead({
    required this.id,
    required this.clientId,
    this.assignedCloserId,
    this.assignedCloserName,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress = '',
    this.deliveryState = 'Federal Capital Territory',
    this.deliveryLga = 'Abuja Municipal (AMAC)',
    this.productInterest = 'Grazer Tea',
    this.packageInterest = '2 Packs Promo Deal',
    this.status = 'new_lead',
    this.callNotes,
    this.convertedOrderId,
    this.lastCalledAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isNew => status == 'new_lead';
  bool get isCalling => status == 'calling';
  bool get isCallBack => status == 'call_back';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isOrderCreated => status == 'order_created';

  factory CustomerLead.fromJson(Map<String, dynamic> json) {
    return CustomerLead(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      assignedCloserId: json['assigned_closer_id']?.toString(),
      assignedCloserName: json['client_closers'] is Map
          ? json['client_closers']['full_name']?.toString()
          : json['assigned_closer_name']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Customer Lead',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      deliveryState: json['delivery_state']?.toString() ?? 'Federal Capital Territory',
      deliveryLga: json['delivery_lga']?.toString() ?? 'Abuja Municipal (AMAC)',
      productInterest: json['product_interest']?.toString() ?? 'Grazer Tea',
      packageInterest: json['package_interest']?.toString() ?? '2 Packs Promo Deal',
      status: json['status']?.toString() ?? 'new_lead',
      callNotes: json['call_notes']?.toString(),
      convertedOrderId: json['converted_order_id']?.toString() ?? json['order_id']?.toString(),
      lastCalledAt: json['last_called_at'] != null ? DateTime.tryParse(json['last_called_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'assigned_closer_id': assignedCloserId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'delivery_state': deliveryState,
      'delivery_lga': deliveryLga,
      'product_interest': productInterest,
      'package_interest': packageInterest,
      'status': status,
      'call_notes': callNotes,
      'converted_order_id': convertedOrderId,
      'last_called_at': lastCalledAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CustomerLead copyWith({
    String? id,
    String? clientId,
    String? assignedCloserId,
    String? assignedCloserName,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? deliveryState,
    String? deliveryLga,
    String? productInterest,
    String? packageInterest,
    String? status,
    String? callNotes,
    String? convertedOrderId,
    DateTime? lastCalledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerLead(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      assignedCloserId: assignedCloserId ?? this.assignedCloserId,
      assignedCloserName: assignedCloserName ?? this.assignedCloserName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      deliveryState: deliveryState ?? this.deliveryState,
      deliveryLga: deliveryLga ?? this.deliveryLga,
      productInterest: productInterest ?? this.productInterest,
      packageInterest: packageInterest ?? this.packageInterest,
      status: status ?? this.status,
      callNotes: callNotes ?? this.callNotes,
      convertedOrderId: convertedOrderId ?? this.convertedOrderId,
      lastCalledAt: lastCalledAt ?? this.lastCalledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
