import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Industrial Local Data Storage & Caching Verification Suite', () {
    late LocalStorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = LocalStorageServiceImpl();
    });

    test('1. Fleet Drivers Caching: Persists, retrieves, and preserves complete driver metadata', () async {
      final sampleDrivers = [
        const DCFleetDriver(
          id: 'b1111111-1111-4111-8111-111111111111',
          driverCode: 'PDA-7000',
          name: 'Emeka Rider',
          phone: '08012345678',
          email: 'emeka.rider@novaexpress.ng',
          avatarUrl: 'https://example.com/avatar.jpg',
          vehicleModel: 'Bajaj Boxer 100',
          vehiclePlate: 'ABJ-204-XY',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: 'Wuse 2',
          totalAssignedOrders: 6,
          completedOrders: 4,
          routeProgressPercent: 66.7,
          efficiencyRating: 98.5,
          cashInCustody: 55000.0,
          itemsInCustody: 14,
          commissionRate: 1000.0,
          transportAllowance: 1500.0,
        ),
        const DCFleetDriver(
          id: 'b2222222-2222-4222-8222-222222222222',
          driverCode: 'PDA-7588',
          name: 'Sanni Abacha',
          phone: '08098765432',
          email: 'sanni.abacha@novaexpress.ng',
          avatarUrl: 'https://example.com/avatar2.jpg',
          vehicleModel: 'TVS HLX Plus',
          vehiclePlate: 'ABJ-892-KT',
          vehicleType: 'Motorcycle',
          status: 'active',
          assignedZone: 'Maitama',
          totalAssignedOrders: 4,
          completedOrders: 3,
          routeProgressPercent: 75.0,
          efficiencyRating: 99.1,
          cashInCustody: 44000.0,
          itemsInCustody: 8,
          commissionRate: 1000.0,
          transportAllowance: 1500.0,
        ),
      ];

      // Initial get should be null
      final emptyResult = await storageService.getCachedFleetDrivers();
      expect(emptyResult, isNull);

      // Cache drivers
      await storageService.cacheFleetDrivers(sampleDrivers);

      // Retrieve cached drivers
      final cached = await storageService.getCachedFleetDrivers();
      expect(cached, isNotNull);
      expect(cached!.length, equals(2));
      expect(cached[0].driverCode, equals('PDA-7000'));
      expect(cached[0].name, equals('Emeka Rider'));
      expect(cached[0].cashInCustody, equals(55000.0));
      expect(cached[1].driverCode, equals('PDA-7588'));
      expect(cached[1].name, equals('Sanni Abacha'));

      // Check sync timestamp
      final syncTime = await storageService.getLastSyncTime('fleet_drivers');
      expect(syncTime, isNotNull);
    });

    test('2. Orders Caching: Persists and restores live manifest orders accurately', () async {
      final sampleOrders = [
        OrderModel(
          id: 'ord-101',
          orderNumber: 'NX-8921',
          customerName: 'Chidinma Adeyemi',
          customerPhone: '08031234567',
          deliveryState: 'Abuja (FCT)',
          deliveryCity: 'Wuse 2',
          deliveryAddress: 'Plot 12 Adetokunbo Ademola Crescent',
          productName: 'Respira Detox Tea',
          status: 'assigned',
          quantity: 2,
          paidQuantity: 2,
          freeQuantity: 0,
          basePrice: 18000.0,
          upsellAmount: 0.0,
          totalAmount: 36000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          latitude: 9.0765,
          longitude: 7.4832,
          locationConfidence: 'high',
          createdAt: DateTime.now(),
        ),
      ];

      await storageService.cacheOrders(sampleOrders);

      final cachedOrders = await storageService.getCachedOrders();
      expect(cachedOrders, isNotNull);
      expect(cachedOrders!.length, equals(1));
      expect(cachedOrders[0].orderNumber, equals('NX-8921'));
      expect(cachedOrders[0].customerName, equals('Chidinma Adeyemi'));
      expect(cachedOrders[0].totalAmount, equals(36000.0));
      expect(cachedOrders[0].latitude, equals(9.0765));
    });

    test('3. DCConsoleNotifier: Hydrates instantly from local cache without hardcoded lists', () async {
      final testDriver = const DCFleetDriver(
        id: 'drv-live-01',
        driverCode: 'PDA-9999',
        name: 'Musa Bello',
        phone: '08055554444',
        email: 'musa.bello@novaexpress.ng',
        avatarUrl: 'https://example.com/avatar.jpg',
        vehicleModel: 'Honda Ace 125',
        vehiclePlate: 'ABJ-111-AA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Garki',
        totalAssignedOrders: 10,
        completedOrders: 8,
        routeProgressPercent: 80.0,
        efficiencyRating: 99.0,
        cashInCustody: 75000.0,
        itemsInCustody: 5,
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
      );

      // Pre-seed local storage
      await storageService.cacheFleetDrivers([testDriver]);

      // Initialize DCConsoleNotifier with storage service
      final notifier = DCConsoleNotifier(storageService);

      // Allow microtasks to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.drivers.isNotEmpty, isTrue);
      expect(notifier.state.drivers.any((d) => d.driverCode == 'PDA-9999'), isTrue);
      expect(notifier.state.drivers.first.name, equals('Musa Bello'));
    });
  });
}
