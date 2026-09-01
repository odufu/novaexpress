import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/location_lookup_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationLookupService Unit Tests', () {
    test('getAllStates returns all Nigerian states including FCT', () {
      final states = LocationLookupService.getAllStates();
      expect(states.isNotEmpty, isTrue);
      expect(states.contains('Lagos'), isTrue);
      expect(states.contains('Federal Capital Territory'), isTrue);
      expect(states.contains('Rivers'), isTrue);
      expect(states.contains('Kano'), isTrue);
    });

    test('getLgasForState returns valid LGAs for Lagos and FCT', () {
      final lagosLgas = LocationLookupService.getLgasForState('Lagos');
      expect(lagosLgas.contains('Ikeja'), isTrue);
      expect(lagosLgas.contains('Alimosho'), isTrue);
      expect(lagosLgas.contains('Eti Osa'), isTrue);

      final fctLgas = LocationLookupService.getLgasForState('Federal Capital Territory');
      expect(fctLgas.contains('Abuja Municipal (AMAC)'), isTrue);
      expect(fctLgas.contains('Bwari'), isTrue);
    });

    test('normalizeStateName normalizes aliases and common variations', () {
      expect(LocationLookupService.normalizeStateName('Abuja FCT'), equals('Federal Capital Territory'));
      expect(LocationLookupService.normalizeStateName('FCT'), equals('Federal Capital Territory'));
      expect(LocationLookupService.normalizeStateName('Lagos State'), equals('Lagos'));
      expect(LocationLookupService.normalizeStateName('Rivers State'), equals('Rivers'));
    });
  });

  group('DistributionCenter and DCFleetDriver LGA Coverage Tests', () {
    final lagosDc = DistributionCenter(
      id: 'dc-los-01',
      name: 'Ikeja Commercial Hub',
      code: 'DC-LOS-01',
      state: 'Lagos',
      city: 'Ikeja',
      address: '12 Mobolaji Bank Anthony Way',
      operatingZones: const ['Ikeja', 'Alimosho', 'Oshodi-Isolo', 'Kosofe'],
    );

    final fctDc = DistributionCenter(
      id: 'dc-abj-01',
      name: 'Wuse Central Distribution Hub',
      code: 'DC-ABJ-01',
      state: 'Federal Capital Territory',
      city: 'Abuja',
      address: 'Plot 42 Wuse II',
      operatingZones: const ['Abuja Municipal (AMAC)', 'Bwari', 'Gwagwalada'],
    );

    test('DistributionCenter coversLocation accurately matches state and LGA', () {
      expect(lagosDc.coversLocation(stateName: 'Lagos', lgaName: 'Ikeja'), isTrue);
      expect(lagosDc.coversLocation(stateName: 'Lagos', lgaName: 'Alimosho'), isTrue);
      expect(lagosDc.coversLocation(stateName: 'Lagos', lgaName: 'Badagry'), isFalse);
      expect(lagosDc.coversLocation(stateName: 'Federal Capital Territory', lgaName: 'Bwari'), isFalse);

      expect(fctDc.coversLocation(stateName: 'Federal Capital Territory', lgaName: 'Bwari'), isTrue);
      expect(fctDc.coversLocation(stateName: 'Abuja FCT', lgaName: 'Abuja Municipal (AMAC)'), isTrue);
    });

    test('DCFleetDriver coversLga strictly evaluates covered LGAs under DC', () {
      final ikejaRider = DCFleetDriver(
        id: 'drv-001',
        driverCode: 'PDA-101',
        name: 'Tunde Ikeja',
        phone: '08031112233',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'KJA-123-AA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Ikeja',
        distributionCenterId: lagosDc.id,
        coveredLgas: const ['Ikeja', 'Oshodi-Isolo'],
        totalAssignedOrders: 2,
        completedOrders: 1,
        routeProgressPercent: 50.0,
        efficiencyRating: 98.0,
        cashInCustody: 20000.0,
        itemsInCustody: 5,
      );

      expect(ikejaRider.coversLga('Ikeja'), isTrue);
      expect(ikejaRider.coversLga('Oshodi-Isolo'), isTrue);
      expect(ikejaRider.coversLga('Alimosho'), isFalse);
      expect(ikejaRider.coversLga('Bwari'), isFalse);
    });
  });

  group('OrderRoutingService Stock-Aware Multi-Tier Dispatching Tests', () {
    final lagosDc = DistributionCenter(
      id: 'dc-los-01',
      name: 'Ikeja Central DC',
      code: 'DC-LOS-01',
      state: 'Lagos',
      city: 'Ikeja',
      address: 'Ikeja Warehouse',
      operatingZones: const ['Ikeja', 'Alimosho', 'Surulere'],
    );

    final fctDc = DistributionCenter(
      id: 'dc-abj-01',
      name: 'Abuja Regional Hub',
      code: 'DC-ABJ-01',
      state: 'Federal Capital Territory',
      city: 'Abuja',
      address: 'Wuse Warehouse',
      operatingZones: const ['Abuja Municipal (AMAC)', 'Bwari'],
    );

    final riderWithStockInIkeja = DCFleetDriver(
      id: 'drv-ikeja-stock',
      driverCode: 'RDR-IKJ-1',
      name: 'Emeka Rider',
      phone: '08039998888',
      avatarUrl: '',
      vehicleModel: 'Honda Ace',
      vehiclePlate: 'IKJ-444-BB',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Ikeja',
      distributionCenterId: lagosDc.id,
      coveredLgas: const ['Ikeja'],
      totalAssignedOrders: 1,
      completedOrders: 0,
      routeProgressPercent: 0.0,
      efficiencyRating: 99.0,
      cashInCustody: 0.0,
      itemsInCustody: 10,
    );

    final riderZeroStockInIkeja = DCFleetDriver(
      id: 'drv-ikeja-nostock',
      driverCode: 'RDR-IKJ-2',
      name: 'Musa Rider',
      phone: '08037776666',
      avatarUrl: '',
      vehicleModel: 'Bajaj 100',
      vehiclePlate: 'IKJ-555-CC',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Ikeja',
      distributionCenterId: lagosDc.id,
      coveredLgas: const ['Ikeja'],
      totalAssignedOrders: 0,
      completedOrders: 0,
      routeProgressPercent: 0.0,
      efficiencyRating: 95.0,
      cashInCustody: 0.0,
      itemsInCustody: 0,
    );

    final List<RiderStockAllocation> stockAllocations = [
      RiderStockAllocation(
        id: 'alloc-1',
        riderId: riderWithStockInIkeja.id,
        riderName: riderWithStockInIkeja.name,
        riderCode: riderWithStockInIkeja.driverCode,
        productId: 'prod-tea-001',
        sku: 'GT-TEA-001',
        productName: 'Grazer Tea (Herbal)',
        allocatedUnits: 10,
        deliveredUnits: 2,
        inCustodyUnits: 8,
        returnedUnits: 0,
        unitPrice: 20000.0,
        allocatedAt: DateTime.now(),
      ),
      // Musa has zero allocations or 0 remaining stock
    ];

    test('Rule 1: Auto-assigns to qualified rider with matching LGA and sufficient stock', () {
      final order = OrderEntity(
        id: 'ord-101',
        orderNumber: 'TRK-101',
        customerName: 'Adebayo Client',
        customerPhone: '08031234567',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Allen Avenue, Ikeja',
        lga: 'Ikeja',
        productName: 'Grazer Tea (Herbal)',
        productSku: 'GT-TEA-001',
        quantity: 2,
        paidQuantity: 2,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        status: 'unassigned',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: order,
        distributionCenters: [lagosDc, fctDc],
        drivers: [riderWithStockInIkeja, riderZeroStockInIkeja],
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.assignedToRider));
      expect(result.isAssignedToRider, isTrue);
      expect(result.driver?.id, equals(riderWithStockInIkeja.id));
      expect(result.distributionCenter?.id, equals(lagosDc.id));
      expect(result.routedOrder.status, equals('assigned'));
      expect(result.routedOrder.deliveryAgentId, equals(riderWithStockInIkeja.id));
    });

    test('Rule 2 (Strict): Does NOT assign to rider with zero or low stock; routes to DC pending stock', () {
      // Order quantity is 15, but Emeka only has 8 in custody
      final largeOrder = OrderEntity(
        id: 'ord-102',
        orderNumber: 'TRK-102',
        customerName: 'Big Buyer',
        customerPhone: '08039999999',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Obafemi Awolowo Way, Ikeja',
        lga: 'Ikeja',
        productName: 'Grazer Tea (Herbal)',
        productSku: 'GT-TEA-001',
        quantity: 15, // Higher than Emeka's 8 units
        paidQuantity: 15,
        basePrice: 150000.0,
        upsellAmount: 0.0,
        totalAmount: 150000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        status: 'unassigned',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: largeOrder,
        distributionCenters: [lagosDc, fctDc],
        drivers: [riderWithStockInIkeja, riderZeroStockInIkeja],
        stockAllocations: stockAllocations,
      );

      // Must NOT route to Emeka or Musa since both lack 15 units!
      expect(result.status, equals(RoutingStatus.routedToDcOnly));
      expect(result.isAssignedToRider, isFalse);
      expect(result.distributionCenter?.id, equals(lagosDc.id));
      expect(result.routedOrder.deliveryAgentId, isNull);
      expect(result.routedOrder.distributionCenterId, equals(lagosDc.id));
    });

    test('Rule 3: If no rider covers the order LGA, routes to the parent DC covering that State/LGA', () {
      final surulereOrder = OrderEntity(
        id: 'ord-103',
        orderNumber: 'TRK-103',
        customerName: 'Surulere Customer',
        customerPhone: '08038887777',
        deliveryState: 'Lagos',
        deliveryCity: 'Surulere',
        deliveryAddress: 'Adeniran Ogunsanya, Surulere',
        lga: 'Surulere', // DC covers Surulere, but no riders cover Surulere
        productName: 'Grazer Tea (Herbal)',
        productSku: 'GT-TEA-001',
        quantity: 1,
        paidQuantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        status: 'unassigned',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: surulereOrder,
        distributionCenters: [lagosDc, fctDc],
        drivers: [riderWithStockInIkeja, riderZeroStockInIkeja],
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.routedToDcOnly));
      expect(result.isAssignedToRider, isFalse);
      expect(result.distributionCenter?.id, equals(lagosDc.id));
      expect(result.routedOrder.distributionCenterId, equals(lagosDc.id));
      expect(result.routedOrder.deliveryAgentId, isNull);
    });

    test('Rule 4: Validates manual assignment safety against vehicle custody stock', () {
      final safeOrder = OrderEntity(
        id: 'ord-104',
        orderNumber: 'TRK-104',
        customerName: 'Manual Check',
        customerPhone: '08031110000',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Ikeja',
        productName: 'Grazer Tea (Herbal)',
        quantity: 3,
        paidQuantity: 3,
        basePrice: 30000.0,
        upsellAmount: 0.0,
        totalAmount: 30000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        status: 'unassigned',
        createdAt: DateTime.now(),
      );

      final isSafeForEmeka = OrderRoutingService.validateManualAssignmentStock(
        order: safeOrder,
        driver: riderWithStockInIkeja,
        stockAllocations: stockAllocations,
      );
      expect(isSafeForEmeka, isTrue);

      final isSafeForMusa = OrderRoutingService.validateManualAssignmentStock(
        order: safeOrder,
        driver: riderZeroStockInIkeja,
        stockAllocations: stockAllocations,
      );
      expect(isSafeForMusa, isFalse);
    });
  });
}
