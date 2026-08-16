class OrderEntity {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? customerAltPhone;
  final String deliveryState;
  final String deliveryCity;
  final String deliveryAddress;
  final String status;
  final int quantity;
  final double basePrice;
  final double upsellAmount;
  final double totalAmount;
  final String paymentType;
  final String paymentStatus;
  final String? deliveryNotes;
  final DateTime createdAt;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerAltPhone,
    required this.deliveryState,
    required this.deliveryCity,
    required this.deliveryAddress,
    required this.status,
    required this.quantity,
    required this.basePrice,
    required this.upsellAmount,
    required this.totalAmount,
    required this.paymentType,
    required this.paymentStatus,
    this.deliveryNotes,
    required this.createdAt,
  });

  bool get isPod => paymentType == 'pay_on_delivery';
  bool get isDelivered => status == 'delivered';
}
