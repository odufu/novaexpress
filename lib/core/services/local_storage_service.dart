import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dc_console/domain/entities/dc_fleet_driver.dart';
import '../../features/dc_console/domain/entities/dc_payout_claim.dart';
import '../../features/dc_console/domain/entities/dc_transaction_record.dart';
import '../../features/dc_console/domain/entities/product_package.dart';
import '../../features/dc_console/presentation/providers/dc_console_provider.dart';
import '../../features/finance/data/models/remittance_model.dart';
import '../../features/finance/domain/entities/remittance.dart';
import '../../features/finance/domain/entities/transaction_item.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/orders/data/models/order_model.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/stock/data/models/stock_item_model.dart';
import '../../features/stock/domain/entities/rider_stock_allocation.dart';
import '../../features/stock/domain/entities/stock_item.dart';

abstract class LocalStorageService {
  Future<void> saveJsonList(String key, List<Map<String, dynamic>> items);
  Future<List<Map<String, dynamic>>?> getJsonList(String key);
  Future<void> saveJsonObject(String key, Map<String, dynamic> item);
  Future<Map<String, dynamic>?> getJsonObject(String key);
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> remove(String key);
  Future<void> clearAll();

  // Domain-specific caching methods
  Future<void> cacheFleetDrivers(List<DCFleetDriver> drivers);
  Future<List<DCFleetDriver>?> getCachedFleetDrivers();

  Future<void> cachePayoutClaims(List<DCPayoutClaim> claims);
  Future<List<DCPayoutClaim>?> getCachedPayoutClaims();

  Future<void> cacheDcTransactions(List<DCTransactionRecord> txns);
  Future<List<DCTransactionRecord>?> getCachedDcTransactions();

  Future<void> cacheOrders(List<OrderEntity> orders, [String? scopeKey]);
  Future<List<OrderEntity>?> getCachedOrders([String? scopeKey]);

  Future<void> cacheWarehouseBatches(List<DCWarehouseBatch> batches);
  Future<List<DCWarehouseBatch>?> getCachedWarehouseBatches();

  Future<void> cacheReturnItems(List<DCReturnItem> returns);
  Future<List<DCReturnItem>?> getCachedReturnItems();

  Future<void> cacheRemittances(List<RemittanceEntity> remittances);
  Future<List<RemittanceEntity>?> getCachedRemittances();

  Future<void> cacheTransactions(List<TransactionItem> transactions);
  Future<List<TransactionItem>?> getCachedTransactions();

  Future<void> cacheStockItems(List<StockItemEntity> items);
  Future<List<StockItemEntity>?> getCachedStockItems();

  Future<void> cacheRiderStockAllocations(List<RiderStockAllocation> allocations);
  Future<List<RiderStockAllocation>?> getCachedRiderStockAllocations();

  Future<void> cacheNotifications(String agentId, List<AppNotificationEntity> notifications);
  Future<List<AppNotificationEntity>?> getCachedNotifications(String agentId);

  Future<void> cacheProductCatalog(List<CatalogProduct> products);
  Future<List<CatalogProduct>?> getCachedProductCatalog();

  Future<void> cacheUserProfile(Map<String, dynamic> userJson);
  Future<Map<String, dynamic>?> getCachedUserProfile();
  Future<void> clearUserProfile();

  Future<void> setLastSyncTime(String moduleKey);
  Future<DateTime?> getLastSyncTime(String moduleKey);
}

class LocalStorageServiceImpl implements LocalStorageService {
  static const String _fleetDriversKey = 'novexps_cache_fleet_drivers';
  static const String _payoutClaimsKey = 'novexps_cache_payout_claims';
  static const String _ordersKey = 'novexps_cache_orders';
  static const String _batchesKey = 'novexps_cache_warehouse_batches';
  static const String _returnsKey = 'novexps_cache_return_items';
  static const String _remittancesKey = 'novexps_cache_remittances';
  static const String _transactionsKey = 'novexps_cache_transactions';
  static const String _dcTransactionsKey = 'novexps_cache_dc_transactions';
  static const String _stockKey = 'novexps_cache_stock_items';
  static const String _riderAllocationsKey = 'novexps_cache_rider_stock_allocations';
  static const String _productCatalogKey = 'novexps_cache_product_catalog';
  static const String _userProfileKey = 'novexps_cache_user_profile';
  static const String _notificationsPrefix = 'novexps_cache_notifications_';
  static const String _syncTimePrefix = 'novexps_sync_time_';

  // In-memory fallback if platform storage is unavailable
  final Map<String, String> _memoryStore = {};

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] ⚠️ SharedPreferences notice ($e). Utilizing memory fallback.');
      return null;
    }
  }

  @override
  Future<void> saveJsonList(String key, List<Map<String, dynamic>> items) async {
    try {
      final jsonStr = jsonEncode(items);
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(key, jsonStr);
      } else {
        _memoryStore[key] = jsonStr;
      }
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] ⚠️ saveJsonList error for $key: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs?.getString(key) ?? _memoryStore[key];
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] ⚠️ getJsonList error for $key: $e');
    }
    return null;
  }

  @override
  Future<void> saveJsonObject(String key, Map<String, dynamic> item) async {
    try {
      final jsonStr = jsonEncode(item);
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(key, jsonStr);
      } else {
        _memoryStore[key] = jsonStr;
      }
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] ⚠️ saveJsonObject error for $key: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getJsonObject(String key) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs?.getString(key) ?? _memoryStore[key];
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] ⚠️ getJsonObject error for $key: $e');
    }
    return null;
  }

  @override
  Future<void> saveString(String key, String value) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      await prefs.setString(key, value);
    } else {
      _memoryStore[key] = value;
    }
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _getPrefs();
    return prefs?.getString(key) ?? _memoryStore[key];
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await _getPrefs();
    await prefs?.remove(key);
    _memoryStore.remove(key);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs?.clear();
    _memoryStore.clear();
  }

  // --- DC Fleet Drivers Caching ---

  @override
  Future<void> cacheFleetDrivers(List<DCFleetDriver> drivers) async {
    final list = drivers.map((d) => d.toJson()).toList();
    await saveJsonList(_fleetDriversKey, list);
    await setLastSyncTime('fleet_drivers');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${drivers.length} fleet drivers to local storage.');
  }

  @override
  Future<List<DCFleetDriver>?> getCachedFleetDrivers() async {
    final rawList = await getJsonList(_fleetDriversKey);
    if (rawList == null || rawList.isEmpty) return null;

    final drivers = <DCFleetDriver>[];
    for (final map in rawList) {
      try {
        drivers.add(DCFleetDriver.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached driver: $e');
      }
    }
    return drivers.isNotEmpty ? drivers : null;
  }

  // --- Payout Claims Caching ---

  @override
  Future<void> cachePayoutClaims(List<DCPayoutClaim> claims) async {
    final list = claims.map((c) => c.toJson()).toList();
    await saveJsonList(_payoutClaimsKey, list);
    await setLastSyncTime('payout_claims');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${claims.length} payout claims to local storage.');
  }

  @override
  Future<List<DCPayoutClaim>?> getCachedPayoutClaims() async {
    final rawList = await getJsonList(_payoutClaimsKey);
    if (rawList == null || rawList.isEmpty) return null;

    final claims = <DCPayoutClaim>[];
    for (final map in rawList) {
      try {
        claims.add(DCPayoutClaim.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached payout claim: $e');
      }
    }
    return claims.isNotEmpty ? claims : null;
  }

  // --- DC Transactions Caching ---

  @override
  Future<void> cacheDcTransactions(List<DCTransactionRecord> txns) async {
    final list = txns.map((t) => t.toJson()).toList();
    await saveJsonList(_dcTransactionsKey, list);
    await setLastSyncTime('dc_transactions');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${txns.length} DC transactions to local storage.');
  }

  @override
  Future<List<DCTransactionRecord>?> getCachedDcTransactions() async {
    final rawList = await getJsonList(_dcTransactionsKey);
    if (rawList == null || rawList.isEmpty) return null;

    final txns = <DCTransactionRecord>[];
    for (final map in rawList) {
      try {
        txns.add(DCTransactionRecord.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached DC transaction: $e');
      }
    }
    return txns.isNotEmpty ? txns : null;
  }

  // --- Orders Caching ---

  @override
  Future<void> cacheOrders(List<OrderEntity> orders, [String? scopeKey]) async {
    final list = orders.map((o) {
      if (o is OrderModel) {
        return o.toJson();
      }
      return OrderModel.fromEntity(o).toJson();
    }).toList();

    final key = scopeKey != null && scopeKey.isNotEmpty ? '${_ordersKey}_$scopeKey' : _ordersKey;
    await saveJsonList(key, list);
    await setLastSyncTime('orders_${scopeKey ?? 'global'}');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${orders.length} orders to local storage (key: $key).');
  }

  @override
  Future<List<OrderEntity>?> getCachedOrders([String? scopeKey]) async {
    final key = scopeKey != null && scopeKey.isNotEmpty ? '${_ordersKey}_$scopeKey' : _ordersKey;
    final rawList = await getJsonList(key);
    if (rawList == null || rawList.isEmpty) return null;

    final orders = <OrderEntity>[];
    for (final map in rawList) {
      try {
        orders.add(OrderModel.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached order: $e');
      }
    }
    return orders.isNotEmpty ? orders : null;
  }

  // --- Warehouse Batches Caching ---

  @override
  Future<void> cacheWarehouseBatches(List<DCWarehouseBatch> batches) async {
    final list = batches.map((b) => b.toJson()).toList();
    await saveJsonList(_batchesKey, list);
    await setLastSyncTime('warehouse_batches');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${batches.length} warehouse batches to local storage.');
  }

  @override
  Future<List<DCWarehouseBatch>?> getCachedWarehouseBatches() async {
    final rawList = await getJsonList(_batchesKey);
    if (rawList == null || rawList.isEmpty) return null;

    final batches = <DCWarehouseBatch>[];
    for (final map in rawList) {
      try {
        batches.add(DCWarehouseBatch.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached batch: $e');
      }
    }
    return batches.isNotEmpty ? batches : null;
  }

  // --- Return Items Caching ---

  @override
  Future<void> cacheReturnItems(List<DCReturnItem> returns) async {
    final list = returns.map((r) => r.toJson()).toList();
    await saveJsonList(_returnsKey, list);
    await setLastSyncTime('return_items');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${returns.length} return items to local storage.');
  }

  @override
  Future<List<DCReturnItem>?> getCachedReturnItems() async {
    final rawList = await getJsonList(_returnsKey);
    if (rawList == null || rawList.isEmpty) return null;

    final returns = <DCReturnItem>[];
    for (final map in rawList) {
      try {
        returns.add(DCReturnItem.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached return item: $e');
      }
    }
    return returns.isNotEmpty ? returns : null;
  }

  // --- Remittances Caching ---

  @override
  Future<void> cacheRemittances(List<RemittanceEntity> remittances) async {
    final list = remittances.map((r) {
      if (r is RemittanceModel) return r.toJson();
      return RemittanceModel.fromEntity(r).toJson();
    }).toList();
    await saveJsonList(_remittancesKey, list);
    await setLastSyncTime('remittances');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${remittances.length} remittances to local storage.');
  }

  @override
  Future<List<RemittanceEntity>?> getCachedRemittances() async {
    final rawList = await getJsonList(_remittancesKey);
    if (rawList == null || rawList.isEmpty) return null;

    final remittances = <RemittanceEntity>[];
    for (final map in rawList) {
      try {
        remittances.add(RemittanceModel.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached remittance: $e');
      }
    }
    return remittances.isNotEmpty ? remittances : null;
  }

  // --- Transactions Caching ---

  @override
  Future<void> cacheTransactions(List<TransactionItem> transactions) async {
    final list = transactions.map((t) => t.toJson()).toList();
    await saveJsonList(_transactionsKey, list);
    await setLastSyncTime('transactions');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${transactions.length} transactions to local storage.');
  }

  @override
  Future<List<TransactionItem>?> getCachedTransactions() async {
    final rawList = await getJsonList(_transactionsKey);
    if (rawList == null || rawList.isEmpty) return null;

    final txns = <TransactionItem>[];
    for (final map in rawList) {
      try {
        txns.add(TransactionItem.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached transaction: $e');
      }
    }
    return txns.isNotEmpty ? txns : null;
  }

  // --- Stock Items Caching ---

  @override
  Future<void> cacheStockItems(List<StockItemEntity> items) async {
    final list = items.map((s) {
      if (s is StockItemModel) return s.toJson();
      return StockItemModel(
        id: s.id,
        sku: s.sku,
        name: s.name,
        description: s.description,
        price: s.price,
        ownerName: s.ownerName,
        inventoryType: s.inventoryType,
        totalInCustody: s.totalInCustody,
        reservedCount: s.reservedCount,
        assignedCount: s.assignedCount,
        deliveredCount: s.deliveredCount,
        availableCount: s.availableCount,
        returnedCount: s.returnedCount,
        awaitingReturnCount: s.awaitingReturnCount,
        lowStockThreshold: s.lowStockThreshold,
        reorderLevel: s.reorderLevel,
        category: s.category,
        imageAsset: s.imageAsset,
        batchNumber: s.batchNumber,
        lastAuditDate: s.lastAuditDate,
      ).toJson();
    }).toList();
    await saveJsonList(_stockKey, list);
    await setLastSyncTime('stock_items');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${items.length} stock items to local storage.');
  }

  @override
  Future<List<StockItemEntity>?> getCachedStockItems() async {
    final rawList = await getJsonList(_stockKey);
    if (rawList == null || rawList.isEmpty) return null;

    final items = <StockItemEntity>[];
    for (final map in rawList) {
      try {
        items.add(StockItemModel.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached stock item: $e');
      }
    }
    return items.isNotEmpty ? items : null;
  }

  // --- Rider Stock Allocations Caching ---

  @override
  Future<void> cacheRiderStockAllocations(List<RiderStockAllocation> allocations) async {
    final list = allocations.map((a) => a.toJson()).toList();
    await saveJsonList(_riderAllocationsKey, list);
    await setLastSyncTime('rider_stock_allocations');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${allocations.length} rider stock allocations to local storage.');
  }

  @override
  Future<List<RiderStockAllocation>?> getCachedRiderStockAllocations() async {
    final rawList = await getJsonList(_riderAllocationsKey);
    if (rawList == null || rawList.isEmpty) return null;

    final allocations = <RiderStockAllocation>[];
    for (final map in rawList) {
      try {
        allocations.add(RiderStockAllocation.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached rider stock allocation: $e');
      }
    }
    return allocations.isNotEmpty ? allocations : null;
  }

  @override
  Future<void> cacheNotifications(String agentId, List<AppNotificationEntity> notifications) async {
    final list = notifications.map((n) => n.toJson()).toList();
    final key = '$_notificationsPrefix$agentId';
    await saveJsonList(key, list);
    await setLastSyncTime('notifications_$agentId');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${notifications.length} notifications for agent ($agentId).');
  }

  @override
  Future<List<AppNotificationEntity>?> getCachedNotifications(String agentId) async {
    final key = '$_notificationsPrefix$agentId';
    final rawList = await getJsonList(key);
    if (rawList == null || rawList.isEmpty) return null;

    final items = <AppNotificationEntity>[];
    for (final map in rawList) {
      try {
        items.add(AppNotificationEntity.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached notification: $e');
      }
    }
    return items.isNotEmpty ? items : null;
  }

  // --- Product & Package Catalog ---

  @override
  Future<void> cacheProductCatalog(List<CatalogProduct> products) async {
    final list = products.map((p) => p.toJson()).toList();
    await saveJsonList(_productCatalogKey, list);
  }

  @override
  Future<List<CatalogProduct>?> getCachedProductCatalog() async {
    final rawList = await getJsonList(_productCatalogKey);
    if (rawList == null) return null;
    final items = <CatalogProduct>[];
    for (final map in rawList) {
      try {
        items.add(CatalogProduct.fromJson(map));
      } catch (e) {
        debugPrint('[LOCAL_STORAGE] ⚠️ Error parsing cached product catalog: $e');
      }
    }
    return items.isNotEmpty ? items : null;
  }

  // --- User Profile ---

  @override
  Future<void> cacheUserProfile(Map<String, dynamic> userJson) async {
    await saveJsonObject(_userProfileKey, userJson);
    debugPrint('[LOCAL_STORAGE] 💾 Cached user profile to local storage.');
  }

  @override
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final json = await getJsonObject(_userProfileKey);
    if (json != null) {
      debugPrint('[LOCAL_STORAGE] 📦 Restored user profile from local storage.');
    }
    return json;
  }

  @override
  Future<void> clearUserProfile() async {
    await remove(_userProfileKey);
    debugPrint('[LOCAL_STORAGE] 🗑️ Cleared cached user profile from local storage.');
  }

  // --- Sync Metadata ---

  @override
  Future<void> setLastSyncTime(String moduleKey) async {
    await saveString('$_syncTimePrefix$moduleKey', DateTime.now().toIso8601String());
  }

  @override
  Future<DateTime?> getLastSyncTime(String moduleKey) async {
    final iso = await getString('$_syncTimePrefix$moduleKey');
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageServiceImpl();
});
