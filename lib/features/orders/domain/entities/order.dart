class OrderEntity {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? customerAltPhone;
  final String deliveryState;
  final String deliveryCity;
  final String deliveryAddress;
  final String? landmark;
  final String? lga;
  final String productName;
  final String status;
  final int quantity;
  final int paidQuantity;
  final int freeQuantity;
  final double basePrice;
  final double upsellAmount;
  final double totalAmount;
  final String paymentType; // 'pay_on_delivery' | 'prepaid'
  final String paymentStatus;
  final String fulfillmentType; // 'distributed_inventory' | 'client_package'
  final String clientName; // e.g. 'NovaCare'
  final String? packageCustodyId;
  final double clientDeliveryFee; // e.g. 5000.0
  final double agentEntitlement; // e.g. 2500.0
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
    this.landmark,
    this.lga,
    this.productName = 'Respira Detox Tea',
    required this.status,
    required this.quantity,
    this.paidQuantity = 1,
    this.freeQuantity = 0,
    required this.basePrice,
    required this.upsellAmount,
    required this.totalAmount,
    required this.paymentType,
    required this.paymentStatus,
    this.fulfillmentType = 'distributed_inventory',
    this.clientName = 'NovaCare',
    this.packageCustodyId,
    this.clientDeliveryFee = 5000.0,
    this.agentEntitlement = 2500.0,
    this.deliveryNotes,
    required this.createdAt,
  });

  bool get isPod => paymentType == 'pay_on_delivery' || paymentType == 'pod';
  bool get isClientPackage => fulfillmentType == 'client_package';
  bool get isDistributedInventory => fulfillmentType == 'distributed_inventory';
  bool get isDelivered => status == 'delivered';
  int get totalPhysicalQuantity => paidQuantity + freeQuantity > 0 ? paidQuantity + freeQuantity : quantity;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      case 'accepted':
        return 'Accepted';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'call_back':
        return 'Call Back';
      case 'new':
      case 'pending':
        return 'Pending';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}

