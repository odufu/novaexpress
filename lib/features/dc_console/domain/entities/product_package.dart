/// Product Package Entity
/// Represents a commercial package or deal created by a seller for a specific product
/// e.g. "1 Pack" for ₦22,000 or "5 Packs Special Deal" for ₦55,000
class ProductPackage {
  final String id;
  final String productId;
  final String productName;
  final String packageName;
  final int quantity;
  final double packagePrice;
  final String clientName;
  final bool isCustom;
  final DateTime createdAt;

  const ProductPackage({
    required this.id,
    required this.productId,
    required this.productName,
    required this.packageName,
    required this.quantity,
    required this.packagePrice,
    required this.clientName,
    this.isCustom = false,
    required this.createdAt,
  });

  double get unitPrice => quantity > 0 ? packagePrice / quantity : packagePrice;

  ProductPackage copyWith({
    String? id,
    String? productId,
    String? productName,
    String? packageName,
    int? quantity,
    double? packagePrice,
    String? clientName,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return ProductPackage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      packageName: packageName ?? this.packageName,
      quantity: quantity ?? this.quantity,
      packagePrice: packagePrice ?? this.packagePrice,
      clientName: clientName ?? this.clientName,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'package_name': packageName,
      'quantity': quantity,
      'package_price': packagePrice,
      'client_name': clientName,
      'is_custom': isCustom,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductPackage.fromJson(Map<String, dynamic> json) {
    return ProductPackage(
      id: json['id'] as String? ?? 'pkg-${DateTime.now().millisecondsSinceEpoch}',
      productId: json['product_id'] as String? ?? 'prod-custom',
      productName: json['product_name'] as String? ?? 'General Product',
      packageName: json['package_name'] as String? ?? 'Standard Pack',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      packagePrice: (json['package_price'] as num?)?.toDouble() ?? 0.0,
      clientName: json['client_name'] as String? ?? 'Novacare Limited',
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
  final List<ProductPackage> packages;

  const CatalogProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.clientName,
    required this.defaultUnitPrice,
    this.packages = const [],
  });

  CatalogProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? clientName,
    double? defaultUnitPrice,
    List<ProductPackage>? packages,
  }) {
    return CatalogProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      clientName: clientName ?? this.clientName,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      packages: packages ?? this.packages,
    );
  }
}
