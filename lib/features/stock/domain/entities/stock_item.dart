class StockItemEntity {
  final String id;
  final String sku;
  final String name;
  final String description;
  final double price;
  final int quantityHeld;
  final int availableCount;
  final int allocatedCount;
  final String category;

  const StockItemEntity({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.price,
    required this.quantityHeld,
    required this.availableCount,
    required this.allocatedCount,
    required this.category,
  });
}
