import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Agent Merchant Assignment Persistence Across Refresh Tests', () {
    test('1. Assigning merchants to an agent persists across loadAll (simulated page refresh)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      final testAgentId = 'agent-adicha-logistics';

      // Assign Adicha Logistics to Novacare and Shop Eleven
      await notifier.assignAgentToMerchants(
        agentId: testAgentId,
        merchantIds: ['merchant-novacare', 'merchant-shop11'],
        merchantNames: ['Novacare Limited', 'Shop Eleven Limited'],
      );

      var state = container.read(adminConsoleProvider);
      final agentBeforeReload = state.agents.firstWhere((a) => a.id == testAgentId);
      expect(agentBeforeReload.assignedMerchantIds, contains('merchant-novacare'));
      expect(agentBeforeReload.assignedMerchantIds, contains('merchant-shop11'));

      // Verify that SharedPreferences cache was written
      final prefs = await SharedPreferences.getInstance();
      final masterRaw = prefs.getString('nova_all_agent_merchants');
      expect(masterRaw, isNotNull);
      final masterMap = jsonDecode(masterRaw!) as Map<String, dynamic>;
      expect(masterMap.containsKey(agentBeforeReload.agentCode), isTrue);
      final cachedList = (masterMap[agentBeforeReload.agentCode] as List).cast<String>();
      expect(cachedList, contains('merchant-novacare'));
      expect(cachedList, contains('merchant-shop11'));

      // Simulate browser refresh / page reload by calling loadAll()
      await notifier.loadAll();

      state = container.read(adminConsoleProvider);
      final agentAfterReload = state.agents.firstWhere((a) => a.id == testAgentId);

      // Verify agent viewpoints retain the assignment
      expect(agentAfterReload.assignedMerchantIds, contains('merchant-novacare'));
      expect(agentAfterReload.assignedMerchantIds, contains('merchant-shop11'));
      expect(agentAfterReload.assignedMerchantNames, contains('Novacare Limited'));
      expect(agentAfterReload.assignedMerchantNames, contains('Shop Eleven Limited'));

      // Verify Multi-Hub Stock Holder row retains the assignment
      final stockRow = state.stockHolderRows.firstWhere((r) => r.id == testAgentId);
      expect(stockRow.assignedMerchantNames, contains('Novacare Limited'));
      expect(stockRow.assignedMerchantNames, contains('Shop Eleven Limited'));

      // Verify Merchant viewpoints retain the assignment in chosen logistics agents
      final novacare = state.merchants.firstWhere((m) => m.id == 'merchant-novacare');
      expect(novacare.assignedAgentIds, contains(testAgentId));
      expect(novacare.assignedAgentNames, contains(agentAfterReload.name));

      final shop11 = state.merchants.firstWhere((m) => m.id == 'merchant-shop11');
      expect(shop11.assignedAgentIds, contains(testAgentId));
      expect(shop11.assignedAgentNames, contains(agentAfterReload.name));
    });

    test('2. Unassigning merchant and reloading keeps the merchant unassigned', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      final testAgentId = 'agent-victor-ogbenyi-logistics';

      // 1. Initial assignment
      await notifier.assignAgentToMerchants(
        agentId: testAgentId,
        merchantIds: ['merchant-novacare', 'merchant-shop11'],
        merchantNames: ['Novacare Limited', 'Shop Eleven Limited'],
      );

      // 2. Unassign from Shop Eleven
      await notifier.unassignAgentFromMerchant(
        agentId: testAgentId,
        merchantId: 'merchant-shop11',
      );

      // 3. Simulate browser refresh
      await notifier.loadAll();

      final state = container.read(adminConsoleProvider);
      final agent = state.agents.firstWhere((a) => a.id == testAgentId);

      expect(agent.assignedMerchantIds.contains('merchant-shop11'), isFalse);
      expect(agent.assignedMerchantIds.contains('merchant-novacare'), isTrue);

      // Verify merchant viewpoint
      final shop11 = state.merchants.firstWhere((m) => m.id == 'merchant-shop11');
      expect(shop11.assignedAgentIds.contains(testAgentId), isFalse);
    });
  });
}
