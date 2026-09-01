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
      if (prod.packages.length == 1 && prod.packages.first.packageName == '1 Unit (Single)') {
        return ProductCatalogNotifier.buildDefaultPackagesForProduct(
          productId: prod.id,
          productName: prod.name,
          productSku: prod.sku,
          baseUnitPrice: prod.defaultUnitPrice,
          clientName: prod.clientName,
        );
      }
      return prod.packages;
    }
    // Return rich default commercial packages for this product
    return ProductCatalogNotifier.buildDefaultPackagesForProduct(
      productId: prod?.id ?? 'prod-${productName.hashCode.abs()}',
      productName: prod?.name ?? productName,
      productSku: prod?.sku,
      baseUnitPrice: prod?.defaultUnitPrice ?? 25000.0,
      clientName: prod?.clientName ?? 'Novacare Limited',
    );
  }
}

class ProductCatalogNotifier extends StateNotifier<ProductCatalogState> {
  final LocalStorageService _storageService;

  ProductCatalogNotifier({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(const ProductCatalogState(products: [])) {
    _initCatalog();
  }

  /// Builds the standard suite of commercial package bundles for any product
  static List<ProductPackage> buildDefaultPackagesForProduct({
    required String productId,
    required String productName,
    String? productSku,
    required double baseUnitPrice,
    String clientName = 'Novacare Limited',
  }) {
    final sku = productSku ?? 'SKU-${productName.hashCode.abs()}';
    final isGrazer = productName.toLowerCase().contains('grazer');
    final p1Price = baseUnitPrice > 0 ? baseUnitPrice : 25000.0;
    final p2Price = isGrazer ? 35000.0 : (p1Price >= 25000 ? 35000.0 : (p1Price * 2 * 0.85).roundToDouble());
    final p3Price = isGrazer ? 50000.0 : (p1Price >= 25000 ? 50000.0 : (p1Price * 3 * 0.80).roundToDouble());
    const p5Price = 55000.0;

    return [
      // 1 Unit (Single)
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-1',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '1 Unit (Single)',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        packagePrice: p1Price,
        clientName: clientName,
        createdAt: DateTime.now(),
      ),
      // 2-Pack Special Deal
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-2',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '$productName 2-Pack Special Deal',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        packagePrice: p2Price,
        clientName: clientName,
        description: '2 Units Pack Deal',
        createdAt: DateTime.now(),
      ),
      // 3-Pack Value Deal
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-3',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '$productName 3-Pack Value Deal',
        quantity: 3,
        paidQuantity: 3,
        freeQuantity: 0,
        packagePrice: p3Price,
        clientName: clientName,
        description: '3 Units Value Bundle',
        createdAt: DateTime.now(),
      ),
      // 5-Pack Mega Deal (4 + 1 Free @ ₦55,000)
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-5',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '$productName 5-Pack Mega Deal (4 + 1 Free)',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        packagePrice: p5Price,
        clientName: clientName,
        description: 'Buy 4 Units, Get 1 Free Bonus (5 Total Physical Units)',
        createdAt: DateTime.now(),
      ),
    ];
  }

  RealtimeChannel? _realtimeChannel;

  Future<void> _initCatalog() async {
    try {
      final cached = await _storageService.getCachedProductCatalog();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(products: cached);
      }
    } catch (_) {}

    await reloadCatalog();
    _subscribeToRealtimeProducts();
  }

  void _subscribeToRealtimeProducts() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public:products_catalog_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            debugPrint('[CATALOG_PROVIDER] ⚡ Realtime change on products table (${payload.eventType}). Syncing...');
            reloadCatalog();
          },
        )
        ..subscribe();
      debugPrint('[CATALOG_PROVIDER] 📡 Realtime channel active for product catalogue.');
    } catch (e) {
      debugPrint('[CATALOG_PROVIDER] ℹ️ Realtime subscription notice: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
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

        // Merge with existing packages in memory / local cache
        final cachedProd = state.findProductByName(name) ?? state.findProductBySku(sku);
        if (cachedProd != null && cachedProd.packages.isNotEmpty) {
          for (final cachedPkg in cachedProd.packages) {
            if (!parsedPackages.any((p) => p.id == cachedPkg.id || p.packageName.toLowerCase() == cachedPkg.packageName.toLowerCase())) {
              parsedPackages.add(cachedPkg);
            }
          }
        }

        // If packages list only contains single 1-unit or is empty, enrich with default full packages
        if (parsedPackages.length <= 1) {
          final defaults = buildDefaultPackagesForProduct(
            productId: id,
            productName: name,
            productSku: sku,
            baseUnitPrice: basePrice,
            clientName: clientName,
          );
          for (final defPkg in defaults) {
            if (!parsedPackages.any((p) => p.packageName.toLowerCase() == defPkg.packageName.toLowerCase())) {
              parsedPackages.add(defPkg);
            }
          }
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

  /// Syncs newly created stock items from the stock inventory into the product catalog without overwriting existing packages
  void syncFromStockItems(List<StockItemEntity> stockItems) {
    var updated = false;
    final currentList = List<CatalogProduct>.from(state.products);

    for (final item in stockItems) {
      final existing = state.findProductByName(item.name) ?? state.findProductBySku(item.sku);
      if (existing == null) {
        // Register new catalog product with the full suite of commercial packages
        final newProd = CatalogProduct(
          id: item.id,
          name: item.name,
          sku: item.sku,
          clientName: item.ownerName,
          defaultUnitPrice: item.price,
          category: item.category,
          packages: buildDefaultPackagesForProduct(
            productId: item.id,
            productName: item.name,
            productSku: item.sku,
            baseUnitPrice: item.price,
            clientName: item.ownerName,
          ),
        );
        currentList.add(newProd);
        updated = true;
      } else {
        // Product exists. Merge any missing default packages while NEVER removing custom ones!
        final mergedPackages = List<ProductPackage>.from(existing.packages);
        final defaultPkgs = buildDefaultPackagesForProduct(
          productId: existing.id,
          productName: existing.name,
          productSku: existing.sku,
          baseUnitPrice: existing.defaultUnitPrice > 0 ? existing.defaultUnitPrice : item.price,
          clientName: existing.clientName,
        );
        var added = false;
        for (final defPkg in defaultPkgs) {
          if (!mergedPackages.any((p) => p.packageName.toLowerCase() == defPkg.packageName.toLowerCase() || p.quantity == defPkg.quantity)) {
            mergedPackages.add(defPkg);
            added = true;
          }
        }
        if (added) {
          final updatedProd = existing.copyWith(packages: mergedPackages);
          final idx = currentList.indexWhere((p) => p.id == existing.id);
          if (idx != -1) {
            currentList[idx] = updatedProd;
            updated = true;
          }
        }
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
      // Keep at least standard commercial defaults
      updatedPackages.addAll(
        buildDefaultPackagesForProduct(
          productId: existingProduct.id,
          productName: existingProduct.name,
          productSku: existingProduct.sku,
          baseUnitPrice: existingProduct.defaultUnitPrice,
          clientName: existingProduct.clientName,
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

  /// Explicitly registers a new product and its default packages in the catalog
  Future<CatalogProduct> registerNewProduct({
    required String name,
    required String sku,
    required double baseUnitPrice,
    String category = 'Health & Wellness',
    String clientName = 'Novacare Limited',
    List<ProductPackage>? packages,
  }) async {
    final cleanName = name.trim();
    final cleanSku = sku.trim().toUpperCase();
    final newId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final initialPackages = packages ??
        buildDefaultPackagesForProduct(
          productId: newId,
          productName: cleanName,
          productSku: cleanSku,
          baseUnitPrice: baseUnitPrice,
          clientName: clientName,
        );

    final newProduct = CatalogProduct(
      id: newId,
      name: cleanName,
      sku: cleanSku,
      clientName: clientName,
      defaultUnitPrice: baseUnitPrice,
      category: category,
      packages: initialPackages,
    );

    final updated = [
      ...state.products.where((p) => p.sku.toUpperCase() != cleanSku && p.name.toLowerCase() != cleanName.toLowerCase()),
      newProduct
    ];
    state = state.copyWith(products: updated);
    await _persistCatalog();
    return newProduct;
  }
}

final productCatalogProvider =
    StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ProductCatalogNotifier(storageService: storage);
});
