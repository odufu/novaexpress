import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../stock/domain/entities/stock_item.dart';
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

  CatalogProduct? findProductBySku(String sku) {
    final clean = sku.trim().toLowerCase();
    for (final p in products) {
      if (p.sku.toLowerCase() == clean) {
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
        id: 'pkg-default-${productName.hashCode.abs()}',
        productId: prod?.id ?? 'prod-custom',
        productName: productName,
        packageName: '1 Unit (Single)',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        packagePrice: prod?.defaultUnitPrice ?? 25000.0,
        clientName: prod?.clientName ?? 'Novacare Limited',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class ProductCatalogNotifier extends StateNotifier<ProductCatalogState> {
  final LocalStorageService _storageService;

  ProductCatalogNotifier({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(ProductCatalogState(products: _initialProducts)) {
    _initCatalog();
  }

  Future<void> _initCatalog() async {
    try {
      final cached = await _storageService.getCachedProductCatalog();
      if (cached != null && cached.isNotEmpty) {
        // Merge cached custom packages with initial catalog
        final merged = <CatalogProduct>[];
        final cachedMap = {for (final p in cached) p.name.toLowerCase(): p};

        for (final initP in _initialProducts) {
          final cachedP = cachedMap[initP.name.toLowerCase()];
          if (cachedP != null) {
            // Merge packages avoiding duplicates
            final pkgMap = {for (final pkg in initP.packages) pkg.id: pkg};
            for (final cp in cachedP.packages) {
              pkgMap[cp.id] = cp;
            }
            merged.add(initP.copyWith(packages: pkgMap.values.toList()));
            cachedMap.remove(initP.name.toLowerCase());
          } else {
            merged.add(initP);
          }
        }
        // Add any remaining custom products created by users
        merged.addAll(cachedMap.values);
        state = state.copyWith(products: merged);
      }
    } catch (_) {}
  }

  Future<void> _persistCatalog() async {
    try {
      await _storageService.cacheProductCatalog(state.products);
    } catch (_) {}
  }

  /// Syncs newly created stock items from the stock inventory into the product catalog
  void syncFromStockItems(List<StockItemEntity> stockItems) {
    var updated = false;
    final currentList = List<CatalogProduct>.from(state.products);

    for (final item in stockItems) {
      final existing = state.findProductByName(item.name) ?? state.findProductBySku(item.sku);
      if (existing == null) {
        // Register new catalog product with a standard single package
        final newProd = CatalogProduct(
          id: item.id,
          name: item.name,
          sku: item.sku,
          clientName: item.ownerName,
          defaultUnitPrice: item.price,
          category: item.category,
          packages: [
            ProductPackage(
              id: 'pkg-${item.sku.toLowerCase()}-1',
              productId: item.id,
              productName: item.name,
              productSku: item.sku,
              packageName: '1 Unit (Standard Retail)',
              quantity: 1,
              paidQuantity: 1,
              freeQuantity: 0,
              packagePrice: item.price,
              clientName: item.ownerName,
              createdAt: DateTime.now(),
            ),
          ],
        );
        currentList.add(newProd);
        updated = true;
      }
    }

    if (updated) {
      state = state.copyWith(products: currentList);
      _persistCatalog();
    }
  }

  /// Creates and registers a new commercial package for a product (or creates the product if new).
  /// This newly registered package is immediately persistent and reusable across all future orders!
  ProductPackage addPackageToProduct({
    required String productName,
    required String packageName,
    required int quantity,
    int? paidQuantity,
    int? freeQuantity,
    required double packagePrice,
    String? clientName,
    String? productSku,
    String? description,
  }) {
    final cleanProd = productName.trim();
    final cleanPkg = packageName.trim();
    final cleanClient = clientName?.trim().isNotEmpty == true ? clientName!.trim() : 'Novacare Limited';

    final existingProduct = state.findProductByName(cleanProd) ?? (productSku != null ? state.findProductBySku(productSku) : null);
    final packageId = 'pkg-${DateTime.now().millisecondsSinceEpoch}';
    final totalUnits = quantity > 0 ? quantity : 1;
    final paidUnits = paidQuantity ?? totalUnits;
    final freeUnits = freeQuantity ?? 0;

    final newPackage = ProductPackage(
      id: packageId,
      productId: existingProduct?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      productName: existingProduct?.name ?? cleanProd,
      productSku: productSku ?? existingProduct?.sku,
      packageName: cleanPkg,
      quantity: totalUnits,
      paidQuantity: paidUnits,
      freeQuantity: freeUnits,
      packagePrice: packagePrice,
      clientName: existingProduct?.clientName ?? cleanClient,
      description: description,
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
        sku: productSku ?? 'SKU-${cleanProd.replaceAll(" ", "").substring(0, cleanProd.replaceAll(" ", "").length.clamp(0, 4)).toUpperCase()}-${DateTime.now().millisecond}',
        clientName: cleanClient,
        defaultUnitPrice: totalUnits > 0 ? packagePrice / totalUnits : packagePrice,
        packages: [newPackage],
      );

      state = state.copyWith(products: [...state.products, newProduct]);
    }

    _persistCatalog();
    return newPackage;
  }

  /// Removes a package from a product
  bool deletePackage({required String productName, required String packageId}) {
    final existingProduct = state.findProductByName(productName);
    if (existingProduct == null) return false;

    final updatedPackages = existingProduct.packages.where((p) => p.id != packageId).toList();
    if (updatedPackages.isEmpty) {
      // Keep at least one default single pack
      updatedPackages.add(
        ProductPackage(
          id: 'pkg-${existingProduct.sku.toLowerCase()}-1',
          productId: existingProduct.id,
          productName: existingProduct.name,
          productSku: existingProduct.sku,
          packageName: '1 Unit (Single)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: existingProduct.defaultUnitPrice,
          clientName: existingProduct.clientName,
          createdAt: DateTime.now(),
        ),
      );
    }

    final updatedProduct = existingProduct.copyWith(packages: updatedPackages);
    final updatedProductList = state.products.map((p) {
      return p.id == existingProduct.id ? updatedProduct : p;
    }).toList();

    state = state.copyWith(products: updatedProductList);
    _persistCatalog();
    return true;
  }

  /// Updates an existing commercial package (modifying name, pricing, quantities, description)
  ProductPackage? updatePackage({
    required String productName,
    required String packageId,
    required String packageName,
    required int quantity,
    int? paidQuantity,
    int? freeQuantity,
    required double packagePrice,
    String? description,
  }) {
    final existingProduct = state.findProductByName(productName);
    if (existingProduct == null) return null;

    final totalUnits = quantity > 0 ? quantity : 1;
    final paidUnits = paidQuantity ?? totalUnits;
    final freeUnits = freeQuantity ?? 0;

    ProductPackage? updatedPkg;

    final updatedPackages = existingProduct.packages.map((pkg) {
      if (pkg.id == packageId) {
        updatedPkg = pkg.copyWith(
          packageName: packageName.trim(),
          quantity: totalUnits,
          paidQuantity: paidUnits,
          freeQuantity: freeUnits,
          packagePrice: packagePrice,
          description: description?.trim().isNotEmpty == true ? description!.trim() : null,
          isCustom: true,
        );
        return updatedPkg!;
      }
      return pkg;
    }).toList();

    if (updatedPkg == null) return null;

    final updatedProduct = existingProduct.copyWith(packages: updatedPackages);
    final updatedProductList = state.products.map((p) {
      return p.id == existingProduct.id ? updatedProduct : p;
    }).toList();

    state = state.copyWith(products: updatedProductList);
    _persistCatalog();
    return updatedPkg;
  }

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
          productSku: 'SKU-GRZ-001',
          packageName: '1 Pack (Single Retail)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 22000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-grz-2',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          productSku: 'SKU-GRZ-001',
          packageName: '2 Packs Promo Deal',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 38000.0,
          clientName: 'Novacare Limited',
          description: 'Save ₦6,000 compared to single retail',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-grz-3',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          productSku: 'SKU-GRZ-001',
          packageName: '3 Packs Family Bundle',
          quantity: 3,
          paidQuantity: 3,
          freeQuantity: 0,
          packagePrice: 48000.0,
          clientName: 'Novacare Limited',
          description: 'Save ₦18,000 on family bundle',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-grz-5',
          productId: 'prod-grazer',
          productName: 'Grazer Tea',
          productSku: 'SKU-GRZ-001',
          packageName: '5 Packs Mega Deal (5 for ₦55,000)',
          quantity: 5,
          paidQuantity: 5,
          freeQuantity: 0,
          packagePrice: 55000.0,
          clientName: 'Novacare Limited',
          description: 'Best Value Deal! ₦11,000 / unit - Save ₦55,000',
          createdAt: DateTime(2026, 1, 1),
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
          productSku: 'SKU-ALPH-001',
          packageName: '1 Bottle (Standard)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 20000.0,
          clientName: 'MenHealth Global',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-alph-2',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          productSku: 'SKU-ALPH-001',
          packageName: '2 Bottles Treatment Kit',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 35000.0,
          clientName: 'MenHealth Global',
          description: 'Save ₦5,000 on 2-bottle kit',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-alph-3',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          productSku: 'SKU-ALPH-001',
          packageName: '3 Bottles Ultimate Pack',
          quantity: 3,
          paidQuantity: 3,
          freeQuantity: 0,
          packagePrice: 50000.0,
          clientName: 'MenHealth Global',
          description: 'Save ₦10,000 on full course',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-alph-5',
          productId: 'prod-alphaman',
          productName: 'Alpha Man',
          productSku: 'SKU-ALPH-001',
          packageName: '5 Bottles Wholesale Special (5 for ₦75,000)',
          quantity: 5,
          paidQuantity: 5,
          freeQuantity: 0,
          packagePrice: 75000.0,
          clientName: 'MenHealth Global',
          description: 'Wholesale rate - ₦15,000 / bottle - Save ₦25,000',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-respira',
      name: 'Respira Detox Tea',
      sku: 'SKU-RESP-01',
      clientName: 'Novacare Limited',
      defaultUnitPrice: 25000.0,
      packages: [
        ProductPackage(
          id: 'pkg-rsp-1',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          productSku: 'SKU-RESP-01',
          packageName: '1 Box (Single Course)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 25000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-rsp-2',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          productSku: 'SKU-RESP-01',
          packageName: '2 Boxes Promo Duo',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 45000.0,
          clientName: 'Novacare Limited',
          description: 'Save ₦5,000 on duo pack',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-rsp-4',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          productSku: 'SKU-RESP-01',
          packageName: '4 Boxes Full Detox Cleanse (4 for ₦80,000)',
          quantity: 4,
          paidQuantity: 4,
          freeQuantity: 0,
          packagePrice: 80000.0,
          clientName: 'Novacare Limited',
          description: 'Full 60-day cleanse - ₦20,000 / box - Save ₦20,000',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-rsp-5',
          productId: 'prod-respira',
          productName: 'Respira Detox Tea',
          productSku: 'SKU-RESP-01',
          packageName: '5 Boxes Mega Cleanse (5 for ₦95,000)',
          quantity: 5,
          paidQuantity: 5,
          freeQuantity: 0,
          packagePrice: 95000.0,
          clientName: 'Novacare Limited',
          description: 'Bulk bundle - ₦19,000 / box - Save ₦30,000',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    ),
    CatalogProduct(
      id: 'prod-biogold',
      name: 'Bio-Gold Pro Capsules',
      sku: 'SKU-BIO-001',
      clientName: 'Novacare Limited',
      defaultUnitPrice: 35000.0,
      packages: [
        ProductPackage(
          id: 'pkg-bio-1',
          productId: 'prod-biogold',
          productName: 'Bio-Gold Pro Capsules',
          productSku: 'SKU-BIO-001',
          packageName: '1 Bottle (Single Course)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 35000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-bio-2',
          productId: 'prod-biogold',
          productName: 'Bio-Gold Pro Capsules',
          productSku: 'SKU-BIO-001',
          packageName: '2 Bottles Duo Treatment',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 60000.0,
          clientName: 'Novacare Limited',
          description: 'Save ₦10,000 on 2 bottles',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-bio-3',
          productId: 'prod-biogold',
          productName: 'Bio-Gold Pro Capsules',
          productSku: 'SKU-BIO-001',
          packageName: '3 Bottles Premium Pack (Buy 2 Get 1 Free Promo)',
          quantity: 3,
          paidQuantity: 2,
          freeQuantity: 1,
          packagePrice: 70000.0,
          clientName: 'Novacare Limited',
          description: 'Buy 2 get 1 free! Save ₦35,000',
          createdAt: DateTime(2026, 1, 1),
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
          productSku: 'SKU-JNT-001',
          packageName: '1 Pack (Standard)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 35000.0,
          clientName: 'Novacare Limited',
          createdAt: DateTime(2026, 1, 1),
        ),
        ProductPackage(
          id: 'pkg-jnt-2',
          productId: 'prod-jointcare',
          productName: 'Novacare Joint Care Pack',
          productSku: 'SKU-JNT-001',
          packageName: '2 Packs Double Care Kit',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 65000.0,
          clientName: 'Novacare Limited',
          description: 'Save ₦5,000 on double pack',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    ),
  ];
}

final productCatalogProvider =
    StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ProductCatalogNotifier(storageService: storage);
});
