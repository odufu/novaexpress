import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/admin_console/presentation/pages/admin_console_layout.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_agents_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_distribution_centers_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_global_stock_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_merchants_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_warehouse_expenses_tab.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Grand NovaXpress Console - 5 Viewpoint Tabs & Features', () {
    test('1. AdminConsoleState manages the 5 viewpoints with rich initial seed data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(adminConsoleProvider);
      final notifier = container.read(adminConsoleProvider.notifier);

      // Viewpoint 1: Agents holding stock with flat-rate fees
      expect(state.agents, isNotEmpty);
      final nxAgent = state.agents.firstWhere((a) => a.id == 'agent-novaxpress-logistics');
      expect(nxAgent.deliveryFee, equals(2500.0));
      expect(nxAgent.failedDeliveryFee, equals(1000.0));
      expect(nxAgent.heldStock, isNotEmpty);
      expect(nxAgent.assignedWarehouseId, contains('DC-ABJ'));

      // Viewpoint 2: Products and multi-hub + agent stock breakdown
      expect(state.globalStock, isNotEmpty);
      final uraStock = state.globalStock.firstWhere((g) => g.sku == 'SKU-PRD-6731');
      expect(uraStock.dcStockBreakdown, isNotEmpty);

      // Viewpoint 3: Merchants with chosen agents & distributed products
      expect(state.merchants, isNotEmpty);

      // Viewpoint 4: Distribution Centers & working agents
      expect(state.distributionCenters, isNotEmpty);
      final grandDc = state.distributionCenters.firstWhere((d) => d.isGrandDc);
      expect(grandDc.code, contains('DC'));

      // Viewpoint 5: Warehouse Expenses
      expect(state.expenses, isNotEmpty);
      expect(state.expenses.any((e) => e.category == 'diesel_generator'), isTrue);
      expect(state.expenses.any((e) => e.warehouseId.contains('DC-ABJ')), isTrue);
    });

    test('2. Agent daily stock balancing syncs physical count and platform stock', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Record daily physical balance for NovaXpress Logistics
      final res = await notifier.recordAgentDailyBalance(
        agentId: 'agent-novaxpress-logistics',
        confirmedStock: {
          'URA Clear': 100,
          'Grazer Herbal Detox Tea': 50,
        },
        notes: 'End-of-day physical audit confirmed',
      );

      expect(res['success'], isTrue);

      final updatedState = container.read(adminConsoleProvider);
      final updatedAgent = updatedState.agents.firstWhere((a) => a.id == 'agent-novaxpress-logistics');
      expect(updatedAgent.heldStock['URA Clear'], equals(100));
      expect(updatedAgent.heldStock['Grazer Herbal Detox Tea'], equals(50));
      expect(updatedAgent.lastBalancedAt, isNotNull);

      // Check global stock was also updated
      final updatedUra = updatedState.globalStock.firstWhere((g) => g.productName.contains('URA Clear'));
      expect(updatedUra.agentStockBreakdown['NovaXpress Logistics (Internal Fleet)'], equals(100));
    });

    test('3. Registering a new agent sets custom delivery and failed delivery fees', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      await notifier.registerLogisticsAgent(
        name: 'Kano Express Couriers',
        agentCode: 'KEC-3PL-99',
        type: '3pl_partner',
        contactPerson: 'Murtala Mohammed',
        phone: '+234 803 999 8877',
        email: 'dispatch@kanoexpress.ng',
        deliveryFee: 2200.0,
        failedDeliveryFee: 800.0,
        assignedWarehouseId: 'DC-KAN-04',
        assignedWarehouseName: 'Kano Northern Hub',
        coverageStates: ['Kano', 'Jigawa'],
      );

      final state = container.read(adminConsoleProvider);
      final newAgent = state.agents.firstWhere((a) => a.agentCode == 'KEC-3PL-99');
      expect(newAgent.name, equals('Kano Express Couriers'));
      expect(newAgent.deliveryFee, equals(2200.0));
      expect(newAgent.failedDeliveryFee, equals(800.0));
      expect(newAgent.assignedWarehouseId, equals('DC-KAN-04'));
      expect(newAgent.coverageStates, contains('Kano'));
    });

    test('4. Recording warehouse expense updates station expense log and audit trail', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      await notifier.recordWarehouseExpense(
        warehouseId: 'DC-ABJ-02',
        warehouseName: 'Abuja Regional Gateway (Idu)',
        title: 'Emergency Generator Oil Filter Replacement',
        category: 'diesel_generator',
        amount: 35000.0,
        recordedBy: 'Station Head (Abuja)',
        receiptNumber: 'RCP-EMG-1029',
        notes: 'Cold storage backup maintenance',
      );

      final state = container.read(adminConsoleProvider);
      final expense = state.expenses.firstWhere((e) => e.receiptNumber == 'RCP-EMG-1029');
      expect(expense.amount, equals(35000.0));
      expect(expense.warehouseName, contains('Abuja'));
      expect(expense.category, equals('diesel_generator'));

      // Filter by warehouse
      notifier.setExpenseWarehouseFilter('DC-ABJ-02');
      final filteredState = container.read(adminConsoleProvider);
      expect(filteredState.filteredExpenses.every((e) => e.warehouseId == 'DC-ABJ-02'), isTrue);
    });

    testWidgets('5. AdminConsoleLayout tabs switch cleanly between the 5 viewpoints', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(adminConsoleProvider.notifier).loadAll();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdminConsoleLayout(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Viewpoint 1: Tab 0 Agents & 3PLs is active by default
      expect(find.text('Agents & 3PLs'), findsWidgets);
      expect(find.text('NovaXpress Logistics (Internal Fleet)'), findsOneWidget);
      expect(find.text('Add Logistics Partner'), findsOneWidget);

      // Switch to Tab 1: Multi-Hub Stock
      await tester.tap(find.text('Multi-Hub Stock').first);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Inbound QC'), findsOneWidget);
      expect(find.text('Agent / Stock Holder'), findsOneWidget);

      // Switch to Tab 2: Merchants & Partners
      await tester.tap(find.text('Merchants & Partners').first);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Products Distributed'), findsOneWidget);
      expect(find.text('Chosen Logistics Agents'), findsOneWidget);

      // Switch to Tab 3: Warehouses & Branches
      await tester.tap(find.text('Warehouses & Branches').first);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Active Fleet (Dispatch Ops)'), findsOneWidget);

      // Switch to Tab 4: Users & RBAC
      await tester.tap(find.text('Users & RBAC').first);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('User Profile'), findsWidgets);
    });
  });
}
