import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/pages/tabs/admin_global_stock_tab.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';

void main() {
  group('Multi-Hub Stock Tab: Agents in Rows, Products in Columns', () {
    test('1. stockHolderRows generates DC shelves and all 114 CRM agents with product breakdown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(adminConsoleProvider);
      final holders = state.stockHolderRows;

      expect(holders, isNotEmpty);
      expect(holders.length, equals(115)); // 2 DC shelves + 113 merged real agents

      // Verify DC Warehouse Shelves
      final abujaShelf = holders.firstWhere((h) => h.id == 'shelf-dc-abuja');
      expect(abujaShelf.isDcShelf, isTrue);
      expect(abujaShelf.name, contains('Abuja Central DC'));
      expect(abujaShelf.quantityForSku('NOVA-GRAZER-01'), equals(1450));
      expect(abujaShelf.quantityForSku('NOVA-RESPIRA-02'), equals(980));
      expect(abujaShelf.quantityForSku('NOVA-URACLR-03'), equals(750));
      expect(abujaShelf.totalUnits, equals(4210));

      final lagosShelf = holders.firstWhere((h) => h.id == 'shelf-dc-lagos');
      expect(lagosShelf.isDcShelf, isTrue);
      expect(lagosShelf.name, contains('Lagos Central DC'));
      expect(lagosShelf.quantityForSku('NOVA-GRAZER-01'), equals(2350));
      expect(lagosShelf.quantityForSku('NOVA-RESPIRA-02'), equals(1620));
      expect(lagosShelf.quantityForSku('NOVA-URACLR-03'), equals(1240));
      expect(lagosShelf.totalUnits, equals(7200));

      // Verify NovaXpress Logistics Fleet (Abuja Central DC)
      final nxAgent = holders.firstWhere((h) => h.id == 'agent-novaxpress-logistics');
      expect(nxAgent.isInternalFleet, isTrue);
      expect(nxAgent.hubName, contains('Abuja Central DC'));
      expect(nxAgent.quantityForSku('NOVA-GRAZER-01'), equals(180));
      expect(nxAgent.quantityForSku('NOVA-RESPIRA-02'), equals(110));
      expect(nxAgent.quantityForSku('NOVA-URACLR-03'), equals(75));
      expect(nxAgent.quantityForSku('SH11-SHAMP-01'), equals(90));
      expect(nxAgent.quantityForSku('SH11-VEST-02'), equals(50));
      expect(nxAgent.totalUnits, equals(505));

      // Verify ADICHA LOGISTICS (Real Lagos 3PL Partner)
      final adichaAgent = holders.firstWhere((h) => h.id == 'agent-adicha-logistics');
      expect(adichaAgent.is3pl, isTrue);
      expect(adichaAgent.quantityForSku('NOVA-GRAZER-01'), equals(150));
      expect(adichaAgent.quantityForSku('NOVA-RESPIRA-02'), equals(80));
      expect(adichaAgent.totalUnits, equals(380));

      // Verify Victor Ogbenyi Logistics (Real Lagos 3PL Partner)
      final ogbenyiAgent = holders.firstWhere((h) => h.id == 'agent-victor-ogbenyi-logistics');
      expect(ogbenyiAgent.is3pl, isTrue);
      expect(ogbenyiAgent.quantityForSku('NOVA-GRAZER-01'), equals(95));
      expect(ogbenyiAgent.quantityForSku('NOVA-RESPIRA-02'), equals(60));
      expect(ogbenyiAgent.totalUnits, equals(185));

      // Reconciled Total Stock
      final totalShelves = abujaShelf.totalUnits + lagosShelf.totalUnits;
      expect(totalShelves, equals(11410));
      final totalAgentCustody = nxAgent.totalUnits + adichaAgent.totalUnits + ogbenyiAgent.totalUnits;
      expect(totalAgentCustody, equals(1070));
      expect(totalShelves + totalAgentCustody, equals(12480));
    });

    test('2. Filter by DC Hub: Abuja includes NovaXpress; Lagos strictly excludes NovaXpress fleet', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Filter by Abuja
      notifier.setStockHubFilter('Abuja');
      var state = container.read(adminConsoleProvider);
      var abujaRows = state.filteredStockHolderRows;

      expect(abujaRows.any((r) => r.id == 'shelf-dc-abuja'), isTrue);
      expect(abujaRows.any((r) => r.id == 'shelf-dc-lagos'), isFalse);
      expect(abujaRows.any((r) => r.id == 'agent-novaxpress-logistics'), isTrue);

      // Filter by Lagos
      notifier.setStockHubFilter('Lagos');
      state = container.read(adminConsoleProvider);
      var lagosRows = state.filteredStockHolderRows;

      expect(lagosRows.any((r) => r.id == 'shelf-dc-lagos'), isTrue);
      expect(lagosRows.any((r) => r.id == 'shelf-dc-abuja'), isFalse);
      // Strictly excludes NovaXpress Logistics fleet from Lagos
      expect(lagosRows.any((r) => r.id == 'agent-novaxpress-logistics'), isFalse);
      // Includes 3PL partners like ADICHA LOGISTICS
      expect(lagosRows.any((r) => r.id == 'agent-adicha-logistics'), isTrue);
    });

    test('3. Filter by Merchant scopes products and assigned agents', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminConsoleProvider.notifier);

      // Filter by Shop Eleven Limited
      notifier.setStockMerchantFilter('merchant-shop11');
      var state = container.read(adminConsoleProvider);

      expect(state.filteredGlobalStock.length, equals(2));
      expect(state.filteredGlobalStock.every((p) => p.merchantName.contains('Shop Eleven')), isTrue);

      // Filter by Novacare Limited
      notifier.setStockMerchantFilter('merchant-novacare');
      state = container.read(adminConsoleProvider);

      expect(state.filteredGlobalStock.length, equals(3));
      expect(state.filteredGlobalStock.every((p) => p.merchantName.contains('Novacare')), isTrue);
    });

    testWidgets('4. Desktop Viewport renders DataTable with Agents in rows and Products in columns', (tester) async {
      tester.view.physicalSize = const Size(1600, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminGlobalStockTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // DataTable is rendered with AdminStockHolderRow
      expect(find.byType(PangeaExcelDataTable<AdminStockHolderRow>), findsOneWidget);

      // Headers: Agent / Stock Holder in row info, Product columns
      expect(find.text('Agent / Stock Holder'), findsOneWidget);
      expect(find.text('Custodian Type'), findsOneWidget);
      expect(find.text('Operating Hub'), findsOneWidget);
      expect(find.text('PRODUCT QUANTITIES (UNITS)'), findsOneWidget);
      expect(find.text('VALUATION & AUDIT'), findsOneWidget);
      expect(find.text('Total Custody'), findsOneWidget);
      expect(find.text('Stock Value (₦)'), findsOneWidget);

      // Product columns rendered
      expect(find.text('Grazer Tea'), findsOneWidget);
      expect(find.text('Respira Tea'), findsOneWidget);
      expect(find.text('Ura Clear'), findsOneWidget);
      expect(find.text('Hair Shampoo'), findsOneWidget);
      expect(find.text('Compress Vest'), findsOneWidget);

      // Rows contain DC Shelves and Agents
      expect(find.text('Abuja Central DC (Warehouse Shelf)'), findsOneWidget);
      expect(find.text('Lagos Central DC (Warehouse Shelf)'), findsOneWidget);
      expect(find.text('NovaXpress Logistics (Internal Fleet)'), findsOneWidget);
      expect(find.text('RAPH XPRESS LOGISTICS'), findsOneWidget);

      // KPI banner cards
      expect(find.text('Total Network Stock'), findsOneWidget);
      expect(find.text('12480'), findsOneWidget);
      expect(find.text('DC Warehouse Shelves'), findsOneWidget);
      expect(find.text('11410'), findsOneWidget);
      expect(find.text('Agent Fleet Custody'), findsOneWidget);
      expect(find.text('1070'), findsOneWidget);
    });
  });
}
