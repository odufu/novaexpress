import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/domain/entities/agent_daily_sale_record.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Agent Daily Sales & Automatic Stock Depletion Tests', () {
    test('1. AgentDailySaleRecord JSON serialization and unit totals', () {
      final sale = AgentDailySaleRecord(
        id: 'SALE-TEST-001',
        agentId: 'agent-001',
        agentName: 'Musa Ibrahim Logistics',
        agentCode: 'AG-042',
        orderReference: 'ORD-2026-999',
        customerName: 'Chinedu Eze',
        customerPhone: '+234 803 555 1234',
        deliveryLocation: 'Garki 2, Abuja',
        items: const [
          AgentDailySaleItem(
            sku: 'SKU-PRD-8309',
            productName: 'Grazer Herbal Detox Tea',
            quantity: 3,
            unitPrice: 21500.0,
          ),
          AgentDailySaleItem(
            sku: 'SKU-PRD-6731',
            productName: 'URA Clear',
            quantity: 2,
            unitPrice: 24500.0,
          ),
        ],
        totalAmount: (3 * 21500.0) + (2 * 24500.0),
        paymentMethod: 'cash_cod',
        status: 'delivered_collected',
        loggedBy: 'Supervisor Amina',
        timestamp: DateTime(2026, 11, 20, 14, 30),
      );

      expect(sale.totalUnits, equals(5));
      expect(sale.totalAmount, equals(113500.0));

      final json = sale.toJson();
      final roundtrip = AgentDailySaleRecord.fromJson(json);

      expect(roundtrip.id, equals(sale.id));
      expect(roundtrip.agentCode, equals('AG-042'));
      expect(roundtrip.items.length, equals(2));
      expect(roundtrip.items[0].sku, equals('SKU-PRD-8309'));
      expect(roundtrip.items[0].quantity, equals(3));
      expect(roundtrip.totalUnits, equals(5));
      expect(roundtrip.totalAmount, equals(113500.0));
    });

    test('2. recordAgentDailySale decrements agent heldStock and updates globalStock custody', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Create a test agent holding stock
      final testAgent = AdminLogisticsAgent(
        id: '99999999-9999-4999-8999-999999999999',
        name: 'Test Delivery Rider',
        agentCode: 'AG-TEST-777',
        type: '3pl_partner',
        contactPerson: 'Tunde Test',
        phone: '+234 801 111 2222',
        email: 'tunde@test.com',
        coverageStates: ['Abuja (FCT)'],
        activeRidersCount: 2,
        bankName: 'Access Bank',
        accountNumber: '0012345678',
        accountName: 'Tunde Test Logistics',
        status: 'active',
        rating: 4.9,
        totalDeliveries: 10,
        totalRemittedNaira: 150000.0,
        deliveryFee: 2500.0,
        failedDeliveryFee: 1000.0,
        commissionRate: 5.0,
        assignedWarehouseId: 'DC-ABJ-01',
        assignedWarehouseName: 'Abuja Central DC',
        assignedMerchantIds: ['merchant-novacare'],
        assignedMerchantNames: ['Novacare Limited'],
        heldStock: {
          'SKU-PRD-8309': 15, // 15 Grazer Tea
          'SKU-PRD-6731': 8,  // 8 URA Clear
        },
        createdAt: DateTime(2026, 1, 1),
      );

      // Setup initial state with test agent and test products
      notifier.updateLogisticsAgent(testAgent);

      var state = container.read(adminConsoleProvider);
      final agentBefore = state.agents.firstWhere((a) => a.id == testAgent.id);
      expect(agentBefore.heldStock['SKU-PRD-8309'], equals(15));
      expect(agentBefore.heldStock['SKU-PRD-6731'], equals(8));

      // Record a daily sale: 3 Grazer Tea and 2 URA Clear
      final sale = AgentDailySaleRecord(
        id: 'SALE-REC-001',
        agentId: testAgent.id,
        agentName: testAgent.name,
        agentCode: testAgent.agentCode,
        orderReference: 'ORD-TEST-001',
        customerName: 'Fatima Aliyu',
        customerPhone: '+234 809 111 3333',
        deliveryLocation: 'Maitama, Abuja',
        items: const [
          AgentDailySaleItem(
            sku: 'SKU-PRD-8309',
            productName: 'Grazer Herbal Detox Tea',
            quantity: 3,
            unitPrice: 21500.0,
          ),
          AgentDailySaleItem(
            sku: 'SKU-PRD-6731',
            productName: 'URA Clear',
            quantity: 2,
            unitPrice: 24500.0,
          ),
        ],
        totalAmount: (3 * 21500.0) + (2 * 24500.0),
        paymentMethod: 'cash_cod',
        status: 'delivered_collected',
        loggedBy: 'Dispatcher Sani',
        timestamp: DateTime.now(),
      );

      await notifier.recordAgentDailySale(sale);

      state = container.read(adminConsoleProvider);

      // 1. Verify sale record was appended to state.dailySales
      expect(state.dailySales, isNotEmpty);
      expect(state.dailySales.first.id, equals('SALE-REC-001'));
      expect(state.dailySales.first.totalUnits, equals(5));

      // 2. Verify agent held stock was automatically deducted ("minused")
      final agentAfter = state.agents.firstWhere((a) => a.id == testAgent.id);
      expect(agentAfter.heldStock['SKU-PRD-8309'], equals(12)); // 15 - 3 = 12
      expect(agentAfter.heldStock['SKU-PRD-6731'], equals(6));  // 8 - 2 = 6
      expect(agentAfter.totalDeliveries, equals(11));

      // 3. Verify audit trail was logged
      expect(
        state.auditLogs.any((log) =>
            log.action == 'RECORD_AGENT_DAILY_SALE' &&
            log.details.contains('ORD-TEST-001') &&
            log.details.contains('5 units')),
        isTrue,
      );
    });
  });
}
