import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_inventory_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserModel user)
      : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStockLedgerNotifier extends StateNotifier<ClientPortalState>
    implements ClientPortalNotifier {
  DateTime? lastReloadStartDate;
  DateTime? lastReloadEndDate;
  bool reloadCalled = false;

  MockStockLedgerNotifier(ClientPortalState initialState) : super(initialState);

  @override
  Future<void> loadClientData() async {}

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {
    reloadCalled = true;
    lastReloadStartDate = startDate;
    lastReloadEndDate = endDate;
  }

  @override
  String generateStockBalanceCsv() => 'Item,Warehouse,Balance Qty\nTEST,Stores - NL,100';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testUser = UserModel(
    id: 'user-01',
    email: 'orders@novacare.ng',
    firstName: 'Novacare',
    lastName: 'Admin',
    phone: '08099887766',
    role: 'client',
    clientId: 'cli-novacare',
    clientCompanyName: 'Novacare Ltd',
  );

  final testBalances = [
    ClientStockBalance(
      id: 'bal-1',
      clientId: 'cli-novacare',
      itemCode: 'SKU-RESP-01',
      itemName: 'Respira Detox Tea',
      itemGroup: 'Novacare',
      warehouse: 'Stores - NL',
      openingQty: 1000,
      openingValue: 2000000.0,
      inQty: 500,
      inValue: 1000000.0,
      outQty: 300,
      outValue: 600000.0,
      balanceQty: 1200,
      balanceValue: 2400000.0,
      valuationRate: 2000.0,
      reservedStock: 50,
      company: 'Novacare Ltd',
      stockUom: 'Nos',
      updatedAt: DateTime.now(),
    ),
    ClientStockBalance(
      id: 'bal-2',
      clientId: 'cli-novacare',
      itemCode: 'SKU-RESP-02',
      itemName: 'Respira Lungs Detox',
      itemGroup: 'Novacare',
      warehouse: 'Kennedy Orowo (Abuja Hub) - NL',
      openingQty: 60,
      openingValue: 120000.0,
      inQty: 20,
      inValue: 40000.0,
      outQty: 0,
      outValue: 0.0,
      balanceQty: 80,
      balanceValue: 160000.0,
      valuationRate: 2000.0,
      reservedStock: 0,
      company: 'Novacare Ltd',
      stockUom: 'Nos',
      updatedAt: DateTime.now(),
    ),
    ClientStockBalance(
      id: 'bal-3',
      clientId: 'cli-novacare',
      itemCode: 'SKU-RESP-03',
      itemName: 'Respira Cleanse Pack',
      itemGroup: 'Novacare',
      warehouse: 'Pelican Logistics Services Ltd - NL',
      openingQty: 200,
      openingValue: 400000.0,
      inQty: 100,
      inValue: 200000.0,
      outQty: 50,
      outValue: 100000.0,
      balanceQty: 250,
      balanceValue: 500000.0,
      valuationRate: 2000.0,
      reservedStock: 10,
      company: 'Novacare Ltd',
      stockUom: 'Nos',
      updatedAt: DateTime.now(),
    ),
  ];

  final initialState = ClientPortalState(
    isLoading: false,
    clientProfile: const ClientProfile(
      id: 'cli-novacare',
      companyName: 'Novacare Ltd',
      contactPerson: 'Director',
      email: 'orders@novacare.ng',
      phone: '08012345678',
      address: 'Abuja, Nigeria',
      hasInventoryManagement: true,
      servicesEnabled: ['fulfillment', 'delivery', 'inventory_management'],
    ),
    stockBalances: testBalances,
    suppliers: const [],
    stockInvoices: const [],
    orders: const [],
    products: const [],
    leads: const [],
  );

  testWidgets('Stock Ledger sub-tab renders PangeaExcelDataTable with gear settings, custody badges, and date filtering', (tester) async {
    tester.view.physicalSize = const Size(1440, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockNotifier = MockStockLedgerNotifier(initialState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          clientPortalProvider.overrideWith((ref) => mockNotifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ClientInventoryPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Page & Stock Ledger tab is visible
    expect(find.text('Inventory & Landed Cost Supply Chain'), findsOneWidget);
    expect(find.textContaining('Stock Ledger'), findsOneWidget);

    // 2. Verify PangeaExcelDataTable is used
    expect(find.byType(PangeaExcelDataTable<ClientStockBalance>), findsOneWidget);

    // 3. Verify Custody Badges
    expect(find.text('Central DC Store'), findsWidgets);
    expect(find.text('Rider Fleet Custody'), findsWidgets);
    expect(find.text('3PL Regional Hub'), findsWidgets);

    // 4. Verify Clean Warehouse Names
    expect(find.text('Central DC Stores (NL)'), findsWidgets);
    expect(find.text('Stores - NL'), findsWidgets);
    expect(find.textContaining('Kennedy Orowo'), findsWidgets);
    expect(find.textContaining('Pelican'), findsWidgets);

    // 5. Verify Column Headers
    expect(find.text('#'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Item Name'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Opening Qty'), findsOneWidget);
    expect(find.text('In Qty'), findsOneWidget);
    expect(find.text('Out Qty'), findsOneWidget);
    expect(find.text('Balance Qty'), findsOneWidget);
    expect(find.text('Valuation Rate'), findsOneWidget);
    expect(find.text('Balance Value'), findsOneWidget);

    // 6. Verify Top Toolbar has Gear Settings icon and tap opens settings modal
    final topGearButton = find.byKey(const ValueKey('pangea_table_top_settings_gear_btn'));
    expect(topGearButton, findsOneWidget);
    await tester.tap(topGearButton);
    await tester.pumpAndSettle();

    expect(find.byType(PangeaTableSettingsModal), findsOneWidget);
    expect(find.text('Table Display & Typography'), findsOneWidget);
    expect(find.text('Font Size & Scale'), findsOneWidget);

    // Close settings modal
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(PangeaTableSettingsModal), findsNothing);

    // 7. Verify Date Filter button is present
    final dateFilterButton = find.byIcon(Icons.calendar_month_rounded);
    expect(dateFilterButton, findsWidgets);

    // Tap Date Filter button
    await tester.tap(dateFilterButton.first);
    await tester.pumpAndSettle();

    // Verify Pangea Date Range Picker Modal opened
    expect(find.byType(PangeaDateRangePickerModal), findsOneWidget);
    expect(find.text('Dates are shown in Lagos Time'), findsOneWidget);

    // Tap "This month" preset
    final thisMonthPreset = find.text('This month');
    expect(thisMonthPreset, findsWidgets);
    await tester.tap(thisMonthPreset.first);
    await tester.pumpAndSettle();

    // Tap Update button
    final updateButton = find.text('Update');
    expect(updateButton, findsOneWidget);
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    // Verify reloadInventoryData was invoked with updated dates
    expect(mockNotifier.reloadCalled, isTrue);
    expect(mockNotifier.lastReloadStartDate, isNotNull);
    expect(mockNotifier.lastReloadEndDate, isNotNull);

    // 8. Tap a row to open the Stock Detail Inspection Modal
    await tester.tap(find.text('Respira Detox Tea').first);
    await tester.pumpAndSettle();

    expect(find.text('Inward Intake'), findsOneWidget);
    expect(find.text('Dispatched Outflow'), findsOneWidget);
    expect(find.text('Landed Cost (COGS)'), findsOneWidget);
    expect(find.text('Asset Valuation'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close inspection modal
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Inward Intake'), findsNothing);
  });
}
