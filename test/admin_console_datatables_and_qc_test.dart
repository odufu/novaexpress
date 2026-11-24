import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_agents_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_global_stock_tab.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_merchants_tab.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/admin_console/presentation/widgets/admin_inbound_qc_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';

void main() {
  group('Admin Console - Tabular Representation, Dynamic Filtering & QC Modals', () {
    test('1. Cross-relational filtering by Merchant narrows Stocks and Agents', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Verify initial state has multiple products and merchants
      var state = container.read(adminConsoleProvider);
      expect(state.globalStock.length, greaterThanOrEqualTo(3));
      expect(state.merchants, isNotEmpty);
      expect(state.agents, isNotEmpty);

      // NovaXpress Logistics internal fleet is verified as an agent
      final nxAgent = state.agents.firstWhere((a) => a.id == 'agent-novaxpress-logistics');
      expect(nxAgent.name, contains('NovaXpress Logistics'));

      // Filter Stock by merchant Novacare Limited ('merchant-novacare')
      notifier.setStockMerchantFilter('merchant-novacare');
      state = container.read(adminConsoleProvider);
      expect(state.filteredGlobalStock, isNotEmpty);
      expect(state.filteredGlobalStock.every((p) => p.merchantName.contains('Novacare')), isTrue);

      // Clear stock filter
      notifier.setStockMerchantFilter('all');
      state = container.read(adminConsoleProvider);
      expect(state.filteredGlobalStock.length, equals(state.globalStock.length));

      // Filter Agents by Merchant ('merchant-novacare')
      notifier.setAgentMerchantFilter('merchant-novacare');
      state = container.read(adminConsoleProvider);
      expect(state.filteredAgents, isNotEmpty);
      // Novacare uses NovaXpress, ADICHA, and Victor Ogbenyi
      expect(state.filteredAgents.any((a) => a.name.contains('NovaXpress')), isTrue);
      expect(state.filteredAgents.any((a) => a.name.contains('ADICHA')), isTrue);
      expect(state.filteredAgents.any((a) => a.name.contains('Victor Ogbenyi')), isTrue);
    });

    test('2. Inbound Batch & QC creates stock records and writes to immutable audit trail', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      final initialLogsCount = container.read(adminConsoleProvider).auditLogs.length;

      // Record QC inbound batch for Respira Lung Cleanse
      notifier.recordInboundBatchQA(
        sku: 'SKU-PRD-4412',
        producerName: 'PharmaBotanicals Nig Ltd',
        batchNumber: 'BATCH-2026-TEST-01',
        totalUnitsReceived: 1000,
        abujaSplit: 600,
        lagosSplit: 400,
        sampleUnitsTested: 50,
        colorDilationCheck: 'Passed: Uniform botanical pigmentation',
        grindConsistencyCheck: 'Passed: Optimal fine particle distribution',
        packagingCheck: 'Passed: Tamper-evident induction seal intact',
        overallQualityRating: 'Excellent',
        quarantinedUnits: 0,
        qcNotes: 'Passed all lab parameters with flying colors',
        inspectorName: 'Quality Lead Engr. Bello',
      );

      final state = container.read(adminConsoleProvider);
      expect(state.auditLogs.length, equals(initialLogsCount + 1));
      final latestLog = state.auditLogs.first;
      expect(latestLog.action, equals('INBOUND_BATCH_QC_INSPECTION'));
      expect(latestLog.details, contains('BATCH-2026-TEST-01'));
      expect(latestLog.details, contains('Excellent'));
    });

    test('3. Product Onboarding registers new SKU with merchant linkage and shelves', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);
      final initialProductCount = container.read(adminConsoleProvider).globalStock.length;

      notifier.onboardProduct(
        name: 'Herbal Liver Defense Tea',
        sku: 'SKU-PRD-NEW-99',
        merchantId: 'merchant-novacare',
        merchantName: 'Novacare Limited',
        unitPrice: 12000.0,
        abujaShelfQty: 500,
        lagosShelfQty: 300,
        kanoShelfQty: 100,
        initialAgentCustody: {
          'NovaXpress Logistics (Internal Fleet)': 100,
        },
      );

      final state = container.read(adminConsoleProvider);
      expect(state.globalStock.length, equals(initialProductCount + 1));
      expect(state.globalStock.any((p) => p.sku == 'SKU-PRD-NEW-99'), isTrue);
    });

    testWidgets('4. Desktop Viewport (>=900px) renders PangeaExcelDataTable for Stocks, Agents, and Merchants', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Verify AdminGlobalStockTab renders PangeaExcelDataTable with Agents in Rows and Products in Columns
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminGlobalStockTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PangeaExcelDataTable<AdminStockHolderRow>), findsOneWidget);
      expect(find.text('Inbound Batch & QC'), findsOneWidget);
      expect(find.text('Onboard Product'), findsOneWidget);
      expect(find.text('Agent / Stock Holder'), findsOneWidget);
      expect(find.text('PRODUCT QUANTITIES (UNITS)'), findsOneWidget);
      expect(find.text('VALUATION & AUDIT'), findsOneWidget);
      expect(find.text('Grazer Tea'), findsOneWidget);
      expect(find.text('Respira Tea'), findsOneWidget);

      // Verify AdminAgentsTab renders PangeaExcelDataTable
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminAgentsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PangeaExcelDataTable<AdminLogisticsAgent>), findsOneWidget);
      expect(find.text('Logistics Agent & Code'), findsOneWidget);
      expect(find.text('Held Custody'), findsOneWidget);
      expect(find.text('Stock Actions'), findsOneWidget);
      expect(find.text('Log Daily Balancing'), findsWidgets);

      // Verify AdminMerchantsTab renders PangeaExcelDataTable
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminMerchantsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PangeaExcelDataTable<AdminMerchant>), findsOneWidget);
      expect(find.text('Merchant Business'), findsOneWidget);
      expect(find.text('Products Distributed'), findsOneWidget);
      expect(find.text('Chosen Logistics Agents'), findsOneWidget);
      expect(find.text('Onboard Merchant'), findsOneWidget);
    });

    testWidgets('5. Mobile Viewport (<900px) falls back gracefully to responsive cards', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // On mobile, AdminGlobalStockTab shows responsive cards, not PangeaExcelDataTable
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminGlobalStockTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PangeaExcelDataTable<AdminStockHolderRow>), findsNothing);
      expect(find.text('Inbound Batch & QC'), findsOneWidget);
      expect(find.text('Onboard Product'), findsOneWidget);

      // On mobile, AdminAgentsTab shows responsive cards
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminAgentsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PangeaExcelDataTable<AdminLogisticsAgent>), findsNothing);
      expect(find.text('NovaXpress Logistics (Internal Fleet)'), findsOneWidget);
    });

    testWidgets('6. Inbound QC Modal dialog allows entering batch details and saving', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdminInboundQCModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inbound Batch Intake & Quality Assurance (QC)'), findsOneWidget);
      expect(find.text('Sample Tested Units'), findsNothing); // label text inside text field deco
      expect(find.text('Color Dilation Test'), findsOneWidget);
      expect(find.text('Grind / Texture Consistency'), findsOneWidget);
      expect(find.text('Packaging & Security Seal'), findsOneWidget);
      expect(find.text('Sign Off Batch & Onboard Stock'), findsOneWidget);
    });
  });
}
