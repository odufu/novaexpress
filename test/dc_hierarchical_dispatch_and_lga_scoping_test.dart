import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Hierarchical DC & Automated State/LGA Multi-Zone Dispatch Suite', () {
    // Define Grand DC and Regional Station DC in the same state (Abuja FCT)
    final grandDcAbuja = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Wuse Central Distribution Hub',
      code: 'DC-ABJ-01',
      state: 'Federal Capital Territory',
      city: 'Abuja Municipal',
      address: 'Plot 104, Aminu Kano Crescent, Wuse 2, Abuja',
      isGrandDc: true,
      isHub: true,
      isActive: true,
      operatingZones: const ['Abuja Municipal (AMAC)', 'Bwari'],
      storageCapacityUnits: 65000,
    );

    final regionalDcGwagwalada = DistributionCenter(
      id: 'dc-abj-gwagwalada-02',
      name: 'Gwagwalada Satellite Depot',
      code: 'DC-ABJ-02',
      state: 'Federal Capital Territory',
      city: 'Gwagwalada',
      address: 'Industrial Layout, Phase 1, Gwagwalada, Abuja',
      isGrandDc: false,
      isHub: false,
      isActive: true,
      operatingZones: const ['Gwagwalada', 'Kuje', 'Kwali'],
      storageCapacityUnits: 25000,
    );

    final List<DistributionCenter> allDcs = [grandDcAbuja, regionalDcGwagwalada];

    // Define 3 Riders splitting LGAs between DCs
    // Rider 1 (DC 1): Covers AMAC only
    final riderAmac = DCFleetDriver(
      id: 'rider-amac-001',
      driverCode: 'PDA-8001',
      name: 'Ibrahim Musa',
      phone: '08031112222',
      email: 'ibrahim.musa@novaexpress.ng',
      avatarUrl: '',
      vehicleModel: 'Bajaj Boxer 150',
      vehiclePlate: 'ABJ-101-XY',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Abuja Municipal (AMAC)',
      distributionCenterId: grandDcAbuja.id,
      coveredLgas: const ['Abuja Municipal (AMAC)'],
      totalAssignedOrders: 10,
      completedOrders: 8,
      routeProgressPercent: 0.8,
      efficiencyRating: 4.9,
      cashInCustody: 0,
      itemsInCustody: 20,
    );

    // Rider 2 (DC 1): Covers Bwari only
    final riderBwari = DCFleetDriver(
      id: 'rider-bwari-002',
      driverCode: 'PDA-8002',
      name: 'Emeka Nwosu',
      phone: '08032223333',
      email: 'emeka.nwosu@novaexpress.ng',
      avatarUrl: '',
      vehicleModel: 'Honda Ace 125',
      vehiclePlate: 'ABJ-202-YZ',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Bwari',
      distributionCenterId: grandDcAbuja.id,
      coveredLgas: const ['Bwari'],
      totalAssignedOrders: 8,
      completedOrders: 6,
      routeProgressPercent: 0.75,
      efficiencyRating: 4.8,
      cashInCustody: 0,
      itemsInCustody: 15,
    );

    // Rider 3 (DC 2): Covers Gwagwalada & Kuje
    final riderGwagwalada = DCFleetDriver(
      id: 'rider-gwag-003',
      driverCode: 'PDA-8003',
      name: 'Usman Garba',
      phone: '08033334444',
      email: 'usman.garba@novaexpress.ng',
      avatarUrl: '',
      vehicleModel: 'TVS HLX Plus',
      vehiclePlate: 'ABJ-303-ZA',
      vehicleType: 'Motorcycle',
      status: 'active',
      assignedZone: 'Gwagwalada',
      distributionCenterId: regionalDcGwagwalada.id,
      coveredLgas: const ['Gwagwalada', 'Kuje'],
      totalAssignedOrders: 12,
      completedOrders: 10,
      routeProgressPercent: 0.85,
      efficiencyRating: 4.95,
      cashInCustody: 0,
      itemsInCustody: 25,
    );

    final List<DCFleetDriver> allDrivers = [riderAmac, riderBwari, riderGwagwalada];

    // Stock allocations
    final now = DateTime.now();
    final List<RiderStockAllocation> stockAllocations = [
      RiderStockAllocation(
        id: 'alloc-001',
        riderId: 'rider-amac-001',
        riderName: 'Ibrahim Musa',
        riderCode: 'PDA-8001',
        productId: 'prod-001',
        productName: 'Grazer Tea',
        sku: 'GRZ-TEA',
        allocatedUnits: 20,
        inCustodyUnits: 20,
        unitPrice: 22000.0,
        allocatedAt: now,
      ),
      RiderStockAllocation(
        id: 'alloc-002',
        riderId: 'rider-bwari-002',
        riderName: 'Emeka Nwosu',
        riderCode: 'PDA-8002',
        productId: 'prod-001',
        productName: 'Grazer Tea',
        sku: 'GRZ-TEA',
        allocatedUnits: 15,
        inCustodyUnits: 15,
        unitPrice: 22000.0,
        allocatedAt: now,
      ),
      RiderStockAllocation(
        id: 'alloc-003',
        riderId: 'rider-gwag-003',
        riderName: 'Usman Garba',
        riderCode: 'PDA-8003',
        productId: 'prod-001',
        productName: 'Grazer Tea',
        sku: 'GRZ-TEA',
        allocatedUnits: 25,
        inCustodyUnits: 25,
        unitPrice: 22000.0,
        allocatedAt: now,
      ),
    ];

    test('1. Two DCs in Abuja: Order for AMAC routes strictly to Grand DC and Rider 1', () {
      final orderAmac = OrderEntity(
        id: 'ord-amac-001',
        orderNumber: 'NVX-9001',
        customerName: 'Amina Bello',
        customerPhone: '08091112233',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Abuja Municipal (AMAC)',
        lga: 'Abuja Municipal (AMAC)',
        deliveryAddress: 'Plot 45 Gana Street, Maitama, Abuja',
        productName: 'Grazer Tea',
        productSku: 'GRZ-TEA',
        status: 'pending',
        quantity: 2,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 44000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: orderAmac,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.assignedToRider));
      expect(result.distributionCenter?.id, equals(grandDcAbuja.id));
      expect(result.driver?.id, equals(riderAmac.id));
      expect(result.routedOrder.deliveryAgentId, equals(riderAmac.id));
      expect(result.routedOrder.distributionCenterId, equals(grandDcAbuja.id));
      expect(result.routedOrder.status, equals('assigned'));
    });

    test('2. Two DCs in Abuja: Order for Bwari routes strictly to Grand DC and Rider 2', () {
      final orderBwari = OrderEntity(
        id: 'ord-bwari-002',
        orderNumber: 'NVX-9002',
        customerName: 'Chinedu Eze',
        customerPhone: '08092223344',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Bwari',
        lga: 'Bwari',
        deliveryAddress: 'Law School Road, Bwari, Abuja',
        productName: 'Grazer Tea',
        productSku: 'GRZ-TEA',
        status: 'pending',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: orderBwari,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.assignedToRider));
      expect(result.distributionCenter?.id, equals(grandDcAbuja.id));
      expect(result.driver?.id, equals(riderBwari.id));
      expect(result.routedOrder.deliveryAgentId, equals(riderBwari.id));
      expect(result.routedOrder.distributionCenterId, equals(grandDcAbuja.id));
    });

    test('3. Two DCs in Abuja: Order for Gwagwalada routes strictly to Regional DC 2 and Rider 3', () {
      final orderGwag = OrderEntity(
        id: 'ord-gwag-003',
        orderNumber: 'NVX-9003',
        customerName: 'Kabiru Sanusi',
        customerPhone: '08093334455',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Gwagwalada',
        lga: 'Gwagwalada',
        deliveryAddress: 'University of Abuja Teaching Hospital Road, Gwagwalada',
        productName: 'Grazer Tea',
        productSku: 'GRZ-TEA',
        status: 'pending',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: orderGwag,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.assignedToRider));
      expect(result.distributionCenter?.id, equals(regionalDcGwagwalada.id));
      expect(result.driver?.id, equals(riderGwagwalada.id));
      expect(result.routedOrder.deliveryAgentId, equals(riderGwagwalada.id));
      expect(result.routedOrder.distributionCenterId, equals(regionalDcGwagwalada.id));
    });

    test('4. Fallback B: Order for Kwali (covered by DC 2, but no rider assigned) routes to DC 2 for manual assignment', () {
      final orderKwali = OrderEntity(
        id: 'ord-kwali-004',
        orderNumber: 'NVX-9004',
        customerName: 'Fatima Aliyu',
        customerPhone: '08094445566',
        deliveryState: 'Federal Capital Territory',
        deliveryCity: 'Kwali',
        lga: 'Kwali',
        deliveryAddress: 'Abaji-Kwali Expressway, Kwali Central',
        productName: 'Grazer Tea',
        productSku: 'GRZ-TEA',
        status: 'pending',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: orderKwali,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.routedToDcOnly));
      expect(result.distributionCenter?.id, equals(regionalDcGwagwalada.id));
      expect(result.driver, isNull);
      expect(result.routedOrder.deliveryAgentId, isNull);
      expect(result.routedOrder.distributionCenterId, equals(regionalDcGwagwalada.id));
      expect(result.routedOrder.status, equals('pending_dispatch'));
      expect(result.dispatchDiagnosis, contains('Awaiting manual rider assignment for LGA: "Kwali"'));
    });

    test('5. Fallback A: Order for Sokoto/Wamakko (no DC in state) escalates to Grand DC HQ for manual triage', () {
      final orderSokoto = OrderEntity(
        id: 'ord-sok-005',
        orderNumber: 'NVX-9005',
        customerName: 'Abdullahi Balarabe',
        customerPhone: '08095556677',
        deliveryState: 'Sokoto State',
        deliveryCity: 'Wamakko',
        lga: 'Wamakko',
        deliveryAddress: 'Usmanu Danfodiyo University Gate, Wamakko',
        productName: 'Grazer Tea',
        productSku: 'GRZ-TEA',
        status: 'pending',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        totalAmount: 22000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final result = OrderRoutingService.routeOrder(
        order: orderSokoto,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: stockAllocations,
      );

      expect(result.status, equals(RoutingStatus.unrouted));
      expect(result.distributionCenter?.id, equals(grandDcAbuja.id));
      expect(result.driver, isNull);
      expect(result.routedOrder.deliveryAgentId, isNull);
      expect(result.routedOrder.distributionCenterId, equals(grandDcAbuja.id));
      expect(result.routedOrder.status, equals('pending_dispatch'));
      expect(result.dispatchDiagnosis, contains('Escalated to Grand DC'));
    });

    test('6. Verify Grand DC flag and is_grand_dc column in remote Supabase DB', () async {
      final client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      try {
        final dcs = await client
            .from('distribution_centers')
            .select('id, name, code, is_grand_dc, is_hub, operating_zones')
            .eq('is_grand_dc', true)
            .limit(1);

        expect(dcs, isNotNull);
        expect(dcs.isNotEmpty, isTrue);
        final gd = dcs.first;
        expect(gd['is_grand_dc'], equals(true));
      } finally {
        client.dispose();
      }
    });
  });
}
