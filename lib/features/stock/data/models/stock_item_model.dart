import '../../domain/entities/stock_item.dart';

class StockItemModel extends StockItemEntity {
  const StockItemModel({
    required super.id,
    required super.sku,
    required super.name,
    required super.description,
    required super.price,
    required super.quantityHeld,
    required super.availableCount,
    required super.allocatedCount,
    required super.category,
  });

  factory StockItemModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'] ?? json['base_price'] ?? 0.0;
    final double price = rawPrice is num ? rawPrice.toDouble() : 0.0;

    final rawHeld = json['quantity_held'] ?? json['stock_quantity'] ?? 20;
    final int quantityHeld = rawHeld is num ? rawHeld.toInt() : 20;

    final rawAllocated = json['allocated_count'] ?? 12;
    final int allocatedCount = rawAllocated is num ? rawAllocated.toInt() : 12;

    final rawAvailable = json['available_count'] ?? (quantityHeld - allocatedCount);
    final int availableCount = rawAvailable is num ? rawAvailable.toInt() : (quantityHeld - allocatedCount);

    return StockItemModel(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? 'SKU-001',
      name: json['name']?.toString() ?? 'Herbal Product',
      description: json['description']?.toString() ?? '',
      price: price,
      quantityHeld: quantityHeld,
      availableCount: availableCount < 0 ? 0 : availableCount,
      allocatedCount: allocatedCount,
      category: json['category']?.toString() ?? 'Wellness',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'description': description,
      'price': price,
      'quantity_held': quantityHeld,
      'available_count': availableCount,
      'allocated_count': allocatedCount,
      'category': category,
    };
  }
}
