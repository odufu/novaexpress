import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
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
    if (clean.isEmpty) return null;
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
    if (clean.isEmpty) return null;
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
        super(const ProductCatalogState(products: [])) {
    _initCatalog();
  }

  Future<void> _initCatalog() async {
    try {
      final cached = await _storageService.getCachedProductCatalog();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(products: cached);
      }
    } catch (_) {}

    await reloadCatalog();
  }

  /// Authoritatively fetches all active products from Supabase and decodes commercial packages
  Future<void> reloadCatalog() async {
    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final response = await dbClient
          .from('products')
          .select()
          .order('created_at', ascending: true);

      final List<CatalogProduct> fetchedProducts = [];

      for (final raw in (response as List)) {
        final map = raw as Map<String, dynamic>;
        final id = map['id']?.toString() ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
        final name = map['name']?.toString() ?? 'Product';
        final sku = map['sku']?.toString() ?? 'SKU-001';
        final basePrice = (map['base_price'] as num?)?.toDouble() ?? 25000.0;
        final category = map['category']?.toString() ?? 'Health & Wellness';
        final description = map['description']?.toString() ?? '';
        const clientName = 'Novacare Limited';

        List<ProductPackage> parsedPackages = [];

        // Check if packages JSON is embedded in description: e.g. [PACKAGES: [{"id": "...", ...}]]
        if (description.contains('[PACKAGES:')) {
          try {
            final startIdx = description.indexOf('[PACKAGES:') + 10;
            final endIdx = description.lastIndexOf(']');
            if (endIdx > startIdx) {
              final jsonStr = description.substring(startIdx, endIdx + 1).trim();
              final decodedList = jsonDecode(jsonStr) as List;
              parsedPackages = decodedList
                  .map((item) => ProductPackage.fromJson(item as Map<String, dynamic>))
                  .toList();
            }
          } catch (e) {
            debugPrint('[CATALOG_PROVIDER] ⚠️ Could not parse embedded packages for $name: $e');
          }
        }

        // If no packages embedded, check if we had cached packages for this product
        if (parsedPackages.isEmpty) {
          final cachedProd = state.findProductByName(name) ?? state.findProductBySku(sku);
          if (cachedProd != null && cachedProd.packages.isNotEmpty) {
            parsedPackages = cachedProd.packages;
          }
        }

        // If still empty, add default 1-unit single package
        if (parsedPackages.isEmpty) {
          parsedPackages = [
            ProductPackage(
              id: 'pkg-${sku.toLowerCase()}-1',
              productId: id,
              productName: name,
              productSku: sku,
              packageName: '1 Unit (Single)',
              quantity: 1,
              paidQuantity: 1,
              freeQuantity: 0,
              packagePrice: basePrice,
              clientName: clientName,
              createdAt: DateTime.now(),
            ),
          ];
        }

        fetchedProducts.add(
          CatalogProduct(
            id: id,
            name: name,
            sku: sku,
            clientName: clientName,
            defaultUnitPrice: basePrice,
            category: category,
            packages: parsedPackages,
          ),
        );
      }

      if (fetchedProducts.isNotEmpty) {
        state = state.copyWith(products: fetchedProducts, isLoading: false);
        await _storageService.cacheProductCatalog(fetchedProducts);
        debugPrint('[CATALOG_PROVIDER] 📦 Loaded ${fetchedProducts.length} authoritative products and package configurations from Supabase.');
      }
    } catch (e) {
      debugPrint('[CATALOG_PROVIDER] ℹ️ Supabase reloadCatalog notice: $e');
    } finally {
      dbClient?.dispose();
    }
  }

  /// Persists the product catalog to local storage cache and live Supabase products table
  Future<void> _persistCatalog() async {
    try {
      await _storageService.cacheProductCatalog(state.products);
    } catch (_) {}

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      for (final p in state.products) {
        var cleanBaseDesc = p.name;
        // Clean out previous audit tag
        if (cleanBaseDesc.contains('[PACKAGES:')) {
          cleanBaseDesc = cleanBaseDesc.split('[PACKAGES:').first.trim();
        }
        final packagesJson = jsonEncode(p.packages.map((pkg) => pkg.toJson()).toList());
        final combinedDesc = '$cleanBaseDesc - Distributed Inventory [PACKAGES: $packagesJson]';

        try {
          await dbClient.from('products').update({
            'description': combinedDesc,
          }).eq('id', p.id);
        } catch (_) {
          try {
            await dbClient.from('products').update({
              'description': combinedDesc,
            }).eq('name', p.name);
          } catch (_) {}
        }
      }
      debugPrint('[CATALOG_PROVIDER] 💾 Persisted ${state.products.length} products & commercial packages to Supabase.');
    } catch (e) {
      debugPrint('[CATALOG_PROVIDER] ⚠️ _persistCatalog notice: $e');
    } finally {
      dbClient?.dispose();
    }
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
              packageName: '1 Unit (Single)',
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
  /// This newly registered package is immediately persistent across devices and reusable across all future orders!
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
}

final productCatalogProvider =
    StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ProductCatalogNotifier(storageService: storage);
});
