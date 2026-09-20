/// Item detail for Product Entry / Stock Intake Invoice
class ClientStockInvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double supplierUnitPrice; // Raw price per unit from manufacturer
  final double packagingCostPerUnit; // Custom box, foil, sticker, or sachet add-on
  final double transportationCostPerUnit; // Freight haulage & transit add-on
  final double handlingCostPerUnit; // Offloading, clearing, or QA inspection add-on
  final double otherAddonsPerUnit;
  final double effectiveLandedCostPerUnit; // Base + Packaging + Transport + Handling
  final double totalLandedCost; // quantity * effectiveLandedCostPerUnit
  final double targetRetailPrice; // Proposed catalog selling price
  final double projectedMarginPercent; // ((retail - landed) / retail) * 100

  const ClientStockInvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.supplierUnitPrice,
    this.packagingCostPerUnit = 0.0,
    this.transportationCostPerUnit = 0.0,
    this.handlingCostPerUnit = 0.0,
    this.otherAddonsPerUnit = 0.0,
    required this.effectiveLandedCostPerUnit,
    required this.totalLandedCost,
    this.targetRetailPrice = 0.0,
    this.projectedMarginPercent = 0.0,
  });

  String get sku => productSku;
  double get unitCost => supplierUnitPrice;
  double get packagingCost => packagingCostPerUnit;
  double get freightCost => transportationCostPerUnit;
  double get handlingCost => handlingCostPerUnit;
  double get effectiveLandedCost => effectiveLandedCostPerUnit;

  /// Factory constructor that automatically computes landed costs & margins
  factory ClientStockInvoiceItem.calculate({
    String id = '',
    String invoiceId = '',
    String? productId,
    required String productName,
    required String productSku,
    required int quantity,
    required double supplierUnitPrice,
    double packagingCostPerUnit = 0.0,
    double transportationCostPerUnit = 0.0,
    double handlingCostPerUnit = 0.0,
    double otherAddonsPerUnit = 0.0,
    double targetRetailPrice = 0.0,
  }) {
    final effectiveLanded = supplierUnitPrice +
        packagingCostPerUnit +
        transportationCostPerUnit +
        handlingCostPerUnit +
        otherAddonsPerUnit;
    final totalLanded = quantity * effectiveLanded;
    final margin = targetRetailPrice > 0
        ? (((targetRetailPrice - effectiveLanded) / targetRetailPrice) * 100.0).clamp(-100.0, 100.0)
        : 0.0;

    return ClientStockInvoiceItem(
      id: id,
      invoiceId: invoiceId,
      productId: productId,
      productName: productName,
      productSku: productSku,
      quantity: quantity,
      supplierUnitPrice: supplierUnitPrice,
      packagingCostPerUnit: packagingCostPerUnit,
      transportationCostPerUnit: transportationCostPerUnit,
      handlingCostPerUnit: handlingCostPerUnit,
      otherAddonsPerUnit: otherAddonsPerUnit,
      effectiveLandedCostPerUnit: effectiveLanded,
      totalLandedCost: totalLanded,
      targetRetailPrice: targetRetailPrice,
      projectedMarginPercent: margin,
    );
  }

  factory ClientStockInvoiceItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final supPrice = (json['supplier_unit_price'] as num?)?.toDouble() ?? 0.0;
    final packCost = (json['packaging_cost_per_unit'] as num?)?.toDouble() ?? 0.0;
    final transCost = (json['transportation_cost_per_unit'] as num?)?.toDouble() ?? 0.0;
    final handCost = (json['handling_cost_per_unit'] as num?)?.toDouble() ?? 0.0;
    final otherCost = (json['other_addons_per_unit'] as num?)?.toDouble() ?? 0.0;
    final landed = (json['effective_landed_cost_per_unit'] as num?)?.toDouble() ??
        (supPrice + packCost + transCost + handCost + otherCost);
    final totalLanded = (json['total_landed_cost'] as num?)?.toDouble() ?? (qty * landed);
    final retail = (json['target_retail_price'] as num?)?.toDouble() ?? 0.0;
    final margin = (json['projected_margin_percent'] as num?)?.toDouble() ??
        (retail > 0 ? (((retail - landed) / retail) * 100.0) : 0.0);

    return ClientStockInvoiceItem(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString() ?? 'General Item',
      productSku: json['product_sku']?.toString() ?? 'SKU-GEN',
      quantity: qty,
      supplierUnitPrice: supPrice,
      packagingCostPerUnit: packCost,
      transportationCostPerUnit: transCost,
      handlingCostPerUnit: handCost,
      otherAddonsPerUnit: otherCost,
      effectiveLandedCostPerUnit: landed,
      totalLandedCost: totalLanded,
      targetRetailPrice: retail,
      projectedMarginPercent: margin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'quantity': quantity,
      'supplier_unit_price': supplierUnitPrice,
      'packaging_cost_per_unit': packagingCostPerUnit,
      'transportation_cost_per_unit': transportationCostPerUnit,
      'handling_cost_per_unit': handlingCostPerUnit,
      'other_addons_per_unit': otherAddonsPerUnit,
      'effective_landed_cost_per_unit': effectiveLandedCostPerUnit,
      'total_landed_cost': totalLandedCost,
      'target_retail_price': targetRetailPrice,
      'projected_margin_percent': projectedMarginPercent,
    };
  }
}

/// Client Product Entry / Stock Intake Invoice Entity
class ClientStockInvoice {
  final String id;
  final String clientId;
  final String invoiceNumber;
  final String? supplierId;
  final String supplierName;
  final String destinationWarehouse;
  final DateTime entryDate;
  final String status; // 'draft', 'pending_inspection', 'received', 'verified', 'cancelled'
  final String paymentStatus; // 'unpaid', 'partially_paid', 'paid'
  final int totalUnits;
  final double subtotalRawProductCost;
  final double totalPackagingCost;
  final double totalTransportationCost;
  final double totalHandlingClearingCost;
  final double otherAddonsCost;
  final double grandTotalLandedCost;
  final String? waybillNumber;
  final String? paymentReceiptUrl;
  final String notes;
  final List<ClientStockInvoiceItem> items;
  final DateTime createdAt;

  String get targetWarehouse => destinationWarehouse;
  int get totalQuantity => totalUnits;
  double get grandTotalAmount => grandTotalLandedCost;
  bool get isProcessed => status == 'verified' || status == 'received';
  bool get hasPaymentReceipt => paymentReceiptUrl != null && paymentReceiptUrl!.trim().isNotEmpty;

  const ClientStockInvoice({
    required this.id,
    required this.clientId,
    required this.invoiceNumber,
    this.supplierId,
    required this.supplierName,
    this.destinationWarehouse = 'Stores - NL',
    required this.entryDate,
    this.status = 'verified',
    this.paymentStatus = 'unpaid',
    this.totalUnits = 0,
    this.subtotalRawProductCost = 0.0,
    this.totalPackagingCost = 0.0,
    this.totalTransportationCost = 0.0,
    this.totalHandlingClearingCost = 0.0,
    this.otherAddonsCost = 0.0,
    this.grandTotalLandedCost = 0.0,
    this.waybillNumber,
    this.paymentReceiptUrl,
    this.notes = '',
    this.items = const [],
    required this.createdAt,
  });

  factory ClientStockInvoice.fromJson(Map<String, dynamic> json) {
    List<ClientStockInvoiceItem> parsedItems = [];
    if (json['client_stock_invoice_items'] is List) {
      parsedItems = (json['client_stock_invoice_items'] as List)
          .map((i) => ClientStockInvoiceItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => ClientStockInvoiceItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    final rawNotes = json['notes']?.toString() ?? '';
    String? receipt = json['payment_receipt_url']?.toString();
    if (receipt == null || receipt.trim().isEmpty) {
      final match = RegExp(r'\[RECEIPT:\s*([^\s\]]+)\]').firstMatch(rawNotes);
      if (match != null) {
        receipt = match.group(1);
      }
    }

    return ClientStockInvoice(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? 'INV-STK-001',
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name']?.toString() ?? 'Vendor',
      destinationWarehouse: json['destination_warehouse']?.toString() ?? 'Stores - NL',
      entryDate: json['entry_date'] != null ? DateTime.tryParse(json['entry_date'].toString()) ?? DateTime.now() : DateTime.now(),
      status: json['status']?.toString() ?? 'verified',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      subtotalRawProductCost: (json['subtotal_raw_product_cost'] as num?)?.toDouble() ?? 0.0,
      totalPackagingCost: (json['total_packaging_cost'] as num?)?.toDouble() ?? 0.0,
      totalTransportationCost: (json['total_transportation_cost'] as num?)?.toDouble() ?? 0.0,
      totalHandlingClearingCost: (json['total_handling_clearing_cost'] as num?)?.toDouble() ?? 0.0,
      otherAddonsCost: (json['other_addons_cost'] as num?)?.toDouble() ?? 0.0,
      grandTotalLandedCost: (json['grand_total_landed_cost'] as num?)?.toDouble() ?? 0.0,
      waybillNumber: json['waybill_number']?.toString(),
      paymentReceiptUrl: receipt,
      notes: rawNotes,
      items: parsedItems,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'destination_warehouse': destinationWarehouse,
      'entry_date': entryDate.toIso8601String().split('T').first,
      'status': status,
      'payment_status': paymentStatus,
      'total_units': totalUnits,
      'subtotal_raw_product_cost': subtotalRawProductCost,
      'total_packaging_cost': totalPackagingCost,
      'total_transportation_cost': totalTransportationCost,
      'total_handling_clearing_cost': totalHandlingClearingCost,
      'other_addons_cost': otherAddonsCost,
      'grand_total_landed_cost': grandTotalLandedCost,
      if (paymentReceiptUrl != null) 'payment_receipt_url': paymentReceiptUrl,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ClientStockInvoice copyWith({
    String? id,
    String? clientId,
    String? invoiceNumber,
    String? supplierId,
    String? supplierName,
    String? destinationWarehouse,
    DateTime? entryDate,
    String? status,
    String? paymentStatus,
    int? totalUnits,
    double? subtotalRawProductCost,
    double? totalPackagingCost,
    double? totalTransportationCost,
    double? totalHandlingClearingCost,
    double? otherAddonsCost,
    double? grandTotalLandedCost,
    String? waybillNumber,
    String? paymentReceiptUrl,
    String? notes,
    List<ClientStockInvoiceItem>? items,
    DateTime? createdAt,
  }) {
    return ClientStockInvoice(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      destinationWarehouse: destinationWarehouse ?? this.destinationWarehouse,
      entryDate: entryDate ?? this.entryDate,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalUnits: totalUnits ?? this.totalUnits,
      subtotalRawProductCost: subtotalRawProductCost ?? this.subtotalRawProductCost,
      totalPackagingCost: totalPackagingCost ?? this.totalPackagingCost,
      totalTransportationCost: totalTransportationCost ?? this.totalTransportationCost,
      totalHandlingClearingCost: totalHandlingClearingCost ?? this.totalHandlingClearingCost,
      otherAddonsCost: otherAddonsCost ?? this.otherAddonsCost,
      grandTotalLandedCost: grandTotalLandedCost ?? this.grandTotalLandedCost,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      paymentReceiptUrl: paymentReceiptUrl ?? this.paymentReceiptUrl,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
