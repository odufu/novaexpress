class RiderStockAllocation {
  final String id;
  final String riderId;
  final String riderName;
  final String riderCode;
  final String productId;
  final String productName;
  final String sku;
  final String clientName;
  final int allocatedUnits;
  final int deliveredUnits;
  final int inCustodyUnits;
  final double unitPrice;
  final DateTime allocatedAt;
  final String fulfillmentType;

  const RiderStockAllocation({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.productId,
    required this.productName,
    required this.sku,
    this.clientName = 'Novacare Limited',
    required this.allocatedUnits,
    this.deliveredUnits = 0,
    required this.inCustodyUnits,
    required this.unitPrice,
    required this.allocatedAt,
    this.fulfillmentType = 'distributed_inventory',
  });

  bool get isLowStock => inCustodyUnits <= 2;

  RiderStockAllocation copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? riderCode,
    String? productId,
    String? productName,
    String? sku,
    String? clientName,
    int? allocatedUnits,
    int? deliveredUnits,
    int? inCustodyUnits,
    double? unitPrice,
    DateTime? allocatedAt,
    String? fulfillmentType,
  }) {
    return RiderStockAllocation(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderCode: riderCode ?? this.riderCode,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      clientName: clientName ?? this.clientName,
      allocatedUnits: allocatedUnits ?? this.allocatedUnits,
      deliveredUnits: deliveredUnits ?? this.deliveredUnits,
      inCustodyUnits: inCustodyUnits ?? this.inCustodyUnits,
      unitPrice: unitPrice ?? this.unitPrice,
      allocatedAt: allocatedAt ?? this.allocatedAt,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
    );
  }

  factory RiderStockAllocation.fromJson(Map<String, dynamic> json) {
    return RiderStockAllocation(
      id: json['id']?.toString() ?? '',
      riderId: json['rider_id']?.toString() ?? json['riderId'] ?? '',
      riderName: json['rider_name']?.toString() ?? json['riderName'] ?? 'Rider',
      riderCode: json['rider_code']?.toString() ?? json['riderCode'] ?? '',
      productId: json['product_id']?.toString() ?? json['productId'] ?? '',
      productName: json['product_name']?.toString() ?? json['productName'] ?? 'Product',
      sku: json['sku']?.toString() ?? 'SKU-001',
      clientName: json['client_name']?.toString() ?? json['clientName'] ?? 'Novacare Limited',
      allocatedUnits: (json['allocated_units'] as num?)?.toInt() ?? (json['allocatedUnits'] as num?)?.toInt() ?? 0,
      deliveredUnits: (json['delivered_units'] as num?)?.toInt() ?? (json['deliveredUnits'] as num?)?.toInt() ?? 0,
      inCustodyUnits: (json['in_custody_units'] as num?)?.toInt() ?? (json['inCustodyUnits'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      allocatedAt: json['allocated_at'] != null
          ? DateTime.tryParse(json['allocated_at'].toString()) ?? DateTime.now()
          : (json['allocatedAt'] != null ? DateTime.tryParse(json['allocatedAt'].toString()) ?? DateTime.now() : DateTime.now()),
      fulfillmentType: json['fulfillment_type']?.toString() ?? json['fulfillmentType'] ?? 'distributed_inventory',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rider_id': riderId,
      'rider_name': riderName,
      'rider_code': riderCode,
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'client_name': clientName,
      'allocated_units': allocatedUnits,
      'delivered_units': deliveredUnits,
      'in_custody_units': inCustodyUnits,
      'unit_price': unitPrice,
      'allocated_at': allocatedAt.toIso8601String(),
      'fulfillment_type': fulfillmentType,
    };
  }
}
