import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_operations_officer.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';

void main() {
  group('DC Operations Department & Strictly Mobile Portal Tests', () {
    final wuseDc = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      companyId: '11111111-1111-4111-8111-111111111111',
      name: 'Wuse Grand Central Distribution Center',
      code: 'DC-WUSE-01',
      state: 'Abuja (FCT)',
      city: 'Wuse 2',
      address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
      contactPhone: '+2348023456789',
      contactEmail: 'dc.supervisor@novaxpress.ng',
      managerName: 'Ahmed Bello',
      isGrandDc: true,
      isHub: true,
      isActive: true,
      operatingZones: const ['AMAC', 'Wuse 2', 'Maitama', 'Garki'],
      storageCapacityUnits: 25000,
      totalAssignedRiders: 5,
      activeInventoryBatches: 2,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final otukpoDc = DistributionCenter(
      id: '33333333-3333-4333-8333-333333333333',
      companyId: '11111111-1111-4111-8111-111111111111',
      name: 'Otukpo Regional Distribution Center',
      code: 'DC-OTK-01',
      state: 'Benue State',
      city: 'Otukpo',
      address: '14 Federal Road, Otukpo, Benue State',
      contactPhone: '+2348098765432',
      contactEmail: 'dc.otukpo@novaxpress.ng',
      managerName: 'Sunday Ogwuche',
      isGrandDc: false,
      isHub: false,
      isActive: true,
      operatingZones: const ['Otukpo', 'Ogbadibo', 'Okpokwu'],
      storageCapacityUnits: 10000,
      totalAssignedRiders: 2,
      activeInventoryBatches: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('1. DCOperationsOfficer entity properties and methods', () {
      final officer = DCOperationsOfficer(
        id: 'ops-001',
        email: 'ops.wuse@novaxpress.ng',
        firstName: 'Ibrahim',
        lastName: 'Garba',
        phone: '08012345678',
        staffCode: 'OPS-WUSE-01',
        distributionCenterId: wuseDc.id,
        distributionCenterName: wuseDc.name,
        rawPassword: 'Password123!',
        assignedZone: 'Wuse 2',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(officer.fullName, 'Ibrahim Garba');
      expect(officer.name, 'Ibrahim Garba');
      expect(officer.isActive, isTrue);
      expect(officer.staffCode, 'OPS-WUSE-01');
      expect(officer.distributionCenterId, wuseDc.id);
      expect(officer.rawPassword, 'Password123!');

      final copied = officer.copyWith(isActive: false, rawPassword: 'NewPassword!');
      expect(copied.isActive, isFalse);
      expect(copied.rawPassword, 'NewPassword!');

      final json = officer.toJson();
      expect(json['delivery_agent_code'], 'OPS-WUSE-01');
      expect(json['role'], 'dc_operations');

      final fromJson = DCOperationsOfficer.fromJson(json);
      expect(fromJson.name, officer.name);
      expect(fromJson.staffCode, officer.staffCode);
    });

    test('2. DC Console State operations officer filtering and scoping', () {
      final officer1 = DCOperationsOfficer(
        id: 'ops-1',
        email: 'ibrahim@novaxpress.ng',
        firstName: 'Ibrahim',
        lastName: 'Garba',
        phone: '08012345678',
        staffCode: 'OPS-WUSE-01',
        distributionCenterId: wuseDc.id,
        distributionCenterName: wuseDc.name,
        createdAt: DateTime.now(),
      );

      final officer2 = DCOperationsOfficer(
        id: 'ops-2',
        email: 'sunday@novaxpress.ng',
        firstName: 'Sunday',
        lastName: 'Ogwuche',
        phone: '08098765432',
        staffCode: 'OPS-OTK-01',
        distributionCenterId: otukpoDc.id,
        distributionCenterName: otukpoDc.name,
        createdAt: DateTime.now(),
      );

      final stateWuse = DCConsoleState(
        activeHubId: wuseDc.id,
        activeHubName: wuseDc.name,
        activeHubCode: wuseDc.code,
        distributionCenters: [wuseDc, otukpoDc],
        operationsOfficers: [officer1, officer2],
      );

      expect(stateWuse.dcOperationsOfficers.length, 1);
      expect(stateWuse.dcOperationsOfficers.first.id, 'ops-1');

      final stateOtukpo = DCConsoleState(
        activeHubId: otukpoDc.id,
        activeHubName: otukpoDc.name,
        activeHubCode: otukpoDc.code,
        distributionCenters: [wuseDc, otukpoDc],
        operationsOfficers: [officer1, officer2],
      );

      expect(stateOtukpo.dcOperationsOfficers.length, 1);
      expect(stateOtukpo.dcOperationsOfficers.first.id, 'ops-2');
    });

    test('3. Order visibility and DC scoping: Operations cannot see other DCs orders', () {
      final wuseOrder = OrderEntity(
        id: 'ord-wuse-01',
        orderNumber: 'NX-1001',
        customerName: 'Amina Sani',
        customerPhone: '08011112222',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Wuse Zone 4',
        lga: 'AMAC',
        productName: 'Grazer Herbal Blend',
        status: 'pending_dispatch',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        basePrice: 15000,
        upsellAmount: 0,
        totalAmount: 30000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Grazer Wellness',
        clientCompany: 'Grazer Enterprise',
        clientDeliveryFee: 2500,
        agentEntitlement: 1500,
        transportFee: 500,
        distributionCenterId: wuseDc.id,
        remittanceStatus: 'unremitted',
        financialSettlementStatus: 'pending_remittance',
        createdAt: DateTime.now(),
      );

      final otukpoOrder = OrderEntity(
        id: 'ord-otk-01',
        orderNumber: 'NX-2001',
        customerName: 'Peter Ejeh',
        customerPhone: '08033334444',
        deliveryState: 'Benue State',
        deliveryCity: 'Otukpo',
        deliveryAddress: 'Upu Road',
        lga: 'Otukpo',
        productName: 'Grazer Herbal Blend',
        status: 'pending_dispatch',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 15000,
        upsellAmount: 0,
        totalAmount: 15000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Grazer Wellness',
        clientCompany: 'Grazer Enterprise',
        clientDeliveryFee: 2500,
        agentEntitlement: 1500,
        transportFee: 500,
        distributionCenterId: otukpoDc.id,
        remittanceStatus: 'unremitted',
        financialSettlementStatus: 'pending_remittance',
        createdAt: DateTime.now(),
      );

      final allDcs = [wuseDc, otukpoDc];

      // Wuse Operations: Only sees Wuse order
      expect(OrderRoutingService.doesOrderBelongToDc(order: wuseOrder, currentDc: wuseDc, allDcs: allDcs), isTrue);
      expect(OrderRoutingService.doesOrderBelongToDc(order: otukpoOrder, currentDc: wuseDc, allDcs: allDcs), isFalse);

      // Otukpo Operations: Only sees Otukpo order
      expect(OrderRoutingService.doesOrderBelongToDc(order: otukpoOrder, currentDc: otukpoDc, allDcs: allDcs), isTrue);
      expect(OrderRoutingService.doesOrderBelongToDc(order: wuseOrder, currentDc: otukpoDc, allDcs: allDcs), isFalse);
    });

    test('4. Security & Router isolation: Operations role is strictly confined to /ops', () {
      final opsUser = UserEntity(
        id: 'usr-ops-01',
        email: 'ops.wuse@novaxpress.ng',
        firstName: 'Ibrahim',
        lastName: 'Garba',
        phone: '08012345678',
        role: 'dc_operations',
        distributionCenterId: wuseDc.id,
      );

      expect(opsUser.isDcOperations, isTrue);
      expect(opsUser.isDcManager, isFalse);
      expect(opsUser.isRider, isFalse);
      expect(opsUser.isCloser, isFalse);
      expect(opsUser.isMarketer, isFalse);
      expect(opsUser.homeConsoleRoute, '/ops');

      final authState = AuthState(
        isInitialized: true,
        user: opsUser,
      );

      // 1. Trying to access DC console (/dc) -> Redirected to /ops
      final dcRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/dc',
      );
      expect(dcRedirect, '/ops');

      // 2. Trying to access Rider console (/) -> Redirected to /ops
      final riderRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/',
      );
      expect(riderRedirect, '/ops');

      // 3. Trying to access Client portal (/client) -> Redirected to /ops
      final clientRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/client',
      );
      expect(clientRedirect, '/ops');

      // 4. Accessing mobile operations portal (/ops) -> Allowed (null redirect)
      final opsAllowed = appRouteRedirect(
        authState: authState,
        matchedLocation: '/ops',
      );
      expect(opsAllowed, isNull);

      // 5. Accessing subroute (/ops/orders) -> Allowed
      final opsSubAllowed = appRouteRedirect(
        authState: authState,
        matchedLocation: '/ops/orders',
      );
      expect(opsSubAllowed, isNull);
    });

    test('5. Dispatch Validation: Rider stock custody check, workload balancing, and avatar', () {
      final order = OrderEntity(
        id: 'ord-wuse-99',
        orderNumber: 'NX-9999',
        customerName: 'Zainab Kabir',
        customerPhone: '08099998888',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Aminu Kano',
        productName: 'Grazer Herbal Blend',
        status: 'pending_dispatch',
        quantity: 3, // Requires 3 units
        paidQuantity: 3,
        freeQuantity: 0,
        basePrice: 15000,
        upsellAmount: 0,
        totalAmount: 45000,
        clientDeliveryFee: 2500,
        agentEntitlement: 1500,
        transportFee: 500,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distributed_inventory',
        clientName: 'Grazer Organics',
        clientCompany: 'Grazer Ltd',
        distributionCenterId: wuseDc.id,
        remittanceStatus: 'unremitted',
        financialSettlementStatus: 'pending_remittance',
        createdAt: DateTime.now(),
      );

      // Rider A: Has profile photo, 5 units in custody, 0 active orders (Available)
      const riderA = DCFleetDriver(
        id: 'rdr-01',
        driverCode: 'RDR-001',
        name: 'Musa Ibrahim',
        phone: '08012345678',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'ABJ-123-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Wuse 2',
        totalAssignedOrders: 10,
        completedOrders: 10,
        routeProgressPercent: 100,
        efficiencyRating: 99.0,
        cashInCustody: 0,
        itemsInCustody: 5,
      );

      // Rider B: Has only 1 unit in custody (Less than required 3 units), 3 active orders (Overloaded)
      const riderB = DCFleetDriver(
        id: 'rdr-02',
        driverCode: 'RDR-002',
        name: 'Emeka Okafor',
        phone: '08087654321',
        avatarUrl: '',
        vehicleModel: 'TVS Neo',
        vehiclePlate: 'ABJ-456-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Maitama',
        totalAssignedOrders: 15,
        completedOrders: 12,
        routeProgressPercent: 80,
        efficiencyRating: 95.0,
        cashInCustody: 20000,
        itemsInCustody: 1, // Only 1 unit in vehicle
      );

      // Verify Rider A has sufficient stock and avatar
      expect(riderA.avatarUrl, isNotEmpty);
      expect(riderA.itemsInCustody >= order.quantity, isTrue);

      // Verify Rider B has insufficient stock (< order quantity of 3)
      expect(riderB.itemsInCustody < order.quantity, isTrue);

      // Active orders simulation
      final activeOrdersForRiderB = [
        order.copyWith(id: 'active-1', status: 'in_transit', deliveryAgentId: riderB.id),
        order.copyWith(id: 'active-2', status: 'assigned', deliveryAgentId: riderB.id),
        order.copyWith(id: 'active-3', status: 'out_for_delivery', deliveryAgentId: riderB.id),
      ];

      final riderBLoad = activeOrdersForRiderB.where((o) =>
        (o.deliveryAgentId == riderB.id || o.deliveryAgentCode == riderB.driverCode) &&
        (o.status == 'in_transit' || o.status == 'assigned' || o.status == 'out_for_delivery')
      ).length;

      expect(riderBLoad, 3);
      // Rider A has 0 active orders (Lowest load -> prioritized for load balancing)
      final riderALoad = activeOrdersForRiderB.where((o) =>
        (o.deliveryAgentId == riderA.id || o.deliveryAgentCode == riderA.driverCode) &&
        (o.status == 'in_transit' || o.status == 'assigned' || o.status == 'out_for_delivery')
      ).length;

      expect(riderALoad, 0);
      expect(riderALoad < riderBLoad, isTrue);
    });

    test('6. Operations Officer authentication & role resolution: Abigail Operations', () async {
      final authDs = MockAuthRemoteDataSource();

      // Test login with Abigail's credentials
      final user = await authDs.login('abigail@novaxpress.ng', 'bG5y2mZdrW');

      expect(user.email, 'abigail@novaxpress.ng');
      expect(user.role, 'dc_operations');
      expect(user.isDcOperations, isTrue);
      expect(user.isRider, isFalse);
      expect(user.deliveryAgentId, isNull);
      expect(user.deliveryAgentCode, 'OPS-WUSE-01-748');
      expect(user.distributionCenterId, '22222222-2222-4222-8222-222222222222');
      expect(user.distributionCenterName, 'Wuse Grand Central Distribution Center');
      expect(user.homeConsoleRoute, '/ops');
      expect(user.roleDescription, 'DC Operations & Dispatch Officer');

      // Test router isolation for Abigail
      final authState = AuthState(user: user, isInitialized: true);

      // Login page redirect should go straight to /ops
      final loginRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/login',
      );
      expect(loginRedirect, '/ops');

      // Attempting to visit Rider root app '/' must be blocked and redirected to /ops
      final riderRootRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/',
      );
      expect(riderRootRedirect, '/ops');

      // Attempting to visit Rider orders '/orders' must be blocked and redirected to /ops
      final riderOrdersRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/orders',
      );
      expect(riderOrdersRedirect, '/ops');

      // Attempting to visit DC supervisor console '/dc' must be blocked and redirected to /ops
      final dcRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/dc',
      );
      expect(dcRedirect, '/ops');

      // Visiting allowed operations portal '/ops' returns null (allowed)
      final opsRedirect = appRouteRedirect(
        authState: authState,
        matchedLocation: '/ops',
      );
      expect(opsRedirect, isNull);
    });
  });
}
