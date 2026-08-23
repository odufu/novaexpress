import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dc_console/domain/entities/dc_fleet_driver.dart';
import '../../features/orders/data/models/order_model.dart';
import '../../features/orders/domain/entities/order.dart';

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

  Future<void> cacheOrders(List<OrderEntity> orders);
  Future<List<OrderEntity>?> getCachedOrders();

  Future<void> setLastSyncTime(String moduleKey);
  Future<DateTime?> getLastSyncTime(String moduleKey);
}

class LocalStorageServiceImpl implements LocalStorageService {
  static const String _fleetDriversKey = 'novexps_cache_fleet_drivers';
  static const String _ordersKey = 'novexps_cache_orders';
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

  // --- Orders Caching ---

  @override
  Future<void> cacheOrders(List<OrderEntity> orders) async {
    final list = orders.map((o) {
      if (o is OrderModel) {
        return o.toJson();
      }
      return OrderModel.fromEntity(o).toJson();
    }).toList();

    await saveJsonList(_ordersKey, list);
    await setLastSyncTime('orders');
    debugPrint('[LOCAL_STORAGE] 💾 Cached ${orders.length} orders to local storage.');
  }

  @override
  Future<List<OrderEntity>?> getCachedOrders() async {
    final rawList = await getJsonList(_ordersKey);
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
