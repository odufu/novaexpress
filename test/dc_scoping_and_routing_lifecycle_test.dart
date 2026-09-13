import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  const grandDcId = '22222222-2222-4222-8222-222222222222';
  const otukpoDcId = '00000000-0000-4000-8000-788825051520';
  const ekitiDcId = '00000000-0000-4000-8000-788889180011';

  final wuseGrandDc = DistributionCenter(
    id: grandDcId,
    name: 'Wuse Central Distribution Hub',
    code: 'DC-ABJ-01',
    state: 'Abuja (FCT)',
    city: 'Wuse 2',
    address: 'Plot 412, Wuse 2, Abuja',
    isGrandDc: true,
    isHub: true,
    operatingZones: const ['Wuse 2', 'Maitama', 'Garki', 'Asokoro'],
  );

  final otukpoDc = DistributionCenter(
    id: otukpoDcId,
    name: 'Otukpo Distribution Center',
    code: 'DC-BN-01',
    state: 'Benue State',
    city: 'Otukpo',
    address: 'Federal Road, Otukpo',
    parentDcId: grandDcId,
    operatingZones: const ['Otukpo', 'Ogbadibo', 'Okpokwu'],
  );

  final ekitiDc = DistributionCenter(
    id: ekitiDcId,
    name: 'Ekiti State Distribution Center',
    code: 'DC-EK-01',
    state: 'Ekiti State',
    city: 'Ado-Ekiti',
    address: 'Secretariat Road, Ado-Ekiti',
    parentDcId: grandDcId,
    operatingZones: const ['Ado-Ekiti', 'Ikere', 'Ijero'],
  );

  final emekaRiderWuse = DCFleetDriver(
    id: 'emeka-wuse-uuid',
    driverCode: 'RDR-001',
    name: 'Emeka Okafor',
    phone: '08011111111',
    avatarUrl: '',
    vehicleModel: 'Bajaj Boxer',
    vehiclePlate: 'ABJ-123-XY',
    vehicleType: 'Motorcycle',
    status: 'active',
    assignedZone: 'Wuse 2',
    distributionCenterId: grandDcId,
    totalAssignedOrders: 3,
    completedOrders: 15,
    routeProgressPercent: 50.0,
    efficiencyRating: 98.0,
    cashInCustody: 25000.0,
    itemsInCustody: 4,
    personnelType: 'in_house_rider',
    compensationType: 'salary',
    commissionRate: 500.0,
    transportAllowance: 1000.0,
    failedDeliveryAllowance: 500.0,
    baseSalary: 120000.0,
    upsellBonusPercent: 5.0,
    bankName: 'Access Bank',
    bankAccountNumber: '1234567890',
    bankAccountName: 'Emeka Okafor',
    guarantorName: 'John Okafor',
    guarantorPhone: '08022222222',
  );

  final danielRiderOtukpo = DCFleetDriver(
    id: 'daniel-otukpo-uuid',
    driverCode: 'RDR-004',
    name: 'Daniel Onyanwu',
    phone: '08044444444',
    avatarUrl: '',
    vehicleModel: 'Honda Ace',
    vehiclePlate: 'BN-456-OT',
    vehicleType: 'Motorcycle',
    status: 'active',
    assignedZone: 'Otukpo',
    distributionCenterId: otukpoDcId,
    totalAssignedOrders: 2,
    completedOrders: 10,
    routeProgressPercent: 40.0,
    efficiencyRating: 97.0,
    cashInCustody: 15000.0,
    itemsInCustody: 2,
    personnelType: 'pda',
    compensationType: 'commission',
    commissionRate: 1500.0,
    transportAllowance: 1500.0,
    failedDeliveryAllowance: 500.0,
    baseSalary: 0.0,
    upsellBonusPercent: 10.0,
    bankName: 'Zenith Bank',
    bankAccountNumber: '2345678901',
    bankAccountName: 'Daniel Onyanwu',
    guarantorName: 'James Onyanwu',
    guarantorPhone: '08055555555',
  );

  final shalomRiderEkiti = DCFleetDriver(
    id: 'shalom-ekiti-uuid',
    driverCode: 'RDR-005',
    name: 'Shalom Samson',
    phone: '08077777777',
    avatarUrl: '',
    vehicleModel: 'TVS Star HLX',
    vehiclePlate: 'EK-789-AD',
    vehicleType: 'Motorcycle',
    status: 'active',
    assignedZone: 'Ado-Ekiti',
    distributionCenterId: ekitiDcId,
    totalAssignedOrders: 1,
    completedOrders: 8,
    routeProgressPercent: 30.0,
    efficiencyRating: 99.0,
    cashInCustody: 10000.0,
    itemsInCustody: 1,
    personnelType: 'pda',
    compensationType: 'commission',
    commissionRate: 1500.0,
    transportAllowance: 1500.0,
    failedDeliveryAllowance: 500.0,
    baseSalary: 0.0,
    upsellBonusPercent: 10.0,
    bankName: 'GTBank',
    bankAccountNumber: '3456789012',
    bankAccountName: 'Shalom Samson',
    guarantorName: 'Paul Samson',
    guarantorPhone: '08088888888',
  );

  group('DC Scoping: Riders Exclusivity', () {
    test('Riders strictly belong to their assigned distribution center', () {
      expect(emekaRiderWuse.distributionCenterId, grandDcId);
      expect(danielRiderOtukpo.distributionCenterId, otukpoDcId);
      expect(shalomRiderEkiti.distributionCenterId, ekitiDcId);

      // Verify no rider is unassigned or assigned across multiple DCs
      expect(emekaRiderWuse.distributionCenterId, isNot(equals(otukpoDcId)));
      expect(danielRiderOtukpo.distributionCenterId, isNot(equals(grandDcId)));
      expect(shalomRiderEkiti.distributionCenterId, isNot(equals(otukpoDcId)));
    });

    test('DCConsoleState.dcDrivers filters riders strictly by active DC hub', () {
      final allDrivers = [emekaRiderWuse, danielRiderOtukpo, shalomRiderEkiti];

      // 1. When Otukpo DC is the active hub:
      final otukpoState = DCConsoleState(
        activeHubId: otukpoDcId,
        activeHubCode: 'DC-BN-01',
        activeHubName: 'Otukpo Distribution Center',
        drivers: allDrivers,
      );

      final otukpoDrivers = otukpoState.dcDrivers;
      expect(otukpoDrivers.length, 1);
      expect(otukpoDrivers.first.id, danielRiderOtukpo.id);
      expect(otukpoDrivers.first.driverCode, 'RDR-004');

      // 2. When Grand DC (Wuse Central) is the active hub:
      final grandDcState = DCConsoleState(
        activeHubId: grandDcId,
        activeHubCode: 'DC-ABJ-01',
        activeHubName: 'Wuse Central Distribution Hub',
        drivers: allDrivers,
      );

      final grandDrivers = grandDcState.dcDrivers;
      expect(grandDrivers.length, 1);
      expect(grandDrivers.first.id, emekaRiderWuse.id);
      expect(grandDrivers.first.driverCode, 'RDR-001');

      // Verify sub-DC riders do not leak into Grand DC fleet view
      expect(grandDrivers.any((d) => d.id == danielRiderOtukpo.id), isFalse);
      expect(grandDrivers.any((d) => d.id == shalomRiderEkiti.id), isFalse);
    });
  });

  group('DC Scoping: Orders Isolation & Parent Inspection', () {
    final wuseOrder = OrderModel(
      id: 'ord-wuse-001',
      orderNumber: 'ORD-WUSE-001',
      customerName: 'Aisha Bello',
      customerPhone: '08099990001',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Wuse 2',
      deliveryAddress: '15 Aminu Kano Crescent',
      lga: 'Wuse 2',
      productName: 'Respira Detox Tea',
      status: 'in_transit',
      quantity: 2,
      basePrice: 20000.0,
      upsellAmount: 0.0,
      totalAmount: 20000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'unpaid',
      distributionCenterId: grandDcId,
      deliveryAgentId: emekaRiderWuse.id,
      deliveryAgentName: emekaRiderWuse.name,
      deliveryAgentCode: emekaRiderWuse.driverCode,
      createdAt: DateTime.now(),
    );

    final otukpoOrder = OrderModel(
      id: 'ord-otukpo-001',
      orderNumber: 'ORD-OTUK-001',
      customerName: 'Audu Ogbeh',
      customerPhone: '08099990002',
      deliveryState: 'Benue State',
      deliveryCity: 'Otukpo',
      deliveryAddress: '12 Commercial Road',
      lga: 'Otukpo',
      productName: 'Herbal Glow Body Cream',
      status: 'pending_dispatch',
      quantity: 1,
      basePrice: 15000.0,
      upsellAmount: 0.0,
      totalAmount: 15000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'unpaid',
      distributionCenterId: otukpoDcId,
      createdAt: DateTime.now(),
    );

    test('Orders routed to a DC belong strictly to that DC', () {
      expect(wuseOrder.distributionCenterId, grandDcId);
      expect(otukpoOrder.distributionCenterId, otukpoDcId);
      expect(otukpoOrder.distributionCenterId, isNot(equals(grandDcId)));
    });

    test('Grand DC inspects Sub-DC orders via DC Detail inspection logic', () {
      final allOrders = [wuseOrder, otukpoOrder];

      // Otukpo DC matches its own order
      final otukpoMatched = allOrders.where((o) {
        return o.distributionCenterId == otukpoDc.id ||
            o.deliveryAgentCode == otukpoDc.code ||
            otukpoDc.coversLocation(stateName: o.deliveryState, lgaName: o.lga ?? '');
      }).toList();

      expect(otukpoMatched.length, 1);
      expect(otukpoMatched.first.id, otukpoOrder.id);
      expect(otukpoMatched.first.orderNumber, 'ORD-OTUK-001');

      // Grand DC only matches its own order in main fleet view
      final grandDcOrders = allOrders.where((o) => o.distributionCenterId == grandDcId).toList();
      expect(grandDcOrders.length, 1);
      expect(grandDcOrders.first.id, wuseOrder.id);
    });
  });

  group('DC Scoping: Remittances Isolation', () {
    final otukpoRemittance = RemittanceEntity(
      id: 'rem-otukpo-001',
      referenceNumber: 'REM-OTUK-2026-001',
      companyId: '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: danielRiderOtukpo.id,
      amount: 45000.0,
      grossCollections: 50000.0,
      commissionDeducted: 3000.0,
      transportAllowanceDeducted: 2000.0,
      failedStipendsDeducted: 0.0,
      posFee: 0.0,
      paymentMethod: 'bank_transfer',
      status: 'pending',
      destinationBankName: 'Zenith Bank',
      destinationAccountNumber: '2345678901',
      destinationAccountName: 'Otukpo Hub Remittance',
      distributionCenterId: otukpoDcId,
      distributionCenterName: 'Otukpo Distribution Center',
      createdAt: DateTime.now(),
    );

    final wuseRemittance = RemittanceEntity(
      id: 'rem-wuse-001',
      referenceNumber: 'REM-WUSE-2026-001',
      companyId: '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: emekaRiderWuse.id,
      amount: 120000.0,
      grossCollections: 130000.0,
      commissionDeducted: 6000.0,
      transportAllowanceDeducted: 4000.0,
      failedStipendsDeducted: 0.0,
      posFee: 0.0,
      paymentMethod: 'bank_transfer',
      status: 'verified',
      destinationBankName: 'Access Bank',
      destinationAccountNumber: '1234567890',
      destinationAccountName: 'Wuse Central Logistics',
      distributionCenterId: grandDcId,
      distributionCenterName: 'Wuse Central Distribution Hub',
      createdAt: DateTime.now(),
    );

    test('Remittances are strictly scoped to the governing DC', () {
      final allRemittances = [otukpoRemittance, wuseRemittance];

      final otukpoScoped = allRemittances.where((r) => r.distributionCenterId == otukpoDcId).toList();
      expect(otukpoScoped.length, 1);
      expect(otukpoScoped.first.referenceNumber, 'REM-OTUK-2026-001');

      final wuseScoped = allRemittances.where((r) => r.distributionCenterId == grandDcId).toList();
      expect(wuseScoped.length, 1);
      expect(wuseScoped.first.referenceNumber, 'REM-WUSE-2026-001');
    });
  });

  group('Order Assignment Lifecycle: Assign, Reassign, and Unassign', () {
    final unassignedOrder = OrderModel(
      id: 'ord-unassigned-001',
      orderNumber: 'ORD-UNAS-001',
      customerName: 'Sani Abacha',
      customerPhone: '08033334444',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Garki',
      deliveryAddress: '24 Tafawa Balewa Way',
      lga: 'Garki',
      productName: 'Respira Detox Tea',
      status: 'pending_dispatch',
      quantity: 1,
      basePrice: 10000.0,
      upsellAmount: 0.0,
      totalAmount: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'unpaid',
      distributionCenterId: grandDcId,
      deliveryAgentId: null,
      deliveryAgentName: null,
      deliveryAgentCode: null,
      createdAt: DateTime.now(),
    );

    test('Initial order is unassigned', () {
      expect(unassignedOrder.isUnassigned, isTrue);
      expect(unassignedOrder.deliveryAgentId, isNull);
    });

    test('Assigning order sets rider and updates isUnassigned', () {
      final assignedOrder = unassignedOrder.copyWith(
        status: 'in_transit',
        deliveryAgentId: emekaRiderWuse.id,
        deliveryAgentName: emekaRiderWuse.name,
        deliveryAgentCode: emekaRiderWuse.driverCode,
        assignedAt: DateTime.now(),
      );

      expect(assignedOrder.isUnassigned, isFalse);
      expect(assignedOrder.deliveryAgentId, emekaRiderWuse.id);
      expect(assignedOrder.deliveryAgentName, emekaRiderWuse.name);
      expect(assignedOrder.deliveryAgentCode, 'RDR-001');
      expect(assignedOrder.status, 'in_transit');
    });

    test('Reassigning order cleanly updates the assigned rider', () {
      final assignedOrder = unassignedOrder.copyWith(
        status: 'in_transit',
        deliveryAgentId: emekaRiderWuse.id,
        deliveryAgentName: emekaRiderWuse.name,
        deliveryAgentCode: emekaRiderWuse.driverCode,
      );

      const replacementRiderId = 'replacement-rider-uuid';
      const replacementRiderName = 'Joel Odufu';
      const replacementRiderCode = 'RDR-002';

      final reassignedOrder = assignedOrder.copyWith(
        deliveryAgentId: replacementRiderId,
        deliveryAgentName: replacementRiderName,
        deliveryAgentCode: replacementRiderCode,
      );

      expect(reassignedOrder.isUnassigned, isFalse);
      expect(reassignedOrder.deliveryAgentId, replacementRiderId);
      expect(reassignedOrder.deliveryAgentName, replacementRiderName);
      expect(reassignedOrder.deliveryAgentCode, replacementRiderCode);
    });

    test('Unassigning order resets agent credentials and returns to unassigned pool', () {
      final assignedOrder = unassignedOrder.copyWith(
        status: 'in_transit',
        deliveryAgentId: emekaRiderWuse.id,
        deliveryAgentName: emekaRiderWuse.name,
        deliveryAgentCode: emekaRiderWuse.driverCode,
      );

      expect(assignedOrder.isUnassigned, isFalse);

      final unassignedBack = assignedOrder.copyWith(
        clearAssignment: true,
        status: 'pending_dispatch',
      );

      expect(unassignedBack.isUnassigned, isTrue);
      expect(unassignedBack.deliveryAgentId, isNull);
      expect(unassignedBack.deliveryAgentName, isNull);
      expect(unassignedBack.deliveryAgentCode, isNull);
      expect(unassignedBack.status, 'pending_dispatch');
    });
  });
}
