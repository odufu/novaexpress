import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/domain/entities/crm_agents_roster.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_inventory_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Agent Management, Warehouse Scoping & Merchant Assignment Tests', () {
    test('1. CSV Agents Roster loads comprehensive agents with required attributes', () {
      final roster = CrmAgentsRoster.defaultAgents;
      expect(roster.length, greaterThanOrEqualTo(110));

      for (final agent in roster) {
        expect(agent.id, isNotEmpty);
        expect(agent.name, isNotEmpty);
        expect(agent.agentCode, isNotEmpty);
        expect(agent.contactPerson, isNotEmpty);
        expect(agent.phone, isNotEmpty);
        expect(agent.email, isNotEmpty);
        expect(agent.deliveryFee, greaterThan(0));
        expect(agent.failedDeliveryFee, greaterThan(0));
        expect(agent.assignedWarehouseId, isNotNull);
      }
    });

    test('2. Warehouse Scoping: Abuja uses NovaXpress logistics; Lagos Central does NOT', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      var state = container.read(adminConsoleProvider);

      // Verify NovaXpress Logistics fleet is assigned to Abuja Central DC
      final nxAgent = state.agents.firstWhere((a) => a.id == 'agent-novaxpress-logistics');
      expect(nxAgent.assignedWarehouseId, equals('DC-ABJ-01'));
      expect(nxAgent.assignedWarehouseName, equals('Abuja Central DC'));

      // Filter by Abuja Central DC
      notifier.setAgentHubFilter('DC-ABJ-01');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents, isNotEmpty);
      expect(
        state.filteredAgents.any((a) => a.name.contains('NOVA XPRESS') || a.name.contains('NovaXpress')),
        isTrue,
        reason: 'Abuja Central DC must include NovaXpress Logistics fleet',
      );

      // Filter by Lagos Central DC
      notifier.setAgentHubFilter('DC-LAG-01');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents, isNotEmpty);
      expect(
        state.filteredAgents.any((a) => a.type == 'internal_logistics' || a.name.toLowerCase().contains('novaxpress')),
        isFalse,
        reason: 'Lagos Central DC must strictly NOT include NovaXpress Logistics fleet',
      );

      // Lagos has valid 3PL partner agents
      expect(
        state.filteredAgents.any((a) => a.name.contains('ADICHA') || a.name.contains('Victor Ogbenyi')),
        isTrue,
      );
    });

    test('3. Assign and unassign agent across multiple merchants and verify filtering', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      final testAgentId = 'agent-victor-ogbenyi-logistics';

      // Assign Victor Ogbenyi to Novacare and Shop Eleven
      await notifier.assignAgentToMerchants(
        agentId: testAgentId,
        merchantIds: ['merchant-novacare', 'merchant-shop11'],
        merchantNames: ['Novacare Limited', 'Shop Eleven Limited'],
      );

      var state = container.read(adminConsoleProvider);
      final agentAfterAssign = state.agents.firstWhere((a) => a.id == testAgentId);
      expect(agentAfterAssign.assignedMerchantIds, contains('merchant-novacare'));
      expect(agentAfterAssign.assignedMerchantIds, contains('merchant-shop11'));
      expect(agentAfterAssign.assignedMerchantNames, contains('Novacare Limited'));

      // Filter by Novacare: agent must be visible
      notifier.setAgentMerchantFilter('merchant-novacare');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents.any((a) => a.id == testAgentId), isTrue);

      // Filter by Shop Eleven: agent must be visible
      notifier.setAgentMerchantFilter('merchant-shop11');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents.any((a) => a.id == testAgentId), isTrue);

      // Unassign from Shop Eleven
      await notifier.unassignAgentFromMerchant(
        agentId: testAgentId,
        merchantId: 'merchant-shop11',
      );

      state = container.read(adminConsoleProvider);
      final agentAfterUnassign = state.agents.firstWhere((a) => a.id == testAgentId);
      expect(agentAfterUnassign.assignedMerchantIds.contains('merchant-shop11'), isFalse);
      expect(agentAfterUnassign.assignedMerchantIds.contains('merchant-novacare'), isTrue);

      // Filter by Shop Eleven: agent should no longer appear
      notifier.setAgentMerchantFilter('merchant-shop11');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents.any((a) => a.id == testAgentId), isFalse);

      // But still appears under Novacare
      notifier.setAgentMerchantFilter('merchant-novacare');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents.any((a) => a.id == testAgentId), isTrue);
    });

    test('4. Update individual agent details, fees, commissions, and bank details', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      await notifier.loadAll();
      final initialAgent = container.read(adminConsoleProvider).agents.firstWhere(
            (a) => a.id == 'agent-adicha-logistics',
          );

      final updatedAgent = initialAgent.copyWith(
        deliveryFee: 3500.0,
        failedDeliveryFee: 1500.0,
        commissionRate: 7.5,
        contactPerson: 'Mr. Adicha Senior Ops',
        phone: '+234 812 999 8877',
        bankName: 'Providus Bank',
        accountNumber: '9988776655',
        accountName: 'Adicha Logistics Enterprise',
        assignedWarehouseId: 'DC-LAG-01',
        assignedWarehouseName: 'Lagos Central DC',
      );

      await notifier.updateLogisticsAgent(updatedAgent);

      final state = container.read(adminConsoleProvider);
      final savedAgent = state.agents.firstWhere((a) => a.id == 'agent-adicha-logistics');

      expect(savedAgent.deliveryFee, equals(3500.0));
      expect(savedAgent.failedDeliveryFee, equals(1500.0));
      expect(savedAgent.commissionRate, equals(7.5));
      expect(savedAgent.contactPerson, equals('Mr. Adicha Senior Ops'));
      expect(savedAgent.phone, equals('+234 812 999 8877'));
      expect(savedAgent.bankName, equals('Providus Bank'));
      expect(savedAgent.accountNumber, equals('9988776655'));

      // Audit log was created
      final latestLog = state.auditLogs.first;
      expect(latestLog.action, equals('UPDATE_AGENT_DETAILS'));
      expect(latestLog.details, contains('3500'));
      expect(latestLog.details, contains('1500'));
      expect(latestLog.details, contains('7.5%'));
    });

    test('5. Each warehouse can register their own agent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Register agent under Abuja Central DC
      await notifier.registerLogisticsAgent(
        name: 'Capital Express Rider Partner',
        agentCode: 'ABJ-EXP-099',
        type: 'rider_agent',
        contactPerson: 'Kabiru Mohammed',
        phone: '+234 809 111 4455',
        email: 'ops@capitalexp.ng',
        deliveryFee: 2600.0,
        failedDeliveryFee: 1100.0,
        commissionRate: 6.0,
        assignedWarehouseId: 'DC-ABJ-01',
        assignedWarehouseName: 'Abuja Central DC',
        coverageStates: ['Abuja (FCT)', 'Nasarawa'],
        assignedMerchantIds: ['merchant-novacare'],
        assignedMerchantNames: ['Novacare Limited'],
      );

      // Register agent under Lagos Central DC
      await notifier.registerLogisticsAgent(
        name: 'Island Speedy Courier',
        agentCode: 'LAG-ISL-088',
        type: '3pl_partner',
        contactPerson: 'Sola Babatunde',
        phone: '+234 802 222 3344',
        email: 'ops@islandspeedy.ng',
        deliveryFee: 3100.0,
        failedDeliveryFee: 1300.0,
        commissionRate: 5.5,
        assignedWarehouseId: 'DC-LAG-01',
        assignedWarehouseName: 'Lagos Central DC',
        coverageStates: ['Lagos'],
      );

      final state = container.read(adminConsoleProvider);
      final abjAgent = state.agents.firstWhere((a) => a.agentCode == 'ABJ-EXP-099');
      final lagAgent = state.agents.firstWhere((a) => a.agentCode == 'LAG-ISL-088');

      expect(abjAgent.assignedWarehouseId, equals('DC-ABJ-01'));
      expect(abjAgent.commissionRate, equals(6.0));
      expect(abjAgent.assignedMerchantIds, contains('merchant-novacare'));

      expect(lagAgent.assignedWarehouseId, equals('DC-LAG-01'));
      expect(lagAgent.commissionRate, equals(5.5));
    });

    test('6. Merchant Inventory Portal scopes visible agents to assigned partners only', () {
      final adminContainer = ProviderContainer();
      addTearDown(adminContainer.dispose);

      final merchantContainer = ProviderContainer();
      addTearDown(merchantContainer.dispose);

      final adminState = adminContainer.read(adminConsoleProvider);
      final merchantNotifier = merchantContainer.read(merchantInventoryProvider.notifier);

      // Sync merchant inventory agents with the admin platform roster
      merchantNotifier.syncAgentsFromAdminRoster(adminState.agents);

      final merchantState = merchantContainer.read(merchantInventoryProvider);
      expect(merchantState.agents, isNotEmpty);

      // All visible agents in merchant inventory must be assigned to Novacare
      for (final agent in merchantState.agents) {
        expect(
          agent.assignedMerchantIds.contains('merchant-novacare') ||
              agent.assignedMerchantIds.contains(merchantState.merchantId) ||
              agent.assignedMerchantIds.contains('00000000-0000-4000-8000-791731264594'),
          isTrue,
          reason: 'Merchant should only see agents authorized and assigned to hold their products',
        );
      }
    });
  });
}
