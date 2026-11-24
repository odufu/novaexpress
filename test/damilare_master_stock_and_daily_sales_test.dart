import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/domain/entities/agent_daily_sale_record.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_inventory_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Damilare Ajani Master Stock & Multi-Merchant Sales Tests', () {
    test('1. Damilare Ajani account authentication works seamlessly', () async {
      final mockAuth = MockAuthRemoteDataSource();
      final user = await mockAuth.login('damieajani@gmail.com', 'Password123!');

      expect(user.email, equals('damieajani@gmail.com'));
      expect(user.fullName, equals('Damilare Ajani'));
      expect(user.role, equals('super_admin'));
      expect(user.isSuperAdmin, isTrue);
    });

    test('2. MerchantInventoryProvider initializes all 9 real products and 94 CRM agents', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(merchantInventoryProvider);

      // Verify all 9 real products exist
      expect(state.products.length, equals(9));
      final skus = state.products.map((p) => p.sku).toSet();
      expect(skus.contains('NOVA-GRAZER-01'), isTrue);
      expect(skus.contains('NOVA-RESPIRA-02'), isTrue);
      expect(skus.contains('NOVA-URACLR-03'), isTrue);
      expect(skus.contains('SKU-ALPHA-MAN'), isTrue);
      expect(skus.contains('SKU-CLEAR-VISION'), isTrue);
      expect(skus.contains('SKU-DEFENDER-CAP'), isTrue);
      expect(skus.contains('SKU-GRAZER-BALM'), isTrue);
      expect(skus.contains('SKU-08806'), isTrue);
      expect(skus.contains('SKU-TRIPPLE-H'), isTrue);

      // Verify all 94+ logistics agents are present
      expect(state.agents.length, greaterThanOrEqualTo(94));
      final agentCodes = state.agents.map((a) => a.code).toSet();
      expect(agentCodes.contains('NX-ABJ-01'), isTrue);
      expect(agentCodes.contains('AG-001'), isTrue);
      expect(agentCodes.contains('AG-002'), isTrue);
      expect(agentCodes.contains('AG-093'), isTrue);
    });

    test('3. Holistic daily sales logging with DC replenishment and agent custody subtraction', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Setup a test logistics agent
      final testAgent = AdminLogisticsAgent(
        id: 'agent-damie-test-01',
        name: 'Novacare Express Delivery Test',
        agentCode: 'AG-DAMIE-01',
        type: '3pl_partner',
        contactPerson: 'Damilare Logistics',
        phone: '+234 704 226 6323',
        email: 'damie.agent@test.ng',
        coverageStates: ['Lagos', 'Abuja (FCT)'],
        activeRidersCount: 5,
        bankName: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'Damie Logistics Trust',
        status: 'active',
        rating: 5.0,
        totalDeliveries: 50,
        totalRemittedNaira: 500000.0,
        deliveryFee: 3000.0,
        failedDeliveryFee: 1000.0,
        commissionRate: 5.0,
        assignedWarehouseId: 'DC-ABJ-01',
        assignedWarehouseName: 'Abuja Central DC',
        assignedMerchantIds: ['00000000-0000-4000-8000-791731264594'],
        assignedMerchantNames: ['Novacare Limited'],
        heldStock: {
          'SKU-ALPHA-MAN': 20,
          'SKU-PRD-8309': 50, // Grazer Tea
        },
        createdAt: DateTime(2026, 1, 1),
      );

      notifier.updateLogisticsAgent(testAgent);

      // Record a daily sale: 5 units sold, 10 units replenished from Abuja Central DC, 1 returned
      final saleRecord = AgentDailySaleRecord(
        id: 'SALE-DAMIE-001',
        agentId: testAgent.id,
        agentName: testAgent.name,
        agentCode: testAgent.agentCode,
        orderReference: 'ORD-DAMIE-2026',
        customerName: 'Fatima Aliyu',
        customerPhone: '08031234567',
        deliveryLocation: 'Maitama, Abuja',
        items: const [
          AgentDailySaleItem(
            sku: 'SKU-PRD-8309',
            productName: 'Grazer Herbal Tea',
            quantity: 5,
            unitPrice: 14500.0,
          ),
        ],
        totalAmount: 5 * 14500.0,
        paymentMethod: 'cash_cod',
        status: 'delivered_collected',
        loggedBy: 'Damilare Ajani',
        timestamp: DateTime.now(),
        merchantId: '00000000-0000-4000-8000-791731264594',
        merchantName: 'Novacare Limited',
        replenishedUnits: 10,
        returnedUnits: 1,
        dcName: 'Abuja Central DC',
      );

      await notifier.recordAgentDailySale(saleRecord);

      final stateAfter = container.read(adminConsoleProvider);
      final agentAfter = stateAfter.agents.firstWhere((a) => a.id == testAgent.id);

      // Balance equation: 50 (start) + 10 (replenished) - 5 (sold) - 1 (returned) = 54
      expect(agentAfter.heldStock['SKU-PRD-8309'], equals(54));
      expect(stateAfter.dailySales.first.id, equals('SALE-DAMIE-001'));
      expect(stateAfter.dailySales.first.loggedBy, equals('Damilare Ajani'));
    });

    test('4. Manual custody adjustment and audit log creation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      final testAgent = AdminLogisticsAgent(
        id: 'agent-custody-adj-01',
        name: 'Manual Adjustment Agent',
        agentCode: 'AG-ADJ-01',
        type: '3pl_partner',
        contactPerson: 'Audit Contact',
        phone: '+234 809 999 8888',
        email: 'audit@test.ng',
        coverageStates: ['Kano'],
        activeRidersCount: 3,
        bankName: 'Zenith Bank',
        accountNumber: '2233445566',
        accountName: 'Audit Remittance Trust',
        status: 'active',
        rating: 4.8,
        totalDeliveries: 20,
        totalRemittedNaira: 200000.0,
        deliveryFee: 2800.0,
        failedDeliveryFee: 1000.0,
        commissionRate: 5.0,
        assignedWarehouseId: 'DC-ABJ-01',
        assignedWarehouseName: 'Abuja Central DC',
        assignedMerchantIds: ['00000000-0000-4000-8000-791731264594'],
        assignedMerchantNames: ['Novacare Limited'],
        heldStock: {
          'SKU-DEFENDER-CAP': 15,
        },
        createdAt: DateTime(2026, 1, 1),
      );

      notifier.updateLogisticsAgent(testAgent);

      // Damilare manually edits custody from 15 to 25
      await notifier.updateAgentCustodyStock(
        agentId: testAgent.id,
        newHeldStock: {'SKU-DEFENDER-CAP': 25},
        operatorName: 'Damilare Ajani',
        reason: 'Ambush physical count discrepancy reconciliation',
      );

      final state = container.read(adminConsoleProvider);
      final updatedAgent = state.agents.firstWhere((a) => a.id == testAgent.id);
      expect(updatedAgent.heldStock['SKU-DEFENDER-CAP'], equals(25));

      final auditLog = state.auditLogs.firstWhere(
        (log) => log.action == 'UPDATE_AGENT_CUSTODY_STOCK',
      );
      expect(auditLog.details.contains('Manual Adjustment Agent'), isTrue);
      expect(auditLog.details.contains('Damilare Ajani'), isTrue);
      expect(auditLog.details.contains('15 -> 25 (+10 units)'), isTrue);
    });
  });
}
