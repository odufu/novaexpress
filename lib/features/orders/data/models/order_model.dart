import '../../domain/entities/order.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.customerName,
    required super.customerPhone,
    super.customerAltPhone,
    required super.deliveryState,
    required super.deliveryCity,
    required super.deliveryAddress,
    required super.status,
    required super.quantity,
    required super.basePrice,
    required super.upsellAmount,
    required super.totalAmount,
    required super.paymentType,
    required super.paymentStatus,
    super.deliveryNotes,
    required super.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? 'Customer',
      customerPhone: json['customer_phone'] ?? '',
      customerAltPhone: json['customer_alt_phone'],
      deliveryState: json['delivery_state'] ?? '',
      deliveryCity: json['delivery_city'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      status: json['status'] ?? 'accepted',
      quantity: json['quantity'] ?? 1,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      upsellAmount: (json['upsell_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: json['payment_type'] ?? 'pay_on_delivery',
      paymentStatus: json['payment_status'] ?? 'pending',
      deliveryNotes: json['delivery_notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_alt_phone': customerAltPhone,
      'delivery_state': deliveryState,
      'delivery_city': deliveryCity,
      'delivery_address': deliveryAddress,
      'status': status,
      'quantity': quantity,
      'base_price': basePrice,
      'upsell_amount': upsellAmount,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'payment_status': paymentStatus,
      'delivery_notes': deliveryNotes,
    };
  }
}
