import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_package.dart';

class ProductCatalogState {
  final List<CatalogProduct> products;
  final bool isLoading;

  const ProductCatalogState({
    required this.products,
    this.isLoading = false,
  });

  ProductCatalogState copyWith({
    List<CatalogProduct>? products,
    bool? isLoading,
  }) {
    return ProductCatalogState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  CatalogProduct? findProductByName(String name) {
    final clean = name.trim().toLowerCase();
    for (final p in products) {
      if (p.name.toLowerCase() == clean ||
          p.name.toLowerCase().contains(clean) ||
          clean.contains(p.name.toLowerCase())) {
        return p;
      }
    }
    return null;
  }

  List<ProductPackage> getPackagesForProduct(String productName) {
    final prod = findProductByName(productName);
    if (prod != null && prod.packages.isNotEmpty) {
      return prod.packages;
    }
    // Default fallback single package
    return [
      ProductPackage(
        id: 'pkg-default-1',
        productId: prod?.id ?? 'prod-custom',
        productName: productName,
        packageName: '1 Unit (Single)',
        quantity: 1,
        packagePrice: prod?.defaultUnitPrice ?? 25000.0,
        clientName: prod?.clientName ?? 'Novacare Limited',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class ProductCatalogNotifier extends StateNotifier<ProductCatalogState> {
  ProductCatalogNotifier() : super(ProductCatalogState(products: _initialProducts));

  static final List<CatalogProduct> _initialProducts = [
    CatalogProduct(
      id: 'prod-grazer',
      name: 'Grazer Tea',
      sku: 'SKU-GRZ-001',
      clientName: 'Novacare Limited',
      defaultUnitPrice: 22000.0,
      packages: [
        ProductPackage(
          id: 'pkg-grz-1',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          packageName: '1 Pack (Single)',
          quantity: 1,
          packagePrice: 22000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-grz-2',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          packageName: '2 Packs Promo Deal',
          quantity: 2,
          packagePrice: 38000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-grz-3',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          packageName: '3 Packs Family Bundle',
          quantity: 3,
          packagePrice: 48000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-grz-5',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          packageName: '5 Packs Mega Deal',
          quantity: 5,
          packagePrice: 55000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-alphaman',
      name: 'Alpha Man',
      sku: 'SKU-ALPH-001',
      clientName: 'MenHealth Global',
      defaultUnitPrice: 20000.0,
      packages: [
        ProductPackage(
          id: 'pkg-alph-1',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          packageName: '1 Bottle (Standard)',
          quantity: 1,
          packagePrice: 20000.0,
          clientName: 'MenHealth Global',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-alph-2',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          packageName: '2 Bottles Treatment Kit',
          quantity: 2,
          packagePrice: 35000.0,
          clientName: 'MenHealth Global',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-alph-3',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          packageName: '3 Bottles Ultimate Pack',
          quantity: 3,
          packagePrice: 50000.0,
          clientName: 'MenHealth Global',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-alph-5',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          packageName: '5 Bottles Wholesale Special',
          quantity: 5,
          packagePrice: 75000.0,
          clientName: 'MenHealth Global',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-respira',
      name: 'Respira Detox Tea',
      sku: 'SKU-RSP-001',
      clientName: 'Novacare Limited',
      defaultUnitPrice: 25000.0,
      packages: [
        ProductPackage(
          id: 'pkg-rsp-1',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          packageName: '1 Box (Single Course)',
          quantity: 1,
          packagePrice: 25000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-rsp-2',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          packageName: '2 Boxes Promo Duo',
          quantity: 2,
          packagePrice: 45000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-rsp-4',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          packageName: '4 Boxes Full Detox Cleanse',
          quantity: 4,
          packagePrice: 80000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-multivitamins',
      name: 'PharmaPlus Daily Multivitamins',
      sku: 'SKU-PHM-001',
      clientName: 'PharmaPlus',
      defaultUnitPrice: 15000.0,
      packages: [
        ProductPackage(
          id: 'pkg-phm-1',
          productId: 'prod-multivitamins',
          productName: 'PharmaPlus Daily Multivitamins',
          packageName: '1 Bottle (30 Days)',
          quantity: 1,
          packagePrice: 15000.0,
          clientName: 'PharmaPlus',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-phm-2',
          productId: 'prod-multivitamins',
          productName: 'PharmaPlus Daily Multivitamins',
          packageName: '2 Bottles Duo',
          quantity: 2,
          packagePrice: 28000.0,
          clientName: 'PharmaPlus',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-phm-3',
          productId: 'prod-multivitamins',
          productName: 'PharmaPlus Daily Multivitamins',
          packageName: '3 Bottles Immune Booster Trio',
          quantity: 3,
          packagePrice: 40000.0,
          clientName: 'PharmaPlus',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-jointcare',
      name: 'Novacare Joint Care Pack',
      sku: 'SKU-JNT-001',
      clientName: 'Novacare Limited',
      defaultUnitPrice: 35000.0,
      packages: [
        ProductPackage(
          id: 'pkg-jnt-1',
          productId: 'prod-jointcare',
          productName: 'Novacare Joint Care Pack',
          packageName: '1 Pack (Standard)',
          quantity: 1,
          packagePrice: 35000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-jnt-2',
          productId: 'prod-jointcare',
          productName: 'Novacare Joint Care Pack',
          packageName: '2 Packs Double Care Kit',
          quantity: 2,
          packagePrice: 65000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime.now(),
        ),
      ],
    ),
  ];

  /// Creates and registers a new package for a product (or creates the product if new).
  /// This newly registered package is immediately persistent and reusable across all future orders!
  ProductPackage addPackageToProduct({
    required String productName,
    required String packageName,
    required int quantity,
    required double packagePrice,
    String? clientName,
  }) {
    final cleanProd = productName.trim();
    final cleanPkg = packageName.trim();
    final cleanClient = clientName?.trim().isNotEmpty == true ? clientName!.trim() : 'Novacare Limited';

    final existingProduct = state.findProductByName(cleanProd);
    final packageId = 'pkg-${DateTime.now().millisecondsSinceEpoch}';

    final newPackage = ProductPackage(
      id: packageId,
      productId: existingProduct?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      productName: existingProduct?.name ?? cleanProd,
      packageName: cleanPkg,
      quantity: quantity > 0 ? quantity : 1,
      packagePrice: packagePrice,
      clientName: existingProduct?.clientName ?? cleanClient,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    if (existingProduct != null) {
      // Add package to existing product's package list
      final updatedPackages = List<ProductPackage>.from(existingProduct.packages)..add(newPackage);
      final updatedProduct = existingProduct.copyWith(packages: updatedPackages);

      final updatedProductList = state.products.map((p) {
        return p.id == existingProduct.id ? updatedProduct : p;
      }).toList();

      state = state.copyWith(products: updatedProductList);
    } else {
      // Create new product with this new package
      final newProduct = CatalogProduct(
        id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
        name: cleanProd,
        sku: 'SKU-${cleanProd.substring(0, cleanProd.length.clamp(0, 3)).toUpperCase()}-${DateTime.now().millisecond}',
        clientName: cleanClient,
        defaultUnitPrice: quantity > 0 ? packagePrice / quantity : packagePrice,
        packages: [newPackage],
      );

      state = state.copyWith(products: [...state.products, newProduct]);
    }

    return newPackage;
  }
}

final productCatalogProvider =
    StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  return ProductCatalogNotifier();
});
