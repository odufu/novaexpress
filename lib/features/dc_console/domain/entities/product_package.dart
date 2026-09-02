/// Product Package Entity
/// Represents a commercial package or deal created by a seller for a specific product
/// e.g. "1 Pack" for ₦22,000 or "5 Packs Mega Deal" for ₦55,000
class ProductPackage {
  final String id;
  final String productId;
  final String productName;
  final String? productSku;
  final String packageName;
  final int quantity; // Total physical units to deduct from stock
  final int paidQuantity;
  final int freeQuantity;
  final double packagePrice; // Total package selling price
  final String clientName;
  final String? description;
  final bool isCustom;
  final DateTime createdAt;

  const ProductPackage({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSku,
    required this.packageName,
    required this.quantity,
    this.paidQuantity = 1,
    this.freeQuantity = 0,
    required this.packagePrice,
    required this.clientName,
    this.description,
    this.isCustom = false,
    required this.createdAt,
  });

  /// Effective unit price paid per item in this package
  double get unitPrice => quantity > 0 ? packagePrice / quantity : packagePrice;

  /// Physical warehouse units to deduct when this package is ordered
  int get totalPhysicalQuantity => quantity > 0 ? quantity : (paidQuantity + freeQuantity);

  /// Savings amount in Naira compared to purchasing [baseUnitPrice] individually
  double savingsAmount(double baseUnitPrice) {
    final regularTotal = totalPhysicalQuantity * baseUnitPrice;
    final diff = regularTotal - packagePrice;
    return diff > 0 ? diff : 0.0;
  }

  /// Savings percentage compared to standard single retail price
  double savingsPercent(double baseUnitPrice) {
    if (baseUnitPrice <= 0 || totalPhysicalQuantity <= 0) return 0.0;
    final regularTotal = totalPhysicalQuantity * baseUnitPrice;
    if (regularTotal <= packagePrice) return 0.0;
    final pct = ((regularTotal - packagePrice) / regularTotal) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  ProductPackage copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productSku,
    String? packageName,
    int? quantity,
    int? paidQuantity,
    int? freeQuantity,
    double? packagePrice,
    String? clientName,
    String? description,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return ProductPackage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      packageName: packageName ?? this.packageName,
      quantity: quantity ?? this.quantity,
      paidQuantity: paidQuantity ?? this.paidQuantity,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      packagePrice: packagePrice ?? this.packagePrice,
      clientName: clientName ?? this.clientName,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'package_name': packageName,
      'quantity': quantity,
      'paid_quantity': paidQuantity,
      'free_quantity': freeQuantity,
      'package_price': packagePrice,
      'client_name': clientName,
      'description': description,
      'is_custom': isCustom,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductPackage.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final paidQty = (json['paid_quantity'] as num?)?.toInt() ?? qty;
    final freeQty = (json['free_quantity'] as num?)?.toInt() ?? 0;

    return ProductPackage(
      id: json['id'] as String? ?? 'pkg-${DateTime.now().millisecondsSinceEpoch}',
      productId: json['product_id'] as String? ?? 'prod-custom',
      productName: json['product_name'] as String? ?? 'General Product',
      productSku: json['product_sku'] as String?,
      packageName: json['package_name'] as String? ?? 'Standard Pack',
      quantity: qty,
      paidQuantity: paidQty,
      freeQuantity: freeQty,
      packagePrice: (json['package_price'] as num?)?.toDouble() ?? 0.0,
      clientName: json['client_name'] as String? ?? 'Novacare Limited',
      description: json['description'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Base Product Catalog Item
class CatalogProduct {
  final String id;
  final String name;
  final String sku;
  final String clientName;
  final double defaultUnitPrice;
  final String category;
  final String? imageUrl;
  final int totalStockAcrossHubs;
  final List<ProductPackage> packages;

  const CatalogProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.clientName,
    required this.defaultUnitPrice,
    this.category = 'Health & Wellness',
    this.imageUrl,
    this.totalStockAcrossHubs = 100,
    this.packages = const [],
  });

  CatalogProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? clientName,
    double? defaultUnitPrice,
    String? category,
    String? imageUrl,
    int? totalStockAcrossHubs,
    List<ProductPackage>? packages,
  }) {
    return CatalogProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      clientName: clientName ?? this.clientName,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      totalStockAcrossHubs: totalStockAcrossHubs ?? this.totalStockAcrossHubs,
      packages: packages ?? this.packages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'client_name': clientName,
      'default_unit_price': defaultUnitPrice,
      'category': category,
      'image_url': imageUrl,
      'total_stock': totalStockAcrossHubs,
      'packages': packages.map((p) => p.toJson()).toList(),
    };
  }

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      id: json['id'] as String? ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Product',
      sku: json['sku'] as String? ?? 'SKU-001',
      clientName: json['client_name'] as String? ?? 'Novacare Limited',
      defaultUnitPrice: (json['default_unit_price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Health & Wellness',
      imageUrl: json['image_url'] as String?,
      totalStockAcrossHubs: (json['total_stock'] as num?)?.toInt() ?? 100,
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) => ProductPackage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
