import '../../domain/entities/stock_item.dart';

class StockItemModel extends StockItemEntity {
  const StockItemModel({
    required super.id,
    required super.sku,
    required super.name,
    required super.description,
    required super.price,
    super.ownerName = 'Novacare Limited',
    super.inventoryType = InventoryType.distributedInventory,
    super.totalInCustody = 0,
    super.reservedCount = 0,
    required super.assignedCount,
    required super.deliveredCount,
    required super.availableCount,
    required super.returnedCount,
    super.awaitingReturnCount = 0,
    super.lowStockThreshold = 3,
    super.reorderLevel = 5,
    required super.category,
    super.imageAsset,
    super.batchNumber,
    super.lastAuditDate,
  });

  factory StockItemModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'] ?? json['base_price'] ?? 0.0;
    final double price = rawPrice is num ? rawPrice.toDouble() : 0.0;

    final name = json['name']?.toString() ?? 'Herbal Product';
    final sku = json['sku']?.toString() ?? 'RDT-001';
    final ownerName = json['owner_name']?.toString() ?? json['client_name']?.toString() ?? 'Novacare Limited';

    final int assigned = (json['assigned_count'] ?? json['total_assigned'] ?? json['quantity_held'] ?? 0) is num
        ? (json['assigned_count'] ?? json['total_assigned'] ?? json['quantity_held'] ?? 0).toInt()
        : 0;

    final int delivered = (json['delivered_count'] ?? json['delivered_quantity'] ?? 0) is num
        ? (json['delivered_count'] ?? json['delivered_quantity'] ?? 0).toInt()
        : 0;

    final int returned = (json['returned_count'] ?? json['returned_quantity'] ?? 0) is num
        ? (json['returned_count'] ?? json['returned_quantity'] ?? 0).toInt()
        : 0;

    final int reserved = (json['reserved_count'] ?? json['allocated_count'] ?? 0) is num
        ? (json['reserved_count'] ?? json['allocated_count'] ?? 0).toInt()
        : 0;

    final int awaitingReturn = (json['awaiting_return_count'] ?? json['awaiting_return'] ?? 0) is num
        ? (json['awaiting_return_count'] ?? json['awaiting_return'] ?? 0).toInt()
        : 0;

    final rawAvailable = json['available_count'] ?? (assigned - delivered - returned - reserved);
    final int available = rawAvailable is num ? rawAvailable.toInt() : (assigned - delivered - returned - reserved);

    final int totalInCustody = (json['total_in_custody'] ?? (available + reserved + awaitingReturn)) is num
        ? (json['total_in_custody'] ?? (available + reserved + awaitingReturn)).toInt()
        : (available + reserved + awaitingReturn);

    final int lowThreshold = (json['low_stock_threshold'] ?? 3) is num
        ? (json['low_stock_threshold'] ?? 3).toInt()
        : 3;

    final int reorderLvl = (json['reorder_level'] ?? 5) is num
        ? (json['reorder_level'] ?? 5).toInt()
        : 5;

    final rawInvType = json['inventory_type']?.toString();
    final invType = rawInvType == 'novaexpress_inventory' 
        ? InventoryType.novaExpressInventory 
        : InventoryType.distributedInventory;

    String? imageAsset = json['image_asset']?.toString();
    if (imageAsset == null || imageAsset.isEmpty) {
      final lower = name.toLowerCase();
      if (lower.contains('respira')) {
        imageAsset = 'assets/images/products/respira_detox_tea.jpg';
      } else if (lower.contains('cleanse') || lower.contains('herbal cleanse')) {
        imageAsset = 'assets/images/products/herbal_cleanse_pack.jpg';
      } else if (lower.contains('immunity') || lower.contains('booster')) {
        imageAsset = 'assets/images/products/immunity_booster_pack.jpg';
      } else if (lower.contains('slimfit') || lower.contains('capsule') || lower.contains('alpha')) {
        imageAsset = 'assets/images/products/slimfit_herbal_capsules.jpg';
      }
    }

    return StockItemModel(
      id: json['id']?.toString() ?? '',
      sku: sku,
      name: name,
      description: json['description']?.toString() ?? '',
      price: price,
      ownerName: ownerName,
      inventoryType: invType,
      totalInCustody: totalInCustody < 0 ? 0 : totalInCustody,
      reservedCount: reserved < 0 ? 0 : reserved,
      assignedCount: assigned < 0 ? 0 : assigned,
      deliveredCount: delivered < 0 ? 0 : delivered,
      availableCount: available < 0 ? 0 : available,
      returnedCount: returned < 0 ? 0 : returned,
      awaitingReturnCount: awaitingReturn < 0 ? 0 : awaitingReturn,
      lowStockThreshold: lowThreshold,
      reorderLevel: reorderLvl,
      category: json['category']?.toString() ?? 'Wellness',
      imageAsset: imageAsset,
      batchNumber: json['batch_number']?.toString() ?? 'BATCH-2026-A',
      lastAuditDate: json['last_audit_date']?.toString() ?? 'Today, 08:30 AM',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'description': description,
      'price': price,
      'owner_name': ownerName,
      'inventory_type': inventoryType == InventoryType.novaExpressInventory ? 'novaexpress_inventory' : 'distributed_inventory',
      'total_in_custody': totalInCustody,
      'reserved_count': reservedCount,
      'assigned_count': assignedCount,
      'delivered_count': deliveredCount,
      'available_count': availableCount,
      'returned_count': returnedCount,
      'awaiting_return_count': awaitingReturnCount,
      'low_stock_threshold': lowStockThreshold,
      'reorder_level': reorderLevel,
      'category': category,
      'image_asset': imageAsset,
      'batch_number': batchNumber,
      'last_audit_date': lastAuditDate,
    };
  }
}
