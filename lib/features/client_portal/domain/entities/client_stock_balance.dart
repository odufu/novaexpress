/// Client Stock Balance Ledger Entity
/// Exactly matches and upgrades the Pangea Suite Query Report format.
class ClientStockBalance {
  final String id;
  final String clientId;
  final String? productId;
  final String itemCode; // SKU or Item Identifier
  final String itemName; // Product Name (e.g. 'Grazer Herbal Tea')
  final String itemGroup; // e.g. 'Novacare'
  final String warehouse; // e.g. 'Stores - NL', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL'
  final String stockUom; // Unit of Measure ('Nos', 'Pcs', 'Bottles')
  final double balanceQty; // Current physical balance units
  final double balanceValue; // Total monetary valuation (balanceQty * valuationRate)
  final double openingQty; // Balance at start of period
  final double openingValue; // Value at start of period
  final double inQty; // Intake from supplier invoices & transfers in
  final double inValue; // Total landed value of incoming stock
  final double outQty; // Dispatched & delivered to customers
  final double outValue; // Landed value of dispatched stock
  final double valuationRate; // Landed cost per unit (Base + Packaging + Transit)
  final double reservedStock; // Units reserved for active pending orders
  final String company; // e.g. 'Novacare Ltd'
  final int lowStockThreshold;
  final DateTime updatedAt;

  const ClientStockBalance({
    required this.id,
    required this.clientId,
    this.productId,
    required this.itemCode,
    required this.itemName,
    this.itemGroup = 'Novacare',
    required this.warehouse,
    this.stockUom = 'Nos',
    required this.balanceQty,
    required this.balanceValue,
    this.openingQty = 0.0,
    this.openingValue = 0.0,
    this.inQty = 0.0,
    this.inValue = 0.0,
    this.outQty = 0.0,
    this.outValue = 0.0,
    required this.valuationRate,
    this.reservedStock = 0.0,
    this.company = 'Novacare Ltd',
    this.lowStockThreshold = 20,
    required this.updatedAt,
  });

  /// Available units free to be allocated for new orders
  double get availableToSell => (balanceQty - reservedStock) > 0 ? (balanceQty - reservedStock) : 0.0;

  String get item => itemCode;
  String get stockStatus => status;

  /// Custody Classification
  bool get isCentralWarehouse {
    final lower = warehouse.toLowerCase();
    return lower.contains('stores') || lower.contains('central') || lower.contains('main');
  }

  bool get is3PLPartner {
    if (isCentralWarehouse) return false;
    final upper = warehouse.toUpperCase();
    return upper.contains('LOGISTICS') ||
        upper.contains('LIMITED') ||
        upper.contains('SERVICES') ||
        upper.contains('XPRESS') ||
        upper.contains('LTD');
  }

  bool get isRiderCustody => !isCentralWarehouse && !is3PLPartner;

  String get custodyTypeLabel {
    if (isCentralWarehouse) return 'Central DC Store';
    if (is3PLPartner) return '3PL Regional Hub';
    return 'Rider Fleet Custody';
  }

  /// Clean, human-friendly warehouse/holder name without redundant ERP suffixes
  String get cleanWarehouseName {
    var name = warehouse
        .replaceAll(RegExp(r'\s*-\s*Novacare\s*Ltd\s*-\s*NL', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*LOGISTICS\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*LTD\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*LIMITED\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*SERVICES\s*', caseSensitive: false), ' ')
        .trim();
    if (name.toLowerCase() == 'stores' || name.toLowerCase() == 'stores - nl') {
      return 'Central DC Stores (NL)';
    }
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name.isEmpty ? warehouse : name;
  }

  /// Stock health classification
  String get status {
    if (balanceQty <= 0) return 'Out of Stock';
    if (isRiderCustody && balanceQty > 40 && outQty == 0) return 'Stagnant in Fleet';
    if (balanceQty <= lowStockThreshold) return 'Low Stock';
    return 'Healthy';
  }

  factory ClientStockBalance.fromJson(Map<String, dynamic> json) {
    final balQty = (json['balance_qty'] as num?)?.toDouble() ??
        (json['Balance Qty'] as num?)?.toDouble() ??
        double.tryParse(json['Balance Qty']?.toString() ?? '') ??
        0.0;
    final rate = (json['valuation_rate'] as num?)?.toDouble() ??
        (json['Valuation Rate'] as num?)?.toDouble() ??
        double.tryParse(json['Valuation Rate']?.toString() ?? '') ??
        0.0;
    final balVal = (json['balance_value'] as num?)?.toDouble() ??
        (json['Balance Value'] as num?)?.toDouble() ??
        (balQty * rate);

    final item = json['item_name']?.toString() ?? json['Item Name']?.toString() ?? json['Item']?.toString() ?? 'Unknown Item';
    final code = json['item_code']?.toString() ?? json['Item']?.toString() ?? ('SKU-${item.replaceAll(' ', '').toUpperCase().substring(0, item.length >= 4 ? 4 : item.length)}');

    return ClientStockBalance(
      id: json['id']?.toString() ?? '${item}_${json['warehouse'] ?? json['Warehouse']}',
      clientId: json['client_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      itemCode: code,
      itemName: item,
      itemGroup: json['item_group']?.toString() ?? json['Item Group']?.toString() ?? 'Novacare',
      warehouse: json['warehouse']?.toString() ?? json['Warehouse']?.toString() ?? 'Stores - NL',
      stockUom: json['stock_uom']?.toString() ?? json['Stock UOM']?.toString() ?? 'Nos',
      balanceQty: balQty,
      balanceValue: balVal,
      openingQty: (json['opening_qty'] as num?)?.toDouble() ??
          (json['Opening Qty'] as num?)?.toDouble() ??
          double.tryParse(json['Opening Qty']?.toString() ?? '') ??
          0.0,
      openingValue: (json['opening_value'] as num?)?.toDouble() ??
          (json['Opening Value'] as num?)?.toDouble() ??
          double.tryParse(json['Opening Value']?.toString() ?? '') ??
          0.0,
      inQty: (json['in_qty'] as num?)?.toDouble() ??
          (json['In Qty'] as num?)?.toDouble() ??
          double.tryParse(json['In Qty']?.toString() ?? '') ??
          0.0,
      inValue: (json['in_value'] as num?)?.toDouble() ??
          (json['In Value'] as num?)?.toDouble() ??
          double.tryParse(json['In Value']?.toString() ?? '') ??
          0.0,
      outQty: (json['out_qty'] as num?)?.toDouble() ??
          (json['Out Qty'] as num?)?.toDouble() ??
          double.tryParse(json['Out Qty']?.toString() ?? '') ??
          0.0,
      outValue: (json['out_value'] as num?)?.toDouble() ??
          (json['Out Value'] as num?)?.toDouble() ??
          double.tryParse(json['Out Value']?.toString() ?? '') ??
          0.0,
      valuationRate: rate,
      reservedStock: (json['reserved_stock'] as num?)?.toDouble() ??
          (json['Reserved Stock'] as num?)?.toDouble() ??
          double.tryParse(json['Reserved Stock']?.toString() ?? '') ??
          0.0,
      company: json['company']?.toString() ?? json['Company']?.toString() ?? 'Novacare Ltd',
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 20,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'product_id': productId,
      'item_code': itemCode,
      'item_name': itemName,
      'item_group': itemGroup,
      'warehouse': warehouse,
      'stock_uom': stockUom,
      'balance_qty': balanceQty,
      'balance_value': balanceValue,
      'opening_qty': openingQty,
      'opening_value': openingValue,
      'in_qty': inQty,
      'in_value': inValue,
      'out_qty': outQty,
      'out_value': outValue,
      'valuation_rate': valuationRate,
      'reserved_stock': reservedStock,
      'company': company,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ClientStockBalance copyWith({
    String? id,
    String? clientId,
    String? productId,
    String? itemCode,
    String? itemName,
    String? itemGroup,
    String? warehouse,
    String? stockUom,
    double? balanceQty,
    double? balanceValue,
    double? openingQty,
    double? openingValue,
    double? inQty,
    double? inValue,
    double? outQty,
    double? outValue,
    double? valuationRate,
    double? reservedStock,
    String? company,
    int? lowStockThreshold,
    DateTime? updatedAt,
  }) {
    return ClientStockBalance(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      productId: productId ?? this.productId,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      itemGroup: itemGroup ?? this.itemGroup,
      warehouse: warehouse ?? this.warehouse,
      stockUom: stockUom ?? this.stockUom,
      balanceQty: balanceQty ?? this.balanceQty,
      balanceValue: balanceValue ?? this.balanceValue,
      openingQty: openingQty ?? this.openingQty,
      openingValue: openingValue ?? this.openingValue,
      inQty: inQty ?? this.inQty,
      inValue: inValue ?? this.inValue,
      outQty: outQty ?? this.outQty,
      outValue: outValue ?? this.outValue,
      valuationRate: valuationRate ?? this.valuationRate,
      reservedStock: reservedStock ?? this.reservedStock,
      company: company ?? this.company,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
