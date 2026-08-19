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
  final int lowStockThreshold;
  final int reorderLevel;
  final String category;
  final String? imageAsset;
  final String? batchNumber;
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
    this.lowStockThreshold = 3,
    this.reorderLevel = 5,
    required this.category,
    this.imageAsset,
    this.batchNumber,
    this.lastAuditDate,
  });

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

  String get inventoryTypeLabel {
    switch (inventoryType) {
      case InventoryType.distributedInventory:
        return 'Distributed Inventory';
      case InventoryType.novaExpressInventory:
        return 'NovaExpress Inventory';
    }
  }
}
