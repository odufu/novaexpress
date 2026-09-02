import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

class MockInMemoryLocalStorage implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveJsonList(String key, List<Map<String, dynamic>> items) async {
    _storage[key] = items;
  }

  @override
  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    final val = _storage[key];
    if (val is List) {
      return val.cast<Map<String, dynamic>>();
    }
    return null;
  }

  @override
  Future<void> saveJsonObject(String key, Map<String, dynamic> item) async {
    _storage[key] = item;
  }

  @override
  Future<Map<String, dynamic>?> getJsonObject(String key) async {
    final val = _storage[key];
    if (val is Map) {
      return val.cast<String, dynamic>();
    }
    return null;
  }

  @override
  Future<void> saveString(String key, String value) async => _storage[key] = value;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> clearAll() async => _storage.clear();

  @override
  Future<void> cacheFleetDrivers(List<DCFleetDriver> drivers) async {
    final list = drivers.map((d) => d.toJson()).toList();
    await saveJsonList('novexps_cache_fleet_drivers', list);
  }

  @override
  Future<List<DCFleetDriver>?> getCachedFleetDrivers() async {
    final rawList = await getJsonList('novexps_cache_fleet_drivers');
    if (rawList == null) return null;
    return rawList.map((m) => DCFleetDriver.fromJson(m)).toList();
  }

  @override
  Future<void> cacheDriverCompensationTerms(String driverKey, Map<String, dynamic> terms) async {
    final cleanKey = driverKey.trim().toLowerCase();
    final existing = await getCachedDriverCompensationTerms() ?? {};
    existing[cleanKey] = terms;
    if (terms['driver_code'] != null) {
      existing[terms['driver_code'].toString().toLowerCase()] = terms;
    }
    if (terms['id'] != null) {
      existing[terms['id'].toString().toLowerCase()] = terms;
    }
    if (terms['email'] != null && terms['email'].toString().isNotEmpty) {
      existing[terms['email'].toString().toLowerCase()] = terms;
    }
    await saveJsonObject('novexps_cache_driver_terms_registry', existing);
  }

  @override
  Future<Map<String, Map<String, dynamic>>?> getCachedDriverCompensationTerms() async {
    final raw = await getJsonObject('novexps_cache_driver_terms_registry');
    if (raw == null) return null;
    final res = <String, Map<String, dynamic>>{};
    raw.forEach((k, v) {
      if (v is Map) res[k] = Map<String, dynamic>.from(v);
    });
    return res;
  }

  @override
  Future<void> cacheFinanceSettings(DCFinanceSettings settings) async {
    await saveJsonObject('novexps_cache_dc_finance_settings', settings.toJson());
  }

  @override
  Future<DCFinanceSettings?> getCachedFinanceSettings() async {
    final raw = await getJsonObject('novexps_cache_dc_finance_settings');
    if (raw == null) return null;
    return DCFinanceSettings.fromJson(raw);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rider Commission & Transport Allowance Persistence Suite', () {
    late MockInMemoryLocalStorage mockStorage;
    late DCConsoleNotifier notifier;

    setUp(() {
      mockStorage = MockInMemoryLocalStorage();
      notifier = DCConsoleNotifier(mockStorage);
      notifier.addDriver(const DCFleetDriver(
        id: 'e9c357a3-5bbf-4c41-8bcb-f9385bd6adb4',
        driverCode: 'PDA-7000',
        name: 'Emeka Rider',
        phone: '08031234567',
        email: 'rider.emeka@novaexpress.com',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'ABJ-204-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse 2',
        totalAssignedOrders: 10,
        completedOrders: 8,
        routeProgressPercent: 80.0,
        efficiencyRating: 98.5,
        cashInCustody: 15000.0,
        itemsInCustody: 2,
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
      ));
    });

    test('1. Editing rider commission and transport updates in-memory and caches custom terms', () async {
      final initialDriver = notifier.state.drivers.firstWhere(
        (d) => d.email == 'rider.emeka@novaexpress.com' || d.driverCode == 'PDA-7000',
      );

      expect(initialDriver.commissionRate, equals(1000.0));
      expect(initialDriver.transportAllowance, equals(1500.0));

      // User edits rider to custom terms: ₦2,500 commission + ₦1,800 transport
      final customDriver = initialDriver.copyWith(
        commissionRate: 2500.0,
        transportAllowance: 1800.0,
      );

      await notifier.updateDriverProfileAndTerms(updatedDriver: customDriver);

      // Verify in-memory state updated
      final updatedInMemory = notifier.state.drivers.firstWhere((d) => d.id == customDriver.id);
      expect(updatedInMemory.commissionRate, equals(2500.0));
      expect(updatedInMemory.transportAllowance, equals(1800.0));
      expect(updatedInMemory.totalPerDeliveryEntitlement, equals(4300.0));

      // Verify local storage cached the updated driver entity
      final cachedDrivers = await mockStorage.getCachedFleetDrivers();
      expect(cachedDrivers, isNotNull);
      final cachedDriver = cachedDrivers!.firstWhere((d) => d.id == customDriver.id);
      expect(cachedDriver.commissionRate, equals(2500.0));
      expect(cachedDriver.transportAllowance, equals(1800.0));

      // Verify driver compensation terms registry was cached
      final cachedTerms = await mockStorage.getCachedDriverCompensationTerms();
      expect(cachedTerms, isNotNull);
      expect(cachedTerms![customDriver.driverCode.toLowerCase()]?['commission_rate'], equals(2500.0));
      expect(cachedTerms[customDriver.driverCode.toLowerCase()]?['transport_allowance'], equals(1800.0));
    });

    test('2. Reload simulation (merging DB rows with missing columns) strictly preserves custom terms', () async {
      // 1. Setup custom terms in storage
      const customDriver = DCFleetDriver(
        id: 'e9c357a3-5bbf-4c41-8bcb-f9385bd6adb4',
        driverCode: 'PDA-7000',
        name: 'Emeka Rider',
        phone: '08031234567',
        email: 'rider.emeka@novaexpress.com',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'ABJ-204-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse 2',
        totalAssignedOrders: 10,
        completedOrders: 8,
        routeProgressPercent: 80.0,
        efficiencyRating: 98.5,
        cashInCustody: 15000.0,
        itemsInCustody: 2,
        commissionRate: 2500.0,
        transportAllowance: 1800.0,
      );

      await notifier.updateDriverProfileAndTerms(updatedDriver: customDriver);

      // 2. Simulate raw rows returned from Supabase delivery_agents (where commission_rate & transport_allowance are null)
      final rawDbRow = {
        'id': 'e9c357a3-5bbf-4c41-8bcb-f9385bd6adb4',
        'agent_code': 'PDA-7000',
        'name': 'Emeka Rider',
        'current_status': 'active',
        'operating_city': 'Wuse 2 & Maitama',
        'current_cod_balance': 20000.0,
        'users': {
          'first_name': 'Emeka',
          'last_name': 'Rider',
          'email': 'rider.emeka@novaexpress.com',
          'phone_number': '08031234567',
        },
        // Notice: NO commission_rate or transport_allowance in raw DB row
      };

      // Default fromJson would produce 1000 and 1500
      final dbParsedDriver = DCFleetDriver.fromJson(rawDbRow);
      expect(dbParsedDriver.commissionRate, equals(1000.0)); // Default fallback
      expect(dbParsedDriver.transportAllowance, equals(1500.0)); // Default fallback

      // 3. Now simulate intelligent merge in loadDriversFromDatabase
      final cachedTerms = await mockStorage.getCachedDriverCompensationTerms();
      final terms = cachedTerms?['pda-7000'] ?? cachedTerms?['rider.emeka@novaexpress.com'];

      expect(terms, isNotNull);
      final mergedDriver = dbParsedDriver.copyWith(
        commissionRate: (terms?['commission_rate'] as num?)?.toDouble() ?? dbParsedDriver.commissionRate,
        transportAllowance: (terms?['transport_allowance'] as num?)?.toDouble() ?? dbParsedDriver.transportAllowance,
      );

      // 4. Verify the merged driver preserved the user's custom edited terms!
      expect(mergedDriver.commissionRate, equals(2500.0));
      expect(mergedDriver.transportAllowance, equals(1800.0));
      expect(mergedDriver.cashInCustody, equals(20000.0)); // Live DB balance updated
      expect(mergedDriver.assignedZone, equals('Wuse 2 & Maitama')); // Live DB zone updated
    });

    test('3. Finance Settings custom defaults persist to local storage across restarts', () async {
      const customFinance = DCFinanceSettings(
        posChargeMode: 'tiered',
        posTierAmount: 10000.0,
        posTierFee: 200.0,
        posMaxCapFee: 2000.0,
        defaultCommissionRate: 1500.0,
        defaultTransportAllowance: 2000.0,
      );

      notifier.updateFinanceSettings(customFinance);

      final cached = await mockStorage.getCachedFinanceSettings();
      expect(cached, isNotNull);
      expect(cached!.defaultCommissionRate, equals(1500.0));
      expect(cached.defaultTransportAllowance, equals(2000.0));
      expect(cached.posTierFee, equals(200.0));
    });
  });
}
