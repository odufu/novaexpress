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
    super.landmark,
    super.lga,
    super.productName,
    required super.status,
    required super.quantity,
    super.paidQuantity,
    super.freeQuantity,
    required super.basePrice,
    required super.upsellAmount,
    required super.totalAmount,
    required super.paymentType,
    required super.paymentStatus,
    super.fulfillmentType,
    super.clientName,
    super.packageCustodyId,
    super.clientDeliveryFee,
    super.agentEntitlement,
    super.deliveryNotes,
    required super.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['products'];
    String name = 'Respira Detox Tea';
    if (rawProduct is Map && rawProduct['name'] != null) {
      name = rawProduct['name'].toString();
    } else if (json['product_name'] != null) {
      name = json['product_name'].toString();
    }

    final notes = json['delivery_notes']?.toString() ?? '';
    String fulfillment = json['fulfillment_type'] ?? 'distributed_inventory';
    if (notes.contains('Client Package')) {
      fulfillment = 'client_package';
    }

    int paid = json['paid_quantity'] ?? json['quantity'] ?? 1;
    int free = json['free_quantity'] ?? 0;
    if (notes.contains('5 Paid + 1 Free')) {
      paid = 5;
      free = 1;
    }

    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? 'Customer',
      customerPhone: json['customer_phone'] ?? '',
      customerAltPhone: json['customer_alt_phone'],
      deliveryState: json['delivery_state'] ?? '',
      deliveryCity: json['delivery_city'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      landmark: json['landmark'],
      lga: json['lga'],
      productName: name,
      status: json['status'] ?? 'accepted',
      quantity: json['quantity'] ?? 1,
      paidQuantity: paid,
      freeQuantity: free,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      upsellAmount: (json['upsell_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: json['payment_type'] ?? 'pay_on_delivery',
      paymentStatus: json['payment_status'] ?? 'pending',
      fulfillmentType: fulfillment,
      clientName: json['client_name'] ?? 'Novacare Limited',
      packageCustodyId: json['package_custody_id'],
      clientDeliveryFee: (json['client_delivery_fee'] as num?)?.toDouble() ?? 5000.0,
      agentEntitlement: (json['agent_entitlement'] as num?)?.toDouble() ?? 2500.0,
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
      'landmark': landmark,
      'lga': lga,
      'status': status,
      'quantity': quantity,
      'paid_quantity': paidQuantity,
      'free_quantity': freeQuantity,
      'base_price': basePrice,
      'upsell_amount': upsellAmount,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'payment_status': paymentStatus,
      'fulfillment_type': fulfillmentType,
      'client_name': clientName,
      'package_custody_id': packageCustodyId,
      'client_delivery_fee': clientDeliveryFee,
      'agent_entitlement': agentEntitlement,
      'delivery_notes': deliveryNotes,
    };
  }
}
