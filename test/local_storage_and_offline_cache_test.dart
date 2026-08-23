import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Industrial Local Data Storage & Dynamic Remittance Verification Suite', () {
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

    test('3. Warehouse Batches & Return Items: Caches and restores DC inventory structures', () async {
      final sampleBatch = DCWarehouseBatch(
        id: 'batch-001',
        batchCode: 'LOT-RESP-99',
        productName: 'Respira Detox Tea',
        sku: 'SKU-RESP-01',
        clientName: 'NovaCare Labs',
        waybillNumber: 'WB-99482',
        initialQuantity: 500,
        currentQuantity: 420,
        allocatedQuantity: 60,
        binLocation: 'BIN-WUSE-A3',
        manufactureDate: DateTime.now().subtract(const Duration(days: 30)),
        expiryDate: DateTime.now().add(const Duration(days: 335)),
      );

      final sampleReturn = DCReturnItem(
        id: 'ret-001',
        returnTicketNumber: 'RET-8921',
        orderNumber: 'NX-8921',
        customerName: 'Chidinma Adeyemi',
        customerPhone: '08031234567',
        productName: 'Respira Detox Tea',
        quantity: 1,
        amount: 18000.0,
        riderName: 'Emeka Rider',
        returnReason: 'Customer rescheduled travel',
        qcStatus: 'grade_a_restocked',
        targetBin: 'BIN-WUSE-A3',
        returnedAt: DateTime.now(),
      );

      await storageService.cacheWarehouseBatches([sampleBatch]);
      await storageService.cacheReturnItems([sampleReturn]);

      final cachedBatches = await storageService.getCachedWarehouseBatches();
      final cachedReturns = await storageService.getCachedReturnItems();

      expect(cachedBatches, isNotNull);
      expect(cachedBatches!.first.batchCode, equals('LOT-RESP-99'));
      expect(cachedBatches.first.availableQuantity, equals(360));

      expect(cachedReturns, isNotNull);
      expect(cachedReturns!.first.returnTicketNumber, equals('RET-8921'));
      expect(cachedReturns.first.qcStatus, equals('grade_a_restocked'));
    });

    test('4. Dynamic Rider Remittance & Earnings: Increases cash in custody and calculates earnings with base commission + transport + failed allowance', () {
      const pdaUser = UserEntity(
        id: 'usr-pda-01',
        email: 'emeka@novaexpress.ng',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08012345678',
        role: 'delivery_agent',
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
        failedDeliveryAllowance: 500.0,
      );

      // Scenario 1: Initial state - 1 COD delivered order (₦30,000)
      final order1 = OrderModel(
        id: 'ord-1',
        orderNumber: 'NX-001',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryState: 'Abuja',
        deliveryCity: 'Wuse',
        deliveryAddress: 'Wuse 2',
        productName: 'Respira Detox Tea',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 30000.0,
        upsellAmount: 0.0,
        totalAmount: 30000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final initialSummary = FinancialSummary.calculate(
        orders: [order1],
        remittances: [],
        user: pdaUser,
      );

      // Total collected = 30,000
      expect(initialSummary.cashCollectedAllTime, equals(30000.0));
      // Rider earning = 1,000 (commission) + 1,500 (transport) = 2,500
      expect(initialSummary.totalEarningRetained, equals(2500.0));
      // Net cash to remit to DC = 30,000 - 2,500 = 27,500
      expect(initialSummary.pendingRemittanceToDC, equals(27500.0));

      // Scenario 2: Rider delivers 2nd COD order (₦20,000) and 1 Failed delivery
      final order2 = OrderModel(
        id: 'ord-2',
        orderNumber: 'NX-002',
        customerName: 'Customer B',
        customerPhone: '08022222222',
        deliveryState: 'Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: 'Maitama',
        productName: 'Respira Detox Tea',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'paid',
        createdAt: DateTime.now(),
      );

      final orderFailed = OrderModel(
        id: 'ord-3',
        orderNumber: 'NX-003',
        customerName: 'Customer C',
        customerPhone: '08033333333',
        deliveryState: 'Abuja',
        deliveryCity: 'Gwarinpa',
        deliveryAddress: 'Gwarinpa',
        productName: 'Respira Detox Tea',
        status: 'failed',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'failed',
        createdAt: DateTime.now(),
      );

      final updatedSummary = FinancialSummary.calculate(
        orders: [order1, order2, orderFailed],
        remittances: [],
        user: pdaUser,
      );

      // Total COD collected = 30,000 + 20,000 = 50,000
      expect(updatedSummary.cashCollectedAllTime, equals(50000.0));
      // Total commission = 2 * 1,000 = 2,000
      expect(updatedSummary.totalCommissionRetained, equals(2000.0));
      // Total transport = 2 * 1,500 = 3,000
      expect(updatedSummary.totalTransportRetained, equals(3000.0));
      // Total earnings retained = 2,000 + 3,000 + 500 (failed allowance) = 5,500
      expect(updatedSummary.totalEarningRetained, equals(5500.0));
      // Net cash to remit to DC = 50,000 - 5,500 = 44,500 (INCREASED PROPERLY!)
      expect(updatedSummary.pendingRemittanceToDC, equals(44500.0));
      // Total month earnings = 2 * 2,500 + 500 = 5,500
      expect(updatedSummary.totalMonthEarnings, equals(5500.0));

      // Scenario 3: Rider submits remittance of ₦40,000
      final sampleRemittance = RemittanceEntity(
        id: 'rem-01',
        referenceNumber: 'REM-1001',
        amount: 40000.0,
        status: 'verified',
        createdAt: DateTime.now(),
      );

      final reconciledSummary = FinancialSummary.calculate(
        orders: [order1, order2, orderFailed],
        remittances: [sampleRemittance],
        user: pdaUser,
      );

      // Pending remittance after ₦40,000 verified remittance = 44,500 - 40,000 = 4,500
      expect(reconciledSummary.pendingRemittanceToDC, equals(4500.0));
      expect(reconciledSummary.totalVerifiedRemitted, equals(40000.0));
    });
  });
}
