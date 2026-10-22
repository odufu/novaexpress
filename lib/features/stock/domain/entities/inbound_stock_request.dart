class StockRequestItemModel {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final int requestedQuantity;
  final int approvedQuantity;
  final double unitPrice;

  const StockRequestItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.requestedQuantity,
    this.approvedQuantity = 0,
    this.unitPrice = 0.0,
  });

  factory StockRequestItemModel.fromJson(Map<String, dynamic> json) {
    final prod = json['products'] as Map<String, dynamic>? ?? {};
    return StockRequestItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? prod['id']?.toString() ?? '',
      productName: prod['name']?.toString() ?? 'Product',
      sku: prod['sku']?.toString() ?? 'SKU',
      requestedQuantity: (json['requested_quantity'] as num?)?.toInt() ?? 0,
      approvedQuantity: (json['approved_quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (prod['base_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'sku': sku,
    'requested_quantity': requestedQuantity,
    'approved_quantity': approvedQuantity,
    'unit_price': unitPrice,
  };
}

class InboundStockRequest {
  final String id;
  final String requestId;
  final String dcName;
  final String? dcId;
  final String? riderId;
  final String riderName;
  final String riderCode;
  final String status; // 'pending', 'approved', 'fulfilled', 'rejected', 'Awaiting DC Review'
  final DateTime? requestDate;
  final String? notes;
  final Map<String, int> requestedQuantities;
  final Map<String, int> approvedQuantities;
  final List<StockRequestItemModel> items;

  const InboundStockRequest({
    this.id = '',
    required this.requestId,
    this.dcName = 'DC Warehouse',
    this.dcId,
    this.riderId,
    this.riderName = 'Delivery Agent',
    this.riderCode = 'PDA-RIDER',
    this.status = 'pending',
    this.requestDate,
    this.notes,
    this.requestedQuantities = const {},
    this.approvedQuantities = const {},
    this.items = const [],
  });

  bool get isPending {
    final s = status.toLowerCase();
    return s == 'pending' || s.contains('awaiting') || s == 'review';
  }

  bool get isFulfilled {
    final s = status.toLowerCase();
    return s == 'fulfilled' || s == 'completed';
  }

  bool get isApproved {
    final s = status.toLowerCase();
    return s == 'approved';
  }

  int get totalUnitsRequested {
    if (items.isNotEmpty) {
      return items.fold(0, (sum, i) => sum + i.requestedQuantity);
    }
    return requestedQuantities.values.fold(0, (sum, q) => sum + q);
  }

  factory InboundStockRequest.fromJson(Map<String, dynamic> json) {
    final da = json['delivery_agents'] as Map<String, dynamic>?;
    final user = da?['users'] as Map<String, dynamic>?;
    final first = user?['first_name']?.toString() ?? '';
    final last = user?['last_name']?.toString() ?? '';
    final fullName = '$first $last'.trim();
    final rCode = da?['agent_code']?.toString() ?? 'PDA-RIDER';
    final rawItems = json['stock_request_items'] as List? ?? [];
    final itemsList = rawItems
        .map((it) => StockRequestItemModel.fromJson(Map<String, dynamic>.from(it as Map)))
        .toList();

    final reqQtyMap = <String, int>{};
    final appQtyMap = <String, int>{};
    for (final it in itemsList) {
      reqQtyMap[it.productName] = it.requestedQuantity;
      appQtyMap[it.productName] = it.approvedQuantity;
    }

    return InboundStockRequest(
      id: json['id']?.toString() ?? '',
      requestId: json['request_number']?.toString() ?? 'REQ-000',
      dcName: 'DC Warehouse',
      dcId: json['distribution_center_id']?.toString(),
      riderId: json['delivery_agent_id']?.toString(),
      riderName: fullName.isNotEmpty ? fullName : 'Delivery Agent',
      riderCode: rCode,
      status: json['status']?.toString() ?? 'pending',
      requestDate: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      notes: json['notes']?.toString(),
      requestedQuantities: reqQtyMap,
      approvedQuantities: appQtyMap,
      items: itemsList,
    );
  }

  InboundStockRequest copyWith({
    String? id,
    String? requestId,
    String? dcName,
    String? dcId,
    String? riderId,
    String? riderName,
    String? riderCode,
    String? status,
    DateTime? requestDate,
    String? notes,
    Map<String, int>? requestedQuantities,
    Map<String, int>? approvedQuantities,
    List<StockRequestItemModel>? items,
  }) {
    return InboundStockRequest(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      dcName: dcName ?? this.dcName,
      dcId: dcId ?? this.dcId,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderCode: riderCode ?? this.riderCode,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      notes: notes ?? this.notes,
      requestedQuantities: requestedQuantities ?? this.requestedQuantities,
      approvedQuantities: approvedQuantities ?? this.approvedQuantities,
      items: items ?? this.items,
    );
  }
}
