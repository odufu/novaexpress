import 'package:flutter/foundation.dart';

@immutable
class StockTransferItemRecord {
  final String id;
  final String transferId;
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final int quantityReceived;
  final int quantityDamaged;
  final int quantityMissing;
  final String? itemNotes;

  const StockTransferItemRecord({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    this.quantityReceived = 0,
    this.quantityDamaged = 0,
    this.quantityMissing = 0,
    this.itemNotes,
  });

  int get quantityShipped => quantity;

  bool get hasDiscrepancy =>
      quantityDamaged > 0 ||
      quantityMissing > 0 ||
      (quantityReceived > 0 && quantityReceived != quantity);

  factory StockTransferItemRecord.fromJson(Map<String, dynamic> json) {
    // Product details may be nested if joined or flat
    final productMap = json['product'] as Map<String, dynamic>?;
    final pName = productMap != null
        ? (productMap['name'] ?? '')
        : (json['product_name'] ?? json['name'] ?? '');
    final pSku = productMap != null
        ? (productMap['sku'] ?? '')
        : (json['sku'] ?? '');

    return StockTransferItemRecord(
      id: (json['id'] ?? '').toString(),
      transferId: (json['transfer_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: pName.toString(),
      sku: pSku.toString(),
      quantity: (json['quantity_shipped'] ?? json['quantity'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantity_received'] ?? json['quantityReceived'] as num?)?.toInt() ?? 0,
      quantityDamaged: (json['quantity_damaged'] ?? json['quantityDamaged'] as num?)?.toInt() ?? 0,
      quantityMissing: (json['quantity_missing'] ?? json['quantityMissing'] as num?)?.toInt() ?? 0,
      itemNotes: (json['item_notes'] ?? json['itemNotes']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transfer_id': transferId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'quantity': quantity,
        'quantity_received': quantityReceived,
        'quantity_damaged': quantityDamaged,
        'quantity_missing': quantityMissing,
        'item_notes': itemNotes,
      };

  StockTransferItemRecord copyWith({
    String? id,
    String? transferId,
    String? productId,
    String? productName,
    String? sku,
    int? quantity,
    int? quantityReceived,
    int? quantityDamaged,
    int? quantityMissing,
    String? itemNotes,
  }) {
    return StockTransferItemRecord(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityDamaged: quantityDamaged ?? this.quantityDamaged,
      quantityMissing: quantityMissing ?? this.quantityMissing,
      itemNotes: itemNotes ?? this.itemNotes,
    );
  }
}

@immutable
class StockTransferRecord {
  final String id;
  final String transferNumber;
  final String transferType; // client_supply, dc_to_rider, rider_return, inter_dc
  final String status; // draft, dispatched, in_transit, pending_rider_acceptance, completed, rejected, discrepancy_reported
  final String? clientId;
  final String? clientName;
  final String? sourceWarehouseId;
  final String? sourceWarehouseName;
  final String? destinationWarehouseId;
  final String? destinationWarehouseName;
  final String? sourceDcId;
  final String? destinationDcId;
  final String? senderId;
  final String? senderName;
  final String? senderRole;
  final String? senderSignatureUrl;
  final DateTime? dispatchedAt;
  final String? receiverId;
  final String? receiverName;
  final String? receiverRole;
  final String? receiverSignatureUrl;
  final DateTime? receivedAt;
  final bool hasDiscrepancy;
  final String? discrepancyNotes;
  final String? notes;
  final DateTime createdAt;
  final List<StockTransferItemRecord> items;

  const StockTransferRecord({
    required this.id,
    required this.transferNumber,
    required this.transferType,
    required this.status,
    this.clientId,
    this.clientName,
    this.sourceWarehouseId,
    this.sourceWarehouseName,
    this.destinationWarehouseId,
    this.destinationWarehouseName,
    this.sourceDcId,
    this.destinationDcId,
    this.senderId,
    this.senderName,
    this.senderRole,
    this.senderSignatureUrl,
    this.dispatchedAt,
    this.receiverId,
    this.receiverName,
    this.receiverRole,
    this.receiverSignatureUrl,
    this.receivedAt,
    this.hasDiscrepancy = false,
    this.discrepancyNotes,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  String get waybillNumber => transferNumber;

  bool get isClientSupply => transferType == 'client_supply' || transferType == 'client_to_dc';
  bool get isDcToRider => transferType == 'dc_to_rider';
  bool get isRiderReturn => transferType == 'rider_return';
  bool get isInterDc => transferType == 'inter_dc';

  bool get isDispatched => status == 'dispatched' || status == 'pending_dc_acceptance';
  bool get isPendingRiderAcceptance => status == 'pending_rider_acceptance';
  bool get isPendingDestinationAcceptance => status == 'pending_destination_acceptance' || status == 'in_transit';
  bool get isInTransit => status == 'in_transit';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isDiscrepancyReported => status == 'discrepancy_reported';

  int get totalQuantityRequested =>
      items.fold(0, (sum, item) => sum + item.quantity);
  int get totalQuantityReceived =>
      items.fold(0, (sum, item) => sum + item.quantityReceived);
  int get totalQuantityDamaged =>
      items.fold(0, (sum, item) => sum + item.quantityDamaged);
  int get totalQuantityMissing =>
      items.fold(0, (sum, item) => sum + item.quantityMissing);

  factory StockTransferRecord.fromJson(Map<String, dynamic> json) {
    List<StockTransferItemRecord> parsedItems = [];
    if (json['stock_transfer_items'] != null &&
        json['stock_transfer_items'] is List) {
      parsedItems = (json['stock_transfer_items'] as List)
          .map((item) => StockTransferItemRecord.fromJson(
              item is Map<String, dynamic> ? item : <String, dynamic>{}))
          .toList();
    } else if (json['items'] != null && json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((item) => StockTransferItemRecord.fromJson(
              item is Map<String, dynamic> ? item : <String, dynamic>{}))
          .toList();
    }

    final sourceWh = json['source_warehouse'] as Map<String, dynamic>?;
    final destWh = json['destination_warehouse'] as Map<String, dynamic>?;
    final clientMap = json['client'] as Map<String, dynamic>?;

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback;
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return StockTransferRecord(
      id: (json['id'] ?? '').toString(),
      transferNumber: (json['transfer_number'] ?? json['transferNumber'] ?? '').toString(),
      transferType: (json['transfer_type'] ?? 'client_supply').toString(),
      status: (json['status'] ?? 'draft').toString(),
      clientId: json['client_id']?.toString(),
      clientName: clientMap != null
          ? (clientMap['business_name'] ?? clientMap['name']?.toString())
          : (json['client_name']?.toString()),
      sourceWarehouseId: json['source_warehouse_id']?.toString(),
      sourceWarehouseName: sourceWh != null
          ? sourceWh['name']?.toString()
          : json['source_warehouse_name']?.toString(),
      destinationWarehouseId: json['destination_warehouse_id']?.toString(),
      destinationWarehouseName: destWh != null
          ? destWh['name']?.toString()
          : json['destination_warehouse_name']?.toString(),
      sourceDcId: json['source_dc_id']?.toString(),
      destinationDcId: json['destination_dc_id']?.toString(),
      senderId: json['sender_id']?.toString(),
      senderName: json['sender_name']?.toString(),
      senderRole: json['sender_role']?.toString(),
      senderSignatureUrl: json['sender_signature_url']?.toString(),
      dispatchedAt: parseNullableDate(json['dispatched_at']),
      receiverId: json['receiver_id']?.toString(),
      receiverName: json['receiver_name']?.toString(),
      receiverRole: json['receiver_role']?.toString(),
      receiverSignatureUrl: json['receiver_signature_url']?.toString(),
      receivedAt: parseNullableDate(json['received_at']),
      hasDiscrepancy: (json['has_discrepancy'] as bool?) ?? false,
      discrepancyNotes: json['discrepancy_notes']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at'], DateTime.now()),
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transfer_number': transferNumber,
        'transfer_type': transferType,
        'status': status,
        'client_id': clientId,
        'client_name': clientName,
        'source_warehouse_id': sourceWarehouseId,
        'source_warehouse_name': sourceWarehouseName,
        'destination_warehouse_id': destinationWarehouseId,
        'destination_warehouse_name': destinationWarehouseName,
        'source_dc_id': sourceDcId,
        'destination_dc_id': destinationDcId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'sender_signature_url': senderSignatureUrl,
        'dispatched_at': dispatchedAt?.toIso8601String(),
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'receiver_role': receiverRole,
        'receiver_signature_url': receiverSignatureUrl,
        'received_at': receivedAt?.toIso8601String(),
        'has_discrepancy': hasDiscrepancy,
        'discrepancy_notes': discrepancyNotes,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  StockTransferRecord copyWith({
    String? id,
    String? transferNumber,
    String? transferType,
    String? status,
    String? clientId,
    String? clientName,
    String? sourceWarehouseId,
    String? sourceWarehouseName,
    String? destinationWarehouseId,
    String? destinationWarehouseName,
    String? sourceDcId,
    String? destinationDcId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderSignatureUrl,
    DateTime? dispatchedAt,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    String? receiverSignatureUrl,
    DateTime? receivedAt,
    bool? hasDiscrepancy,
    String? discrepancyNotes,
    String? notes,
    DateTime? createdAt,
    List<StockTransferItemRecord>? items,
  }) {
    return StockTransferRecord(
      id: id ?? this.id,
      transferNumber: transferNumber ?? this.transferNumber,
      transferType: transferType ?? this.transferType,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
      sourceWarehouseName: sourceWarehouseName ?? this.sourceWarehouseName,
      destinationWarehouseId: destinationWarehouseId ?? this.destinationWarehouseId,
      destinationWarehouseName:
          destinationWarehouseName ?? this.destinationWarehouseName,
      sourceDcId: sourceDcId ?? this.sourceDcId,
      destinationDcId: destinationDcId ?? this.destinationDcId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderSignatureUrl: senderSignatureUrl ?? this.senderSignatureUrl,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverRole: receiverRole ?? this.receiverRole,
      receiverSignatureUrl: receiverSignatureUrl ?? this.receiverSignatureUrl,
      receivedAt: receivedAt ?? this.receivedAt,
      hasDiscrepancy: hasDiscrepancy ?? this.hasDiscrepancy,
      discrepancyNotes: discrepancyNotes ?? this.discrepancyNotes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
