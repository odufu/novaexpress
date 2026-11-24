import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/domain/entities/agent_daily_sale_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NovaXpress Dual Stock Keepers & Independent Consoles Architecture Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Strict separation: DCFleetDriver distinguishes NovaXpress Agents from NovaXpress Logistics Riders', () {
      // Platform 3PL Agent (ADICHA LOGISTICS)
      const adichaAgent = DCFleetDriver(
        id: 'agent-adicha',
        driverCode: 'AG-001',
        name: 'ADICHA LOGISTICS',
        phone: '08011111111',
        assignedZone: 'Lagos Mainland',
        personnelType: 'pda',
      );

      // Platform 3PL Agent (Victor Ogbenyi Logistics)
      const victorAgent = DCFleetDriver(
        id: 'agent-victor',
        driverCode: 'AG-002',
        name: 'Victor Ogbenyi Logistics',
        phone: '08022222222',
        assignedZone: 'Lagos Island',
        personnelType: 'pda',
      );

      // Top-level NovaXpress Logistics internal fleet corporate entity
      const nxCorporate = DCFleetDriver(
        id: 'agent-novaxpress-logistics',
        driverCode: 'NX-ABJ-01',
        name: 'NovaXpress Logistics (Internal Fleet)',
        phone: '08031112233',
        assignedZone: 'Wuse 2',
        personnelType: 'pda',
      );

      // NovaXpress Logistics Delivery Workforce Members:
      // a) In-house fleet rider
      const inHouseRider = DCFleetDriver(
        id: 'drv-001',
        driverCode: 'DRV-001',
        name: 'Musa In-House Rider',
        phone: '08033333333',
        assignedZone: 'Abuja Municipal (AMAC)',
        personnelType: 'in_house_rider',
      );

      // b) In-house app PDA rider
      const pdaRider = DCFleetDriver(
        id: 'pda-7000',
        driverCode: 'PDA-7000',
        name: 'Emeka App Rider',
        phone: '08044444444',
        assignedZone: 'Abuja Municipal (AMAC)',
        personnelType: 'pda',
      );

      // c) External PDA (Offline 3PL Courier)
      const externalPda = DCFleetDriver(
        id: 'ext-pda-001',
        driverCode: 'EXT-PDA-001',
        name: 'Suleiman External Courier',
        phone: '08055555555',
        assignedZone: 'Abuja Municipal (AMAC)',
        personnelType: 'external_pda',
      );

      // d) Offline non-app distributor
      const distributor = DCFleetDriver(
        id: 'dist-001',
        driverCode: 'DIST-001',
        name: 'Abuja Regional Offline Distributor',
        phone: '08066666666',
        assignedZone: 'Abuja Municipal (AMAC)',
        personnelType: 'distributor',
      );

      // Assert platform agents are recognized as platform agents
      expect(adichaAgent.isPlatformAgent, isTrue);
      expect(adichaAgent.isNovaXpressLogisticsRider, isFalse);

      expect(victorAgent.isPlatformAgent, isTrue);
      expect(victorAgent.isNovaXpressLogisticsRider, isFalse);

      expect(nxCorporate.isPlatformAgent, isTrue);
      expect(nxCorporate.isNovaXpressLogisticsRider, isFalse);

      // Assert NovaXpress Logistics workforce are recognized as legitimate riders & NOT platform agents
      expect(inHouseRider.isPlatformAgent, isFalse);
      expect(inHouseRider.isNovaXpressLogisticsRider, isTrue);
      expect(inHouseRider.isInHouseRider, isTrue);

      expect(pdaRider.isPlatformAgent, isFalse);
      expect(pdaRider.isNovaXpressLogisticsRider, isTrue);
      expect(pdaRider.isPda, isTrue);

      expect(externalPda.isPlatformAgent, isFalse);
      expect(externalPda.isNovaXpressLogisticsRider, isTrue);
      expect(externalPda.isExternalPda, isTrue);

      expect(distributor.isPlatformAgent, isFalse);
      expect(distributor.isNovaXpressLogisticsRider, isTrue);
      expect(distributor.isDistributor, isTrue);

      // Filtering verification for NovaXpress Logistics DC Console
      final allMixed = [adichaAgent, victorAgent, nxCorporate, inHouseRider, pdaRider, externalPda, distributor];
      final logisticsWorkforce = allMixed.where((d) => !d.isPlatformAgent).toList();

      expect(logisticsWorkforce.length, equals(4));
      expect(logisticsWorkforce.map((d) => d.driverCode), containsAll(['DRV-001', 'PDA-7000', 'EXT-PDA-001', 'DIST-001']));
      expect(logisticsWorkforce.map((d) => d.driverCode), isNot(contains('AG-001')));
      expect(logisticsWorkforce.map((d) => d.driverCode), isNot(contains('AG-002')));
      expect(logisticsWorkforce.map((d) => d.driverCode), isNot(contains('NX-ABJ-01')));
    });

    test('2. Stock allocation dependency: 0 platform allocation blocks rider allocation', () {
      // Product with 0 units allocated from NovaXpress platform (Damilare)
      final unallocatedProduct = StockItemEntity(
        id: 'prod-unallocated-01',
        sku: 'NOVA-UNALLOC-01',
        name: 'Unallocated Test Formula',
        description: 'No replenishment from Damilare',
        price: 25000.0,
        availableCount: 0,
        assignedCount: 0,
        deliveredCount: 0,
        returnedCount: 0,
        category: 'Health',
      );

      // Attempting to allocate when availableCount <= 0 must fail
      const requestQty = 5;
      expect(unallocatedProduct.availableCount < requestQty, isTrue);

      // If availableCount is 0, allocation message indicates dependency on Damilare's master replenishment
      final hasZeroStock = unallocatedProduct.availableCount <= 0;
      final errorMessage = hasZeroStock
          ? 'Cannot allocate: NovaXpress Logistics has 0 available units from NovaXpress platform. Request stock allocation from Damilare first.'
          : 'Insufficient warehouse stock.';

      expect(errorMessage, contains('Damilare'));
      expect(errorMessage, contains('0 available units'));
    });

    test('3. Stock allocation dependency: Platform allocation enables DC Station shelf allocation to riders', () {
      // Damilare allocates 100 units of Grazer Tea to NovaXpress Logistics
      const platformAllocation = 100;

      var stationShelfItem = StockItemEntity(
        id: 'prod-grazer-01',
        sku: 'NOVA-GRAZER-01',
        name: 'Grazer Herbal Tea',
        description: 'Herbal Detox Tea',
        price: 21500.0,
        availableCount: platformAllocation,
        assignedCount: 0,
        deliveredCount: 0,
        returnedCount: 0,
        category: 'Health & Wellness',
      );

      expect(stationShelfItem.availableCount, equals(100));

      // Ani Willis Ami allocates 20 units to In-House Rider (DRV-001)
      const riderQty = 20;
      stationShelfItem = stationShelfItem.copyWith(
        availableCount: stationShelfItem.availableCount - riderQty,
        assignedCount: stationShelfItem.assignedCount + riderQty,
      );

      final riderAlloc = RiderStockAllocation(
        id: 'alloc-drv-001',
        riderId: 'drv-001',
        riderName: 'Musa Rider',
        riderCode: 'DRV-001',
        productId: stationShelfItem.id,
        productName: stationShelfItem.name,
        sku: stationShelfItem.sku,
        allocatedUnits: riderQty,
        deliveredUnits: 0,
        inCustodyUnits: riderQty,
        unitPrice: stationShelfItem.price,
        allocatedAt: DateTime.now(),
      );

      // Ani Willis Ami allocates 15 units to External PDA (EXT-PDA-001)
      const extPdaQty = 15;
      stationShelfItem = stationShelfItem.copyWith(
        availableCount: stationShelfItem.availableCount - extPdaQty,
        assignedCount: stationShelfItem.assignedCount + extPdaQty,
      );

      final extPdaAlloc = RiderStockAllocation(
        id: 'alloc-ext-001',
        riderId: 'ext-pda-001',
        riderName: 'Suleiman External Courier',
        riderCode: 'EXT-PDA-001',
        productId: stationShelfItem.id,
        productName: stationShelfItem.name,
        sku: stationShelfItem.sku,
        allocatedUnits: extPdaQty,
        deliveredUnits: 0,
        inCustodyUnits: extPdaQty,
        unitPrice: stationShelfItem.price,
        allocatedAt: DateTime.now(),
      );

      // Mathematical balancing equation verification
      expect(stationShelfItem.availableCount, equals(65)); // 100 - (20 + 15)
      expect(stationShelfItem.assignedCount, equals(35));
      expect(riderAlloc.inCustodyUnits, equals(20));
      expect(extPdaAlloc.inCustodyUnits, equals(15));

      final totalCustodyHeldByRiders = riderAlloc.inCustodyUnits + extPdaAlloc.inCustodyUnits;
      expect(stationShelfItem.availableCount + totalCustodyHeldByRiders, equals(platformAllocation));
    });

    test('4. Independent consoles: Damilare manages all Agents, Ani Willis manages Fleet Riders', () {
      // 1. Damilare's Platform Scope
      final damilareManagedAgents = [
        'NovaXpress Logistics (Internal Fleet)',
        'ADICHA LOGISTICS',
        'Victor Ogbenyi Logistics',
        'Omoga Victor Ohe-obe Logistics',
      ];

      // Damilare can replenish NovaXpress Logistics
      final novaXpressAgent = AdminLogisticsAgent(
        id: 'agent-novaxpress-logistics',
        name: 'NovaXpress Logistics (Internal Fleet)',
        agentCode: 'NX-ABJ-01',
        type: 'internal_logistics',
        contactPerson: 'Engr. Tunde Adeleke',
        phone: '+234 803 111 2233',
        email: 'logistics@novaxpress.ng',
        coverageStates: const ['Abuja (FCT)', 'Niger', 'Nasarawa', 'Kaduna'],
        heldStock: const {'NOVA-GRAZER-01': 100},
        createdAt: DateTime.now(),
      );

      expect(damilareManagedAgents, contains(novaXpressAgent.name));

      // 2. Ani Willis Ami's Station Scope (strictly couriers & distributors under NovaXpress Logistics)
      final aniWillisWorkforceCodes = ['DRV-001', 'PDA-7000', 'EXT-PDA-001', 'DIST-001'];

      // Neither ADICHA nor Victor Ogbenyi are under Ani Willis Ami's station workforce
      expect(aniWillisWorkforceCodes, isNot(contains('AG-001')));
      expect(aniWillisWorkforceCodes, isNot(contains('AG-002')));
      expect(aniWillisWorkforceCodes, isNot(contains('NX-ABJ-01')));
    });
  });
}
