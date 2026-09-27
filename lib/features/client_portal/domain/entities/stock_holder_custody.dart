/// Domain entity representing a physical holder possessing merchant stock
/// (Distribution Centers, PDAs / Dispatch Personnel, Central Storage / In-Transit)
/// with full period movement (opening, in, out, closing) and dual valuation.
class StockHolderCustodyEntity {
  final String id;
  final String holderId;
  final String holderName;
  final String holderType; // 'Distribution Center', 'PDA / Dispatch Personnel', 'Central Storage / In-Transit'
  final String state;
  final String lga;
  final String city;
  final String phone;
  final String productId;
  final String productSku;
  final String productName;
  final int openingQty;
  final double openingValue;
  final int inQty;
  final double inValue;
  final int outQty;
  final double outValue;
  final int closingQty;
  final double closingValue;
  final double valuationRate;
  final DateTime lastUpdated;
  final String status; // 'Active Custody', 'Low Stock', 'Out of Stock'

  const StockHolderCustodyEntity({
    required this.id,
    required this.holderId,
    required this.holderName,
    required this.holderType,
    required this.state,
    required this.lga,
    required this.city,
    this.phone = '',
    required this.productId,
    required this.productSku,
    required this.productName,
    this.openingQty = 0,
    this.openingValue = 0.0,
    this.inQty = 0,
    this.inValue = 0.0,
    this.outQty = 0,
    this.outValue = 0.0,
    required this.closingQty,
    required this.closingValue,
    required this.valuationRate,
    required this.lastUpdated,
    this.status = 'Active Custody',
  });

  bool get _isDcType {
    final t = holderType.toLowerCase();
    final n = holderName.toLowerCase();
    return t.contains('center') ||
        t.contains('hub') ||
        t.contains('dc') ||
        t.contains('grand') ||
        t.contains('general') ||
        n.contains('center') ||
        n.contains('hub') ||
        n.contains('dc') ||
        n.contains('distribution');
  }

  bool get isGrandDc =>
      holderType.toLowerCase().contains('grand') ||
      holderName.toLowerCase().contains('grand') ||
      holderName.toLowerCase().contains('wuse');

  bool get isHubDc =>
      ((holderType.toLowerCase().contains('hub') ||
        holderName.toLowerCase().contains('hub') ||
        holderName.toLowerCase().contains('kaduna')) &&
      !isGrandDc);

  bool get isGeneralDc =>
      holderType.toLowerCase().contains('general') ||
      holderName.toLowerCase().contains('general') ||
      holderName.toLowerCase().contains('otukpo') ||
      holderName.toLowerCase().contains('lagos') ||
      (_isDcType && !isGrandDc && !isHubDc);
  bool get isDistributionCenter => _isDcType;
  bool get isPdaRider => holderType.toLowerCase().contains('pda') || holderType.toLowerCase().contains('dispatch') || holderType.toLowerCase().contains('rider');
  bool get isInTransitOrDepot => !isPdaRider && (holderType.toLowerCase().contains('transit') || holderType.toLowerCase().contains('depot') || holderType.toLowerCase().contains('storage'));

  StockHolderCustodyEntity copyWith({
    String? id,
    String? holderId,
    String? holderName,
    String? holderType,
    String? state,
    String? lga,
    String? city,
    String? phone,
    String? productId,
    String? productSku,
    String? productName,
    int? openingQty,
    double? openingValue,
    int? inQty,
    double? inValue,
    int? outQty,
    double? outValue,
    int? closingQty,
    double? closingValue,
    double? valuationRate,
    DateTime? lastUpdated,
    String? status,
  }) {
    return StockHolderCustodyEntity(
      id: id ?? this.id,
      holderId: holderId ?? this.holderId,
      holderName: holderName ?? this.holderName,
      holderType: holderType ?? this.holderType,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      productId: productId ?? this.productId,
      productSku: productSku ?? this.productSku,
      productName: productName ?? this.productName,
      openingQty: openingQty ?? this.openingQty,
      openingValue: openingValue ?? this.openingValue,
      inQty: inQty ?? this.inQty,
      inValue: inValue ?? this.inValue,
      outQty: outQty ?? this.outQty,
      outValue: outValue ?? this.outValue,
      closingQty: closingQty ?? this.closingQty,
      closingValue: closingValue ?? this.closingValue,
      valuationRate: valuationRate ?? this.valuationRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
    );
  }

  factory StockHolderCustodyEntity.fromJson(Map<String, dynamic> json) {
    return StockHolderCustodyEntity(
      id: (json['id'] ?? '').toString(),
      holderId: (json['holder_id'] ?? json['holderId'] ?? '').toString(),
      holderName: (json['holder_name'] ?? json['holderName'] ?? 'Fulfillment Holder').toString(),
      holderType: (json['holder_type'] ?? json['holderType'] ?? 'Distribution Center').toString(),
      state: (json['state'] ?? 'Lagos').toString(),
      lga: (json['lga'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      productSku: (json['product_sku'] ?? json['productSku'] ?? '').toString(),
      productName: (json['product_name'] ?? json['productName'] ?? '').toString(),
      openingQty: (json['opening_qty'] as num?)?.toInt() ?? 0,
      openingValue: (json['opening_value'] as num?)?.toDouble() ?? 0.0,
      inQty: (json['in_qty'] as num?)?.toInt() ?? 0,
      inValue: (json['in_value'] as num?)?.toDouble() ?? 0.0,
      outQty: (json['out_qty'] as num?)?.toInt() ?? 0,
      outValue: (json['out_value'] as num?)?.toDouble() ?? 0.0,
      closingQty: (json['closing_qty'] ?? json['balance_qty'] as num?)?.toInt() ?? 0,
      closingValue: (json['closing_value'] ?? json['balance_value'] as num?)?.toDouble() ?? 0.0,
      valuationRate: (json['valuation_rate'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: (json['status'] ?? 'Active Custody').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'holder_id': holderId,
      'holder_name': holderName,
      'holder_type': holderType,
      'state': state,
      'lga': lga,
      'city': city,
      'phone': phone,
      'product_id': productId,
      'product_sku': productSku,
      'product_name': productName,
      'opening_qty': openingQty,
      'opening_value': openingValue,
      'in_qty': inQty,
      'in_value': inValue,
      'out_qty': outQty,
      'out_value': outValue,
      'closing_qty': closingQty,
      'closing_value': closingValue,
      'valuation_rate': valuationRate,
      'last_updated': lastUpdated.toIso8601String(),
      'status': status,
    };
  }
}
