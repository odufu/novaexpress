import 'package:flutter/foundation.dart';

enum ExpenditureCategory {
  advertisement,
  procurement,
  logistics,
  salaries,
  rentUtilities,
  packaging,
  riderAllowance,
  dieselFuel,
  equipmentMaintenance,
  other;

  String get label {
    switch (this) {
      case ExpenditureCategory.advertisement:
        return 'Advertisement & Marketing';
      case ExpenditureCategory.procurement:
        return 'Product Procurement';
      case ExpenditureCategory.logistics:
        return 'Logistics & Haulage';
      case ExpenditureCategory.salaries:
        return 'Salaries & Commissions';
      case ExpenditureCategory.rentUtilities:
        return 'Rent & Utilities';
      case ExpenditureCategory.packaging:
        return 'Packaging & Pouches';
      case ExpenditureCategory.riderAllowance:
        return 'Rider Allowances & Fuel';
      case ExpenditureCategory.dieselFuel:
        return 'Diesel & Generator Fuel';
      case ExpenditureCategory.equipmentMaintenance:
        return 'Equipment Maintenance';
      case ExpenditureCategory.other:
        return 'Other General OpEx';
    }
  }

  static ExpenditureCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'advertisement':
        return ExpenditureCategory.advertisement;
      case 'procurement':
        return ExpenditureCategory.procurement;
      case 'logistics':
        return ExpenditureCategory.logistics;
      case 'salaries':
        return ExpenditureCategory.salaries;
      case 'rent_utilities':
        return ExpenditureCategory.rentUtilities;
      case 'packaging':
        return ExpenditureCategory.packaging;
      case 'rider_allowance':
        return ExpenditureCategory.riderAllowance;
      case 'diesel_fuel':
        return ExpenditureCategory.dieselFuel;
      case 'equipment_maintenance':
        return ExpenditureCategory.equipmentMaintenance;
      default:
        return ExpenditureCategory.other;
    }
  }

  String toDbValue() {
    switch (this) {
      case ExpenditureCategory.advertisement:
        return 'advertisement';
      case ExpenditureCategory.procurement:
        return 'procurement';
      case ExpenditureCategory.logistics:
        return 'logistics';
      case ExpenditureCategory.salaries:
        return 'salaries';
      case ExpenditureCategory.rentUtilities:
        return 'rent_utilities';
      case ExpenditureCategory.packaging:
        return 'packaging';
      case ExpenditureCategory.riderAllowance:
        return 'rider_allowance';
      case ExpenditureCategory.dieselFuel:
        return 'diesel_fuel';
      case ExpenditureCategory.equipmentMaintenance:
        return 'equipment_maintenance';
      case ExpenditureCategory.other:
        return 'other';
    }
  }
}

@immutable
class BusinessExpenditureEntity {
  final String id;
  final String entityType; // 'merchant', 'grand_dc', 'sub_dc'
  final String? clientId;
  final String? distributionCenterId;
  final String? productId;
  final String title;
  final String? description;
  final ExpenditureCategory category;
  final double amount;
  final DateTime expenditureDate;
  final String? receiptUrl;
  final String? receiptFileName;
  final String? receiptMimeType;
  final String? createdBy;
  final DateTime createdAt;

  const BusinessExpenditureEntity({
    required this.id,
    required this.entityType,
    this.clientId,
    this.distributionCenterId,
    this.productId,
    required this.title,
    this.description,
    required this.category,
    required this.amount,
    required this.expenditureDate,
    this.receiptUrl,
    this.receiptFileName,
    this.receiptMimeType,
    this.createdBy,
    required this.createdAt,
  });

  bool get hasReceipt => receiptUrl != null && receiptUrl!.trim().isNotEmpty;
  bool get isPdfReceipt => receiptMimeType?.toLowerCase().contains('pdf') ?? false;

  factory BusinessExpenditureEntity.fromMap(Map<String, dynamic> map) {
    return BusinessExpenditureEntity(
      id: map['id']?.toString() ?? '',
      entityType: map['entity_type']?.toString() ?? 'merchant',
      clientId: map['client_id']?.toString(),
      distributionCenterId: map['distribution_center_id']?.toString(),
      productId: map['product_id']?.toString(),
      title: map['title']?.toString() ?? 'Untitled Expense',
      description: map['description']?.toString(),
      category: ExpenditureCategory.fromString(map['category']?.toString() ?? 'other'),
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      expenditureDate: map['expenditure_date'] != null
          ? DateTime.tryParse(map['expenditure_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      receiptUrl: map['receipt_url']?.toString(),
      receiptFileName: map['receipt_file_name']?.toString(),
      receiptMimeType: map['receipt_mime_type']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType,
      if (clientId != null) 'client_id': clientId,
      if (distributionCenterId != null) 'distribution_center_id': distributionCenterId,
      if (productId != null) 'product_id': productId,
      'title': title,
      if (description != null) 'description': description,
      'category': category.toDbValue(),
      'amount': amount,
      'expenditure_date': expenditureDate.toIso8601String().split('T').first,
      if (receiptUrl != null) 'receipt_url': receiptUrl,
      if (receiptFileName != null) 'receipt_file_name': receiptFileName,
      if (receiptMimeType != null) 'receipt_mime_type': receiptMimeType,
    };
  }
}
