import 'package:flutter/foundation.dart';

/// Standard QC Defect classifications for Distribution Center physical inspection
class DefectCategory {
  static const String brokenSeal = 'Broken Tamper / Induction Seal';
  static const String colorDilation = 'Color Dilation / Pigment Alteration';
  static const String textureCoarseness = 'Texture / Grind Coarseness';
  static const String puncturedPackaging = 'Punctured Packaging / Leakage';
  static const String expiredLot = 'Expired / Near-Expiry Lot';
  static const String transitCrushed = 'Transit Crushed / Physical Dent';

  static const List<String> all = [
    brokenSeal,
    colorDilation,
    textureCoarseness,
    puncturedPackaging,
    expiredLot,
    transitCrushed,
  ];
}

/// Inbound Consignment shipment dispatched from Merchant to NovaXpress DC
@immutable
class MerchantInboundShipment {
  final String id;
  final String waybillNumber;
  final String merchantId;
  final String merchantName;
  final String productId;
  final String productName;
  final String sku;
  final String targetDcId;
  final String targetDcName;
  final int expectedQuantity;
  final int acceptedQuantity;
  final int spoiltQuantity;
  final Map<String, int> defectBreakdown;
  final String status; // 'in_transit', 'received_clean', 'received_with_defects', 'rejected'
  final String carrierDriverName;
  final String carrierPhone;
  final String carrierPlate;
  final String? stagingBay;
  final String? notes;
  final DateTime dispatchedAt;
  final DateTime? receivedAt;
  final String? dcInspectorName;

  const MerchantInboundShipment({
    required this.id,
    required this.waybillNumber,
    required this.merchantId,
    required this.merchantName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.targetDcId,
    required this.targetDcName,
    required this.expectedQuantity,
    this.acceptedQuantity = 0,
    this.spoiltQuantity = 0,
    this.defectBreakdown = const {},
    this.status = 'in_transit',
    this.carrierDriverName = '',
    this.carrierPhone = '',
    this.carrierPlate = '',
    this.stagingBay,
    this.notes,
    required this.dispatchedAt,
    this.receivedAt,
    this.dcInspectorName,
  });

  bool get isInTransit => status == 'in_transit' || status == 'dispatched';
  bool get isReceivedClean => status == 'received_clean' || (status == 'completed' && spoiltQuantity == 0);
  bool get isReceivedWithDefects => status == 'received_with_defects' || (status == 'completed' && spoiltQuantity > 0);
  bool get isCompleted => isReceivedClean || isReceivedWithDefects || status == 'completed';

  int get totalDefectsRecorded => defectBreakdown.values.fold(0, (sum, q) => sum + q);

  MerchantInboundShipment copyWith({
    String? id,
    String? waybillNumber,
    String? merchantId,
    String? merchantName,
    String? productId,
    String? productName,
    String? sku,
    String? targetDcId,
    String? targetDcName,
    int? expectedQuantity,
    int? acceptedQuantity,
    int? spoiltQuantity,
    Map<String, int>? defectBreakdown,
    String? status,
    String? carrierDriverName,
    String? carrierPhone,
    String? carrierPlate,
    String? stagingBay,
    String? notes,
    DateTime? dispatchedAt,
    DateTime? receivedAt,
    String? dcInspectorName,
  }) {
    return MerchantInboundShipment(
      id: id ?? this.id,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      targetDcId: targetDcId ?? this.targetDcId,
      targetDcName: targetDcName ?? this.targetDcName,
      expectedQuantity: expectedQuantity ?? this.expectedQuantity,
      acceptedQuantity: acceptedQuantity ?? this.acceptedQuantity,
      spoiltQuantity: spoiltQuantity ?? this.spoiltQuantity,
      defectBreakdown: defectBreakdown ?? this.defectBreakdown,
      status: status ?? this.status,
      carrierDriverName: carrierDriverName ?? this.carrierDriverName,
      carrierPhone: carrierPhone ?? this.carrierPhone,
      carrierPlate: carrierPlate ?? this.carrierPlate,
      stagingBay: stagingBay ?? this.stagingBay,
      notes: notes ?? this.notes,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      dcInspectorName: dcInspectorName ?? this.dcInspectorName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'waybillNumber': waybillNumber,
        'merchantId': merchantId,
        'merchantName': merchantName,
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'targetDcId': targetDcId,
        'targetDcName': targetDcName,
        'expectedQuantity': expectedQuantity,
        'acceptedQuantity': acceptedQuantity,
        'spoiltQuantity': spoiltQuantity,
        'defectBreakdown': defectBreakdown,
        'status': status,
        'carrierDriverName': carrierDriverName,
        'carrierPhone': carrierPhone,
        'carrierPlate': carrierPlate,
        'stagingBay': stagingBay,
        'notes': notes,
        'dispatchedAt': dispatchedAt.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'dcInspectorName': dcInspectorName,
      };

  factory MerchantInboundShipment.fromJson(Map<String, dynamic> json) {
    Map<String, int> defects = {};
    if (json['defectBreakdown'] is Map) {
      (json['defectBreakdown'] as Map).forEach((k, v) {
        defects[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return MerchantInboundShipment(
      id: json['id']?.toString() ?? '',
      waybillNumber: json['waybillNumber']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      merchantName: json['merchantName']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      targetDcId: json['targetDcId']?.toString() ?? '',
      targetDcName: json['targetDcName']?.toString() ?? '',
      expectedQuantity: (json['expectedQuantity'] as num?)?.toInt() ?? 0,
      acceptedQuantity: (json['acceptedQuantity'] as num?)?.toInt() ?? 0,
      spoiltQuantity: (json['spoiltQuantity'] as num?)?.toInt() ?? 0,
      defectBreakdown: defects,
      status: json['status']?.toString() ?? 'in_transit',
      carrierDriverName: json['carrierDriverName']?.toString() ?? '',
      carrierPhone: json['carrierPhone']?.toString() ?? '',
      carrierPlate: json['carrierPlate']?.toString() ?? '',
      stagingBay: json['stagingBay']?.toString(),
      notes: json['notes']?.toString(),
      dispatchedAt: DateTime.tryParse(json['dispatchedAt']?.toString() ?? '') ?? DateTime.now(),
      receivedAt: json['receivedAt'] != null ? DateTime.tryParse(json['receivedAt'].toString()) : null,
      dcInspectorName: json['dcInspectorName']?.toString(),
    );
  }
}

/// Agent Daily Sales & Stock Balancing Log Entry
@immutable
class MerchantAgentSalesRecord {
  final String id;
  final DateTime date;
  final String merchantId;
  final String agentId;
  final String agentName;
  final String agentCode;
  final String agentType; // 'NovaXpress Fleet', 'GIG Logistics', 'Speedaf', 'Fez Delivery', 'Partner'
  final String productId;
  final String productName;
  final String sku;
  final int openingCustody;
  final int replenishedUnits;
  final int unitsSold;
  final int unitsReturned;
  final int closingCustody; // opening + replenished - unitsSold - unitsReturned
  final int? physicalAuditCount; // Ambush / random physical stock count
  final double? variancePercentage; // ((physical - closing) / closing) * 100
  final bool isAuditAmbush;
  final bool discrepancyFlagged;
  final String? discrepancyNotes;
  final String? notes;
  final String loggedBy;
  final DateTime createdAt;

  const MerchantAgentSalesRecord({
    required this.id,
    required this.date,
    required this.merchantId,
    required this.agentId,
    required this.agentName,
    required this.agentCode,
    required this.agentType,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.openingCustody,
    this.replenishedUnits = 0,
    required this.unitsSold,
    this.unitsReturned = 0,
    required this.closingCustody,
    this.physicalAuditCount,
    this.variancePercentage,
    this.isAuditAmbush = false,
    this.discrepancyFlagged = false,
    this.discrepancyNotes,
    this.notes,
    required this.loggedBy,
    required this.createdAt,
  });

  /// Factory calculating the mathematical closing custody:
  /// Closing = Opening + Replenished - UnitsSold - UnitsReturned
  factory MerchantAgentSalesRecord.compute({
    required String id,
    required DateTime date,
    required String merchantId,
    required String agentId,
    required String agentName,
    required String agentCode,
    required String agentType,
    required String productId,
    required String productName,
    required String sku,
    required int openingCustody,
    int replenishedUnits = 0,
    required int unitsSold,
    int unitsReturned = 0,
    int? physicalAuditCount,
    String? notes,
    required String loggedBy,
  }) {
    final computedClosing = (openingCustody + replenishedUnits - unitsSold - unitsReturned).clamp(0, 9999999);
    
    double? varPct;
    bool flagged = false;
    String? discNotes;

    if (physicalAuditCount != null) {
      final variance = physicalAuditCount - computedClosing;
      if (computedClosing > 0) {
        varPct = (variance / computedClosing) * 100.0;
        // As stated in the meeting transcript:
        // "count if their CRM is showing 18,000 stock takers must count 18,000 or plus or minus less than 5%"
        if (varPct.abs() > 5.0) {
          flagged = true;
          discNotes = 'Audit Variance of ${varPct.toStringAsFixed(1)}% exceeds the ±5% investigation threshold ($variance units discrepancy).';
        }
      } else if (variance != 0) {
        flagged = true;
        varPct = 100.0;
        discNotes = 'Non-zero physical count against 0 calculated custody ($variance units discrepancy).';
      }
    }

    return MerchantAgentSalesRecord(
      id: id,
      date: date,
      merchantId: merchantId,
      agentId: agentId,
      agentName: agentName,
      agentCode: agentCode,
      agentType: agentType,
      productId: productId,
      productName: productName,
      sku: sku,
      openingCustody: openingCustody,
      replenishedUnits: replenishedUnits,
      unitsSold: unitsSold,
      unitsReturned: unitsReturned,
      closingCustody: computedClosing,
      physicalAuditCount: physicalAuditCount,
      variancePercentage: varPct,
      isAuditAmbush: physicalAuditCount != null,
      discrepancyFlagged: flagged,
      discrepancyNotes: discNotes,
      notes: notes,
      loggedBy: loggedBy,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'merchantId': merchantId,
        'agentId': agentId,
        'agentName': agentName,
        'agentCode': agentCode,
        'agentType': agentType,
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'openingCustody': openingCustody,
        'replenishedUnits': replenishedUnits,
        'unitsSold': unitsSold,
        'unitsReturned': unitsReturned,
        'closingCustody': closingCustody,
        'physicalAuditCount': physicalAuditCount,
        'variancePercentage': variancePercentage,
        'isAuditAmbush': isAuditAmbush,
        'discrepancyFlagged': discrepancyFlagged,
        'discrepancyNotes': discrepancyNotes,
        'notes': notes,
        'loggedBy': loggedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MerchantAgentSalesRecord.fromJson(Map<String, dynamic> json) {
    return MerchantAgentSalesRecord(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      merchantId: json['merchantId']?.toString() ?? '',
      agentId: json['agentId']?.toString() ?? '',
      agentName: json['agentName']?.toString() ?? '',
      agentCode: json['agentCode']?.toString() ?? '',
      agentType: json['agentType']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      openingCustody: (json['openingCustody'] as num?)?.toInt() ?? 0,
      replenishedUnits: (json['replenishedUnits'] as num?)?.toInt() ?? 0,
      unitsSold: (json['unitsSold'] as num?)?.toInt() ?? 0,
      unitsReturned: (json['unitsReturned'] as num?)?.toInt() ?? 0,
      closingCustody: (json['closingCustody'] as num?)?.toInt() ?? 0,
      physicalAuditCount: (json['physicalAuditCount'] as num?)?.toInt(),
      variancePercentage: (json['variancePercentage'] as num?)?.toDouble(),
      isAuditAmbush: json['isAuditAmbush'] == true,
      discrepancyFlagged: json['discrepancyFlagged'] == true,
      discrepancyNotes: json['discrepancyNotes']?.toString(),
      notes: json['notes']?.toString(),
      loggedBy: json['loggedBy']?.toString() ?? 'Stock Officer',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Agent entity from the perspective of Merchant Stock Keeper
@immutable
class MerchantPartnerAgent {
  final String id;
  final String name;
  final String code;
  final String agentType; // 'NovaXpress Fleet', 'GIG Logistics', 'Speedaf', 'Fez Delivery'
  final String phone;
  final String state;
  final List<String> assignedMerchantIds;
  final Map<String, int> productCustody; // SKU -> physical custody units

  const MerchantPartnerAgent({
    required this.id,
    required this.name,
    required this.code,
    required this.agentType,
    required this.phone,
    required this.state,
    this.assignedMerchantIds = const [],
    this.productCustody = const {},
  });

  int get totalHeldUnits => productCustody.values.fold(0, (sum, q) => sum + q);

  MerchantPartnerAgent copyWith({
    String? id,
    String? name,
    String? code,
    String? agentType,
    String? phone,
    String? state,
    List<String>? assignedMerchantIds,
    Map<String, int>? productCustody,
  }) {
    return MerchantPartnerAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      agentType: agentType ?? this.agentType,
      phone: phone ?? this.phone,
      state: state ?? this.state,
      assignedMerchantIds: assignedMerchantIds ?? this.assignedMerchantIds,
      productCustody: productCustody ?? this.productCustody,
    );
  }
}

/// Merchant SKU representation across DCs and Shelves
@immutable
class MerchantProductStockView {
  final String id;
  final String name;
  final String sku;
  final double unitPrice;
  final String category;
  final String? description;
  final String? imageUrl;
  final Map<String, int> dcShelves; // dcName -> units available
  final Map<String, int> dcDefectQuarantine; // dcName -> units spoilt
  final Map<String, int> agentCustody; // agentName -> units held

  const MerchantProductStockView({
    required this.id,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.category,
    this.description,
    this.imageUrl,
    this.dcShelves = const {},
    this.dcDefectQuarantine = const {},
    this.agentCustody = const {},
  });

  int get totalInDcShelves => dcShelves.values.fold(0, (sum, q) => sum + q);
  int get totalInAgentCustody => agentCustody.values.fold(0, (sum, q) => sum + q);
  int get totalDefectiveUnits => dcDefectQuarantine.values.fold(0, (sum, q) => sum + q);
  int get totalSystemStock => totalInDcShelves + totalInAgentCustody;
  double get totalValuation => totalSystemStock * unitPrice;

  MerchantProductStockView copyWith({
    String? id,
    String? name,
    String? sku,
    double? unitPrice,
    String? category,
    String? description,
    String? imageUrl,
    Map<String, int>? dcShelves,
    Map<String, int>? dcDefectQuarantine,
    Map<String, int>? agentCustody,
  }) {
    return MerchantProductStockView(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      dcShelves: dcShelves ?? this.dcShelves,
      dcDefectQuarantine: dcDefectQuarantine ?? this.dcDefectQuarantine,
      agentCustody: agentCustody ?? this.agentCustody,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'unitPrice': unitPrice,
        'category': category,
        'description': description,
        'imageUrl': imageUrl,
        'dcShelves': dcShelves,
        'dcDefectQuarantine': dcDefectQuarantine,
        'agentCustody': agentCustody,
      };

  factory MerchantProductStockView.fromJson(Map<String, dynamic> json) {
    Map<String, int> shelves = {};
    if (json['dcShelves'] is Map) {
      (json['dcShelves'] as Map).forEach((k, v) {
        shelves[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    Map<String, int> defects = {};
    if (json['dcDefectQuarantine'] is Map) {
      (json['dcDefectQuarantine'] as Map).forEach((k, v) {
        defects[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    Map<String, int> custody = {};
    if (json['agentCustody'] is Map) {
      (json['agentCustody'] as Map).forEach((k, v) {
        custody[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return MerchantProductStockView(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'General',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      dcShelves: shelves,
      dcDefectQuarantine: defects,
      agentCustody: custody,
    );
  }
}
