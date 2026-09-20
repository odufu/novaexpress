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
    return prod?.packages ?? const [];
  }
}

class ProductCatalogNotifier extends StateNotifier<ProductCatalogState> {
  final LocalStorageService _storageService;

  ProductCatalogNotifier({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(const ProductCatalogState(products: [])) {
    _initCatalog();
  }

  SupabaseClient _getAuthDbClient() {
    return SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  /// Builds the baseline single-unit commercial package for a product.
  /// NOTE: Strict pricing governance forbids synthetic multi-pack discount calculations.
  /// All multi-pack bundles must be pre-created by merchants or operators in public.product_packages.
  static List<ProductPackage> buildDefaultPackagesForProduct({
    required String productId,
    required String productName,
    String? productSku,
    required double baseUnitPrice,
    String clientName = '',
  }) {
    final sku = productSku ?? 'SKU-${productName.hashCode.abs()}';
    final p1Price = baseUnitPrice > 0 ? baseUnitPrice : 0.0;
    final lower = productName.toLowerCase();

    if (lower.contains('respira')) {
      return [
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-1',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '1 Unit (Single) - 1 Box',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 21500.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-2',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '2 Boxes Promo Deal',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 35000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-3',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '3 Boxes Cleanse Bundle',
          quantity: 3,
          paidQuantity: 3,
          freeQuantity: 0,
          packagePrice: 45000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-5',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '4 Boxes + 1 Box Free Mega Deal (4 + 1 Free)',
          quantity: 5,
          paidQuantity: 4,
          freeQuantity: 1,
          packagePrice: 55000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
      ];
    }

    if (lower.contains('grazer')) {
      return [
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-1',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '1 Unit (Single)',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          packagePrice: 25000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-2',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '2-Pack Deal',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          packagePrice: 35000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-3',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '3-Pack Family Deal',
          quantity: 3,
          paidQuantity: 3,
          freeQuantity: 0,
          packagePrice: 50000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
        ProductPackage(
          id: 'pkg-${sku.toLowerCase()}-5',
          productId: productId,
          productName: productName,
          productSku: sku,
          packageName: '5-Pack Mega Deal (4 + 1 Free)',
          quantity: 5,
          paidQuantity: 4,
          freeQuantity: 1,
          packagePrice: 55000.0,
          clientName: clientName,
          createdAt: DateTime.now(),
        ),
      ];
    }

    return [
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
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-2',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '2-Pack Deal',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        packagePrice: (p1Price * 1.7).roundToDouble(),
        clientName: clientName,
        createdAt: DateTime.now(),
      ),
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-3',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '3-Pack Value Deal',
        quantity: 3,
        paidQuantity: 3,
        freeQuantity: 0,
        packagePrice: (p1Price * 2.4).roundToDouble(),
        clientName: clientName,
        createdAt: DateTime.now(),
      ),
      ProductPackage(
        id: 'pkg-${sku.toLowerCase()}-5',
        productId: productId,
        productName: productName,
        productSku: sku,
        packageName: '5-Pack Mega Saver (4 + 1 Free)',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        packagePrice: (p1Price * 3.2).roundToDouble(),
        clientName: clientName,
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
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_packages',
          callback: (payload) {
            debugPrint('[CATALOG_PROVIDER] ⚡ Realtime change on product_packages table (${payload.eventType}). Syncing...');
            reloadCatalog();
          },
        )
        ..subscribe();
      debugPrint('[CATALOG_PROVIDER] 📡 Realtime channel active for product catalogue & packages.');
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

      List<ProductPackage> dbPackages = [];
      try {
        final packagesRes = await dbClient
            .from('product_packages')
            .select()
            .order('created_at', ascending: true);
        for (final pkgRow in (packagesRes as List)) {
          try {
            dbPackages.add(ProductPackage.fromJson(pkgRow as Map<String, dynamic>));
          } catch (_) {}
        }
      } catch (pkgErr) {
        debugPrint('[CATALOG_PROVIDER] ℹ️ Supabase product_packages fetch notice: $pkgErr');
      }

      // 1.5 Aggregate live stock balances across regional hubs
      final Map<String, int> stockAggregates = {};
      try {
        final balancesRes = await dbClient
            .from('client_stock_balances')
            .select('item_code, item_name, balance_qty');
        for (final b in (balancesRes as List)) {
          final bMap = b as Map<String, dynamic>;
          final itemCode = (bMap['item_code'] ?? '').toString().trim().toUpperCase();
          final itemName = (bMap['item_name'] ?? '').toString().trim().toLowerCase();
          final qty = (bMap['balance_qty'] as num?)?.toInt() ?? 0;
          if (itemCode.isNotEmpty) {
            stockAggregates[itemCode] = (stockAggregates[itemCode] ?? 0) + qty;
          }
          if (itemName.isNotEmpty) {
            stockAggregates[itemName] = (stockAggregates[itemName] ?? 0) + qty;
          }
        }
      } catch (balErr) {
        debugPrint('[CATALOG_PROVIDER] ℹ️ Stock balances aggregate notice: $balErr');
      }

      final List<CatalogProduct> fetchedProducts = [];

      for (final raw in (response as List)) {
        final map = raw as Map<String, dynamic>;
        final id = map['id']?.toString() ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
        final name = map['name']?.toString() ?? 'Product';
        final sku = map['sku']?.toString() ?? 'SKU-001';
        final basePrice = (map['base_price'] as num?)?.toDouble() ?? 0.0;
        final costPrice = (map['cost_price'] as num?)?.toDouble() ?? 0.0;
        final barcode = map['barcode']?.toString();
        final weightKg = (map['weight_kg'] as num?)?.toDouble() ?? 0.5;
        final lowStockThreshold = (map['low_stock_threshold'] as num?)?.toInt() ?? 10;
        final category = map['category']?.toString() ?? 'Health & Wellness';
        final description = map['description']?.toString() ?? '';
        final clientName = map['client_name']?.toString() ?? '';
        final clientId = map['client_id']?.toString();
        final imageUrl = map['image_url']?.toString();

        final skuUpper = sku.trim().toUpperCase();
        final nameLower = name.trim().toLowerCase();
        int stockCount = (map['available_count'] ?? map['stock_quantity'] as num?)?.toInt() ?? 0;
        if (stockCount == 0) {
          stockCount = stockAggregates[skuUpper] ?? stockAggregates[nameLower] ?? 0;
          if (stockCount == 0) {
            for (final entry in stockAggregates.entries) {
              if (nameLower.contains(entry.key) || entry.key.contains(nameLower)) {
                stockCount = entry.value;
                break;
              }
            }
          }
        }

        List<String> parsedCoveringStates = [];
        if (map['covering_states'] is List) {
          parsedCoveringStates = (map['covering_states'] as List).map((e) => e.toString()).toList();
        } else if (description.contains('[COVERING_STATES:')) {
          final match = RegExp(r'\[COVERING_STATES:\s*(\[.*?\])\]').firstMatch(description);
          if (match != null) {
            try {
              final decoded = jsonDecode(match.group(1)!) as List<dynamic>;
              parsedCoveringStates = decoded.map((e) => e.toString()).toList();
            } catch (_) {}
          }
        }

        List<ProductPackage> parsedPackages = [];

        // 1. Gather packages from Supabase product_packages table
        final matchingDbPackages = dbPackages.where((dp) {
          final matchProdId = dp.productId == id;
          final matchSku = dp.productSku != null && dp.productSku!.toUpperCase() == sku.toUpperCase();
          final matchName = dp.productName.trim().toLowerCase() == name.trim().toLowerCase();
          final matchClient = dp.clientId == null || dp.clientId == clientId || dp.clientName.toLowerCase() == clientName.toLowerCase();
          return (matchProdId || matchSku || matchName) && matchClient;
        }).toList();
        parsedPackages.addAll(matchingDbPackages);

        // 2. Check if packages JSON is embedded in description: e.g. [PACKAGES: [{"id": "...", ...}]]
        if (description.contains('[PACKAGES:')) {
          try {
            final pkgMarker = description.indexOf('[PACKAGES:');
            final jsonStart = description.indexOf('[', pkgMarker + 10);
            if (jsonStart != -1) {
              int bracketCount = 0;
              int jsonEnd = -1;
              for (int i = jsonStart; i < description.length; i++) {
                if (description[i] == '[') bracketCount++;
                if (description[i] == ']') {
                  bracketCount--;
                  if (bracketCount == 0) {
                    jsonEnd = i;
                    break;
                  }
                }
              }

              if (jsonEnd != -1) {
                final jsonStr = description.substring(jsonStart, jsonEnd + 1).trim();
                final decodedList = jsonDecode(jsonStr) as List;
                for (final item in decodedList) {
                  final pkg = ProductPackage.fromJson(item as Map<String, dynamic>);
                  if (!parsedPackages.any((p) => p.id == pkg.id || p.packageName.toLowerCase() == pkg.packageName.toLowerCase())) {
                    parsedPackages.add(pkg);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[CATALOG_PROVIDER] ⚠️ Could not parse embedded packages for $name: $e');
          }
        }

        // 3. Merge with existing packages in memory / local cache
        final cachedProd = state.findProductByName(name) ?? state.findProductBySku(sku);
        if (cachedProd != null && cachedProd.packages.isNotEmpty) {
          for (final cachedPkg in cachedProd.packages) {
            if (!parsedPackages.any((p) => p.id == cachedPkg.id || p.packageName.toLowerCase() == cachedPkg.packageName.toLowerCase())) {
              parsedPackages.add(cachedPkg);
            }
          }
        }

        // 4. If packages list is empty, add baseline 1-unit package
        if (parsedPackages.isEmpty && basePrice > 0) {
          final defaults = buildDefaultPackagesForProduct(
            productId: id,
            productName: name,
            productSku: sku,
            baseUnitPrice: basePrice,
            clientName: clientName,
          );
          parsedPackages.addAll(defaults);
        }

        fetchedProducts.add(
          CatalogProduct(
            id: id,
            name: name,
            sku: sku,
            clientName: clientName,
            clientId: clientId,
            defaultUnitPrice: basePrice,
            costPrice: costPrice,
            barcode: barcode,
            weightKg: weightKg,
            lowStockThreshold: lowStockThreshold,
            category: category,
            description: description,
            imageUrl: imageUrl,
            totalStockAcrossHubs: stockCount,
            coveringStates: parsedCoveringStates,
            packages: parsedPackages,
          ),
        );
      }

      state = state.copyWith(products: fetchedProducts, isLoading: false);
      await _storageService.cacheProductCatalog(fetchedProducts);
      debugPrint('[CATALOG_PROVIDER] 📦 Loaded ${fetchedProducts.length} authoritative products and package configurations from Supabase.');
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
      dbClient = _getAuthDbClient();

      final updatedProducts = <CatalogProduct>[];

      for (final p in state.products) {
        var baseDesc = (p.description != null && p.description!.trim().isNotEmpty)
            ? p.description!
            : p.name;
        // Clean out previous [PACKAGES: ...] tag
        final pkgRegex = RegExp(r'\[PACKAGES:\s*(\[.*?\])\]');
        baseDesc = baseDesc.replaceAll(pkgRegex, '').trim();

        // Ensure covering states tag is present if product has covering states
        if (p.coveringStates.isNotEmpty && !baseDesc.contains('[COVERING_STATES:')) {
          baseDesc = '$baseDesc [COVERING_STATES: ${jsonEncode(p.coveringStates)}]';
        }

        final packagesJson = jsonEncode(p.packages.map((pkg) => pkg.toJson()).toList());
        final combinedDesc = '$baseDesc [PACKAGES: $packagesJson]'.trim();
        final updatedProd = p.copyWith(description: combinedDesc);
        updatedProducts.add(updatedProd);

        try {
          final bool isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(p.id);
          final cleanCId = (p.clientId != null &&
                  RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(p.clientId!))
              ? p.clientId
              : null;

          dynamic res;
          if (isValidUuid) {
            res = await dbClient.from('products').update({
              'description': combinedDesc,
              if (p.clientName.isNotEmpty) 'client_name': p.clientName,
              if (cleanCId != null) 'client_id': cleanCId,
              if (p.imageUrl != null && p.imageUrl!.isNotEmpty) 'image_url': p.imageUrl,
              if (p.coveringStates.isNotEmpty) 'covering_states': p.coveringStates,
              'cost_price': p.costPrice,
              if (p.barcode != null && p.barcode!.isNotEmpty) 'barcode': p.barcode,
              'weight_kg': p.weightKg,
              'low_stock_threshold': p.lowStockThreshold,
            }).eq('id', p.id).select();
          }

          if (res == null || (res as List).isEmpty) {
            final resBySku = await dbClient.from('products').update({
              'description': combinedDesc,
              if (p.clientName.isNotEmpty) 'client_name': p.clientName,
              if (cleanCId != null) 'client_id': cleanCId,
              if (p.imageUrl != null && p.imageUrl!.isNotEmpty) 'image_url': p.imageUrl,
              if (p.coveringStates.isNotEmpty) 'covering_states': p.coveringStates,
              'cost_price': p.costPrice,
              if (p.barcode != null && p.barcode!.isNotEmpty) 'barcode': p.barcode,
              'weight_kg': p.weightKg,
              'low_stock_threshold': p.lowStockThreshold,
            }).eq('sku', p.sku).select();

            if ((resBySku as List).isEmpty) {
              final resByName = await dbClient.from('products').update({
                'description': combinedDesc,
                if (p.clientName.isNotEmpty) 'client_name': p.clientName,
                if (cleanCId != null) 'client_id': cleanCId,
                if (p.imageUrl != null && p.imageUrl!.isNotEmpty) 'image_url': p.imageUrl,
                if (p.coveringStates.isNotEmpty) 'covering_states': p.coveringStates,
                'cost_price': p.costPrice,
                if (p.barcode != null && p.barcode!.isNotEmpty) 'barcode': p.barcode,
                'weight_kg': p.weightKg,
                'low_stock_threshold': p.lowStockThreshold,
              }).eq('name', p.name).select();

              if ((resByName as List).isEmpty) {
                // Not yet created in remote DB, upsert it now cleanly
                const compId = '11111111-1111-4111-8111-111111111111';
                final Map<String, dynamic> insertPayload = {
                  'company_id': compId,
                  'name': p.name,
                  'sku': p.sku,
                  'category': p.category,
                  'base_price': p.defaultUnitPrice,
                  'cost_price': p.costPrice,
                  if (p.barcode != null && p.barcode!.isNotEmpty) 'barcode': p.barcode,
                  'weight_kg': p.weightKg,
                  'low_stock_threshold': p.lowStockThreshold,
                  if (p.clientName.isNotEmpty) 'client_name': p.clientName,
                  if (cleanCId != null) 'client_id': cleanCId,
                  if (p.imageUrl != null && p.imageUrl!.isNotEmpty) 'image_url': p.imageUrl,
                  if (p.coveringStates.isNotEmpty) 'covering_states': p.coveringStates,
                  'description': combinedDesc,
                  'is_active': true,
                };
                if (isValidUuid) {
                  insertPayload['id'] = p.id;
                }
                final insRes = await dbClient.from('products').upsert(insertPayload, onConflict: 'sku').select('id').maybeSingle();
                if (insRes != null && insRes['id'] != null && !isValidUuid) {
                  final effectiveId = insRes['id'].toString();
                  for (final pkg in p.packages) {
                    try {
                      final pkgPayload = pkg.copyWith(
                        productId: effectiveId,
                        clientName: p.clientName,
                        clientId: cleanCId,
                      ).toJson();
                      await dbClient.from('product_packages').upsert(pkgPayload);
                    } catch (_) {}
                  }
                }
              }
            }
          }

          // Authoritatively persist packages into product_packages table
          for (final pkg in p.packages) {
            try {
              final pkgPayload = pkg.copyWith(
                productId: isValidUuid ? p.id : pkg.productId,
                clientName: p.clientName,
                clientId: cleanCId,
              ).toJson();
              await dbClient.from('product_packages').upsert(pkgPayload);
            } catch (_) {}
          }
        } catch (_) {
          try {
            await dbClient.from('products').update({
              'description': combinedDesc,
            }).eq('sku', p.sku);
          } catch (_) {}
        }
      }
      if (updatedProducts.isNotEmpty) {
        state = state.copyWith(products: updatedProducts);
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
    String? clientId,
    String? productId,
    String? productSku,
    String? description,
  }) {
    final cleanProd = productName.trim();
    final cleanPkg = packageName.trim();
    final existingProduct = state.findProductByName(cleanProd) ?? (productSku != null ? state.findProductBySku(productSku) : null);
    final cleanClient = clientName?.trim().isNotEmpty == true
        ? clientName!.trim()
        : (existingProduct?.clientName ?? '');
    final totalUnits = quantity > 0 ? quantity : 1;
    final paidUnits = paidQuantity ?? totalUnits;
    final freeUnits = freeQuantity ?? 0;
    final effectiveClientId = clientId ?? existingProduct?.clientId;
    final cleanSku = (productSku ?? existingProduct?.sku ?? cleanProd).replaceAll(' ', '_').toLowerCase();
    final packageId = effectiveClientId != null && effectiveClientId.isNotEmpty
        ? 'pkg_${effectiveClientId}_${cleanSku}_${totalUnits}_${DateTime.now().millisecondsSinceEpoch}'
        : 'pkg-${DateTime.now().millisecondsSinceEpoch}';

    final newPackage = ProductPackage(
      id: packageId,
      productId: productId ?? existingProduct?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      productName: existingProduct?.name ?? cleanProd,
      productSku: productSku ?? existingProduct?.sku,
      packageName: cleanPkg,
      quantity: totalUnits,
      paidQuantity: paidUnits,
      freeQuantity: freeUnits,
      packagePrice: packagePrice,
      clientName: existingProduct?.clientName ?? cleanClient,
      clientId: effectiveClientId,
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
        id: productId ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
        name: cleanProd,
        sku: productSku ?? 'SKU-${cleanProd.replaceAll(" ", "").substring(0, cleanProd.replaceAll(" ", "").length.clamp(0, 4)).toUpperCase()}-${DateTime.now().millisecond}',
        clientName: cleanClient,
        clientId: effectiveClientId,
        defaultUnitPrice: totalUnits > 0 ? packagePrice / totalUnits : packagePrice,
        packages: [newPackage],
      );

      state = state.copyWith(products: [...state.products, newProduct]);
    }

    // Persist to Supabase product_packages table asynchronously
    try {
      final db = _getAuthDbClient();
      final cleanCId = (effectiveClientId != null &&
              RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(effectiveClientId))
          ? effectiveClientId
          : null;
      final payload = newPackage.copyWith(clientId: cleanCId).toJson();
      db.from('product_packages').upsert(payload).then((_) {
        debugPrint('[CATALOG_PROVIDER] ✅ Persisted package ${newPackage.packageName} to Supabase product_packages.');
        db.dispose();
      }).catchError((err) {
        debugPrint('[CATALOG_PROVIDER] ℹ️ Error saving to product_packages table: $err');
        db.dispose();
      });
    } catch (_) {}

    _persistCatalog();
    return newPackage;
  }

  /// Removes a package from a product
  bool deletePackage({required String productName, required String packageId}) {
    final existingProduct = state.findProductByName(productName);
    if (existingProduct == null) return false;

    final updatedPackages = existingProduct.packages.where((p) => p.id != packageId).toList();
    // Maintain autonomous package sets: do not force re-injection of standard defaults
    final updatedProduct = existingProduct.copyWith(packages: updatedPackages);
    final updatedProductList = state.products.map((p) {
      return p.id == existingProduct.id ? updatedProduct : p;
    }).toList();

    state = state.copyWith(products: updatedProductList);

    // Delete from Supabase product_packages table asynchronously
    try {
      final db = _getAuthDbClient();
      db.from('product_packages').delete().eq('id', packageId).then((_) {
        debugPrint('[CATALOG_PROVIDER] ✅ Deleted package $packageId from Supabase product_packages.');
        db.dispose();
      }).catchError((err) {
        debugPrint('[CATALOG_PROVIDER] ℹ️ Error deleting from product_packages: $err');
        db.dispose();
      });
    } catch (_) {}

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

    // Update in Supabase product_packages table asynchronously
    try {
      final db = _getAuthDbClient();
      db.from('product_packages').update(updatedPkg!.toJson()).eq('id', packageId).then((_) {
        debugPrint('[CATALOG_PROVIDER] ✅ Updated package $packageId in Supabase product_packages.');
        db.dispose();
      }).catchError((err) {
        debugPrint('[CATALOG_PROVIDER] ℹ️ Error updating product_packages: $err');
        db.dispose();
      });
    } catch (_) {}

    _persistCatalog();
    return updatedPkg;
  }

  /// Explicitly registers a new product and its default packages in the catalog
  Future<CatalogProduct> registerNewProduct({
    String? id,
    required String name,
    required String sku,
    required double baseUnitPrice,
    double? costPrice,
    String? barcode,
    double? weightKg,
    int? lowStockThreshold,
    String category = 'Health & Wellness',
    String clientName = '',
    String? clientId,
    String? description,
    String? imageUrl,
    String? preferredSupplierId,
    List<String> coveringStates = const [],
    List<ProductPackage>? packages,
  }) async {
    final cleanName = name.trim();
    final cleanSku = sku.trim().toUpperCase();
    final newId = (id != null && id.isNotEmpty) ? id : 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final initialPackages = packages ??
        buildDefaultPackagesForProduct(
          productId: newId,
          productName: cleanName,
          productSku: cleanSku,
          baseUnitPrice: baseUnitPrice,
          clientName: clientName,
        );

    final cleanClientId = (clientId != null &&
            clientId.trim().isNotEmpty &&
            RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(clientId.trim()))
        ? clientId.trim()
        : null;

    final newProduct = CatalogProduct(
      id: newId,
      name: cleanName,
      sku: cleanSku,
      clientName: clientName,
      clientId: cleanClientId,
      defaultUnitPrice: baseUnitPrice,
      costPrice: costPrice ?? 0.0,
      barcode: barcode,
      weightKg: weightKg ?? 0.5,
      lowStockThreshold: lowStockThreshold ?? 10,
      category: category,
      description: description,
      imageUrl: imageUrl,
      totalStockAcrossHubs: 0,
      preferredSupplierId: preferredSupplierId,
      coveringStates: coveringStates,
      packages: initialPackages,
    );

    // Persist new product and packages directly to Supabase using authenticated client
    SupabaseClient? dbClient;
    String effectiveProdId = newId;
    try {
      dbClient = _getAuthDbClient();
      final bool isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(newId);

      final Map<String, dynamic> productPayload = {
        'name': cleanName,
        'sku': cleanSku,
        'base_price': baseUnitPrice,
        'cost_price': costPrice ?? 0.0,
        if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
        'weight_kg': weightKg ?? 0.5,
        'low_stock_threshold': lowStockThreshold ?? 10,
        'category': category,
        'client_name': clientName.isNotEmpty ? clientName : 'NovaXpress Merchant',
        if (cleanClientId != null) 'client_id': cleanClientId,
        if (preferredSupplierId != null && preferredSupplierId.isNotEmpty) 'preferred_supplier_id': preferredSupplierId,
        'description': description,
        'image_url': imageUrl,
        'stock_quantity': 0,
        'available_count': 0,
        'in_transit_count': 0,
        'delivered_count': 0,
        'is_active': true,
        'company_id': '11111111-1111-4111-8111-111111111111',
        if (coveringStates.isNotEmpty) 'covering_states': coveringStates,
      };
      if (isValidUuid) {
        productPayload['id'] = newId;
      }
      final upsertRes = await dbClient
          .from('products')
          .upsert(productPayload, onConflict: 'sku')
          .select('id')
          .maybeSingle();

      if (upsertRes != null && upsertRes['id'] != null) {
        effectiveProdId = upsertRes['id'].toString();
      }

      for (final pkg in initialPackages) {
        final pkgPayload = pkg.copyWith(
          productId: effectiveProdId,
          clientName: clientName,
          clientId: cleanClientId,
        ).toJson();
        await dbClient.from('product_packages').upsert(pkgPayload);
      }
      debugPrint('[CATALOG_PROVIDER] ✅ Authoritatively saved new product $cleanSku ($effectiveProdId) and ${initialPackages.length} package(s) to Supabase.');
    } catch (e, st) {
      debugPrint('[CATALOG_PROVIDER] ❌ Register product to Supabase error: $e\n$st');
    } finally {
      dbClient?.dispose();
    }

    final finalProduct = newProduct.copyWith(
      id: effectiveProdId,
      packages: initialPackages.map((p) => p.copyWith(productId: effectiveProdId)).toList(),
    );

    final updated = [
      ...state.products.where((p) => p.sku.toUpperCase() != cleanSku && p.name.toLowerCase() != cleanName.toLowerCase()),
      finalProduct
    ];
    state = state.copyWith(products: updated);

    await _persistCatalog();
    return finalProduct;
  }
}

final productCatalogProvider =
    StateNotifierProvider<ProductCatalogNotifier, ProductCatalogState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ProductCatalogNotifier(storageService: storage);
});
