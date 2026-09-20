import 'client_supplier.dart';
import '../../../../features/dc_console/domain/entities/product_package.dart';

/// Aggregated supplier model with linked products and network inventory health
class ClientSupplierExpanded {
  final ClientSupplier supplier;
  final List<CatalogProduct> linkedProducts;
  final int totalUnitsRemaining;
  final int lowStockProductsCount;
  final bool hasCriticalLowStock;
  final String stockHealthStatus; // 'CRITICAL REORDER' | 'LOW STOCK' | 'HEALTHY' | 'OUT OF STOCK'

  const ClientSupplierExpanded({
    required this.supplier,
    required this.linkedProducts,
    required this.totalUnitsRemaining,
    required this.lowStockProductsCount,
    required this.hasCriticalLowStock,
    required this.stockHealthStatus,
  });

  /// Factory helper that computes the inventory health given the supplier, all products, and stock balances
  factory ClientSupplierExpanded.fromData({
    required ClientSupplier supplier,
    required List<CatalogProduct> allProducts,
  }) {
    // Match products either by preferredSupplierId or by name/sku in supplier.suppliedProducts
    final linked = allProducts.where((p) {
      if (p.preferredSupplierId != null && p.preferredSupplierId == supplier.id) {
        return true;
      }
      return supplier.suppliedProducts.any((sp) =>
          sp.trim().toLowerCase() == p.name.trim().toLowerCase() ||
          sp.trim().toLowerCase() == p.sku.trim().toLowerCase());
    }).toList();

    int totalUnits = 0;
    int lowStockCount = 0;
    bool hasCritical = false;

    for (final p in linked) {
      final stock = p.stockQuantity;
      totalUnits += stock;
      final threshold = p.lowStockThreshold;
      if (stock <= 0) {
        hasCritical = true;
        lowStockCount++;
      } else if (stock <= threshold) {
        lowStockCount++;
      }
    }

    String healthStatus;
    if (linked.isEmpty) {
      healthStatus = 'NO PRODUCTS';
    } else if (hasCritical || (totalUnits == 0 && linked.isNotEmpty)) {
      healthStatus = 'CRITICAL REORDER';
    } else if (lowStockCount > 0) {
      healthStatus = 'LOW STOCK';
    } else {
      healthStatus = 'HEALTHY';
    }

    return ClientSupplierExpanded(
      supplier: supplier,
      linkedProducts: linked,
      totalUnitsRemaining: totalUnits,
      lowStockProductsCount: lowStockCount,
      hasCriticalLowStock: hasCritical,
      stockHealthStatus: healthStatus,
    );
  }
}
