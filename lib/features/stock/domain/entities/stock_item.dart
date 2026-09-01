enum StockStatus {
  available,
  lowStock,
  outOfStock,
}

enum InventoryType {
  distributedInventory,
  novaExpressInventory,
}

class StockItemEntity {
  final String id;
  final String sku;
  final String name;
  final String description;
  final double price;
  final String ownerName;
  final InventoryType inventoryType;
  final int totalInCustody;
  final int reservedCount;
  final int assignedCount;
  final int deliveredCount;
  final int availableCount;
  final int returnedCount;
  final int awaitingReturnCount;
  final int complaintCount;
  final int lowStockThreshold;
  final int reorderLevel;
  final String category;
  final String? imageAsset;
  final String? batchNumber;
  final String? binLocation;
  final String? lastAuditDate;

  const StockItemEntity({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.price,
    this.ownerName = 'Novacare Limited',
    this.inventoryType = InventoryType.distributedInventory,
    this.totalInCustody = 0,
    this.reservedCount = 0,
    required this.assignedCount,
    required this.deliveredCount,
    required this.availableCount,
    required this.returnedCount,
    this.awaitingReturnCount = 0,
    this.complaintCount = 0,
    this.lowStockThreshold = 3,
    this.reorderLevel = 5,
    required this.category,
    this.imageAsset,
    this.batchNumber,
    this.binLocation = 'BIN-A1-01',
    this.lastAuditDate,
  });

  static const StockItemEntity empty = StockItemEntity(
    id: '',
    sku: '',
    name: '',
    description: '',
    price: 0,
    assignedCount: 0,
    deliveredCount: 0,
    availableCount: 0,
    returnedCount: 0,
    category: '',
  );

  int get quantityHeld => availableCount;
  int get allocatedCount => reservedCount > 0 
      ? reservedCount 
      : ((assignedCount - deliveredCount - availableCount - returnedCount) > 0 
          ? (assignedCount - deliveredCount - availableCount - returnedCount) 
          : 0);

  int get totalStockQuantity => totalInCustody > 0 
      ? totalInCustody 
      : (availableCount + reservedCount + awaitingReturnCount);

  double get stockPercentage {
    final base = assignedCount > 0 ? assignedCount : totalStockQuantity;
    if (base <= 0) return 0.0;
    final ratio = availableCount / base;
    return (ratio > 1.0) ? 1.0 : (ratio < 0.0 ? 0.0 : ratio);
  }

  int get stockPercentageInt => (stockPercentage * 100).round();

  StockStatus get status {
    if (availableCount <= 0) {
      return StockStatus.outOfStock;
    } else if (availableCount <= lowStockThreshold) {
      return StockStatus.lowStock;
    } else {
      return StockStatus.available;
    }
  }

  String get statusBadgeText {
    switch (status) {
      case StockStatus.available:
        return 'AVAILABLE';
      case StockStatus.lowStock:
        return 'LOW STOCK';
      case StockStatus.outOfStock:
        return 'OUT OF STOCK';
    }
  }

  bool get isLowStock => status == StockStatus.lowStock;
  bool get isOutOfStock => status == StockStatus.outOfStock;
  int get inRiderCustodyCount => (assignedCount - deliveredCount - returnedCount).clamp(0, 999999);
  int get warehouseAvailableCount => availableCount;

  String get inventoryTypeLabel {
    switch (inventoryType) {
      case InventoryType.distributedInventory:
        return 'Distributed Inventory';
      case InventoryType.novaExpressInventory:
        return 'NovaExpress Inventory';
    }
  }

  String get cleanDescription {
    if (description.isEmpty) {
      return '$name commercial inventory unit managed and tracked under NovaXpress distribution network.';
    }
    var desc = description;

    // Remove [IMAGE_URL: ...] tag
    if (desc.contains('[IMAGE_URL:')) {
      desc = desc.replaceAll(RegExp(r'\[IMAGE_URL:\s*[^\]]+\]'), '').trim();
    }

    // Remove [PACKAGES: ...] tag (including nested JSON brackets)
    if (desc.contains('[PACKAGES:')) {
      final start = desc.indexOf('[PACKAGES:');
      final end = desc.lastIndexOf(']');
      if (end > start) {
        desc = (desc.substring(0, start) + desc.substring(end + 1)).trim();
      } else {
        desc = desc.substring(0, start).trim();
      }
    }

    // Remove trailing metadata like '- Distributed Inventory'
    desc = desc.replaceAll(RegExp(r'-\s*Distributed Inventory', caseSensitive: false), '').trim();

    // Clean up punctuation or whitespace
    desc = desc.replaceAll(RegExp(r'[\s\-_]+$'), '').trim();

    if (desc.isEmpty || desc.toLowerCase() == name.toLowerCase()) {
      return '$name commercial inventory unit managed and tracked under NovaXpress distribution network.';
    }
    return desc;
  }

  StockItemEntity copyWith({
    String? id,
    String? sku,
    String? name,
    String? description,
    double? price,
    String? ownerName,
    InventoryType? inventoryType,
    int? totalInCustody,
    int? reservedCount,
    int? assignedCount,
    int? deliveredCount,
    int? availableCount,
    int? returnedCount,
    int? awaitingReturnCount,
    int? complaintCount,
    int? lowStockThreshold,
    int? reorderLevel,
    String? category,
    String? imageAsset,
    String? batchNumber,
    String? binLocation,
    String? lastAuditDate,
  }) {
    return StockItemEntity(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      ownerName: ownerName ?? this.ownerName,
      inventoryType: inventoryType ?? this.inventoryType,
      totalInCustody: totalInCustody ?? this.totalInCustody,
      reservedCount: reservedCount ?? this.reservedCount,
      assignedCount: assignedCount ?? this.assignedCount,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      availableCount: availableCount ?? this.availableCount,
      returnedCount: returnedCount ?? this.returnedCount,
      awaitingReturnCount: awaitingReturnCount ?? this.awaitingReturnCount,
      complaintCount: complaintCount ?? this.complaintCount,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      category: category ?? this.category,
      imageAsset: imageAsset ?? this.imageAsset,
      batchNumber: batchNumber ?? this.batchNumber,
      binLocation: binLocation ?? this.binLocation,
      lastAuditDate: lastAuditDate ?? this.lastAuditDate,
    );
  }
}
