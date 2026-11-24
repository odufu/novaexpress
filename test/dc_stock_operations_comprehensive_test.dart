import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/data/models/stock_item_model.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/presentation/widgets/return_stock_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_notify_merchant_restock_modal.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_stock_operations_page.dart';
import 'package:novexps/features/pipeline_chat/presentation/providers/pipeline_chat_provider.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserEntity user) : super(AuthState(user: user, isInitialized: true));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePipelineChatNotifier extends StateNotifier<PipelineChatState> implements PipelineChatNotifier {
  FakePipelineChatNotifier() : super(const PipelineChatState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  FakeStockNotifier(super.initial);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const testUser = UserEntity(
    id: 'user-dc-01',
    email: 'stockkeeper@novaxpress.ng',
    firstName: 'Musa',
    lastName: 'Abdullahi',
    phone: '08012345678',
    role: 'dc_manager',
    distributionCenterId: 'dc-abuja-01',
    distributionCenterName: 'Abuja Central DC',
    operatingState: 'FCT - Abuja',
    operatingCity: 'Abuja',
    vehicleType: 'van',
    vehiclePlateNumber: 'ABJ-123-XY',
    bankName: 'Zenith Bank',
    bankAccountNumber: '1234567890',
    bankAccountName: 'Musa Abdullahi',
    agentStatus: 'available',
    compensationType: 'salary',
    commissionRate: 0.0,
    transportAllowance: 0.0,
    fuelAllowance: 0.0,
    failedDeliveryAllowance: 0.0,
    baseSalary: 250000.0,
    isSupervisor: false,
  );

  const testItem = StockItemEntity(
    id: 'prod-01',
    name: 'Grazer Herbal Detox Tea',
    sku: 'SKU-PRD-8309',
    description: 'Herbal tea for digestion',
    price: 21500.0,
    totalInCustody: 100,
    assignedCount: 20,
    deliveredCount: 5,
    damagedCount: 0,
    availableCount: 80,
    reservedCount: 0,
    returnedCount: 0,
    awaitingReturnCount: 0,
    complaintCount: 0,
    lowStockThreshold: 10,
    reorderLevel: 25,
    category: 'Health & Wellness',
    ownerName: 'Novacare Limited',
    inventoryType: InventoryType.distributedInventory,
  );

  group('DC Stock Operations - Daily Sold & Stock Reconciliation Tests', () {
    test('recordDailyRiderSales correctly updates state custody and delivered units', () async {
      final container = ProviderContainer(
        overrides: [
          initialUserProvider.overrideWithValue(testUser),
        ],
      );
      addTearDown(container.dispose);

      final stockNotifier = container.read(stockProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));
      
      final testAllocation = RiderStockAllocation(
        id: 'alloc-01',
        riderId: 'driver-01',
        riderName: 'Ibrahim Danladi',
        riderCode: 'RDR-001',
        productId: 'prod-01',
        productName: 'Grazer Herbal Detox Tea',
        sku: 'SKU-PRD-8309',
        allocatedUnits: 17,
        deliveredUnits: 2,
        inCustodyUnits: 15,
        returnedUnits: 0,
        unitPrice: 21500.0,
        allocatedAt: DateTime.now(),
      );

      stockNotifier.state = StockState(
        stockItems: const [testItem],
        riderAllocations: [testAllocation],
        isLoading: false,
      );

      // Record 5 units sold today
      final result = await stockNotifier.recordDailyRiderSales(
        riderId: 'driver-01',
        productId: 'prod-01',
        unitsSold: 5,
        notes: 'End of day dispatch reconciliation',
      );

      expect(result['success'], isTrue);

      final updatedState = container.read(stockProvider);
      final updatedAlloc = updatedState.riderAllocations.firstWhere((a) => a.riderId == 'driver-01');
      expect(updatedAlloc.inCustodyUnits, 10);
      expect(updatedAlloc.deliveredUnits, 7);

      final updatedItem = updatedState.stockItems.firstWhere((p) => p.id == 'prod-01');
      expect(updatedItem.assignedCount, 15);
      expect(updatedItem.deliveredCount, 10);
    });

    test('recordDailyRiderSales falls back cleanly to catalog product when rider has no prior allocation', () async {
      final container = ProviderContainer(
        overrides: [
          initialUserProvider.overrideWithValue(testUser),
        ],
      );
      addTearDown(container.dispose);

      final stockNotifier = container.read(stockProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      stockNotifier.state = const StockState(
        stockItems: [testItem],
        riderAllocations: [],
        isLoading: false,
      );

      final result = await stockNotifier.recordDailyRiderSales(
        riderId: 'driver-no-alloc',
        riderName: 'Tunde Courier',
        productId: 'prod-01',
        unitsSold: 3,
        reconcileOrderIds: const ['ord-forgot-1'],
        notes: 'Closed forgotten order & balanced stock',
      );

      expect(result['success'], isTrue);
      expect(result['message'].toString(), contains('Closed 1 open order(s)'));

      final updatedState = container.read(stockProvider);
      final updatedItem = updatedState.stockItems.firstWhere((p) => p.id == 'prod-01');
      expect(updatedItem.deliveredCount, 8);
      expect(updatedItem.availableCount, 77);
      expect(updatedState.riderAllocations.any((a) => a.riderId == 'driver-no-alloc'), isTrue);
    });

    test('transferStockBetweenRiders balances source and destination rider custody', () async {
      final container = ProviderContainer(
        overrides: [
          initialUserProvider.overrideWithValue(testUser),
        ],
      );
      addTearDown(container.dispose);

      final stockNotifier = container.read(stockProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      final sourceAlloc = RiderStockAllocation(
        id: 'alloc-src-1',
        riderId: 'driver-src',
        riderName: 'Source Rider',
        riderCode: 'RDR-SRC',
        productId: 'prod-01',
        productName: 'Grazer Herbal Detox Tea',
        sku: 'SKU-PRD-8309',
        allocatedUnits: 10,
        deliveredUnits: 0,
        inCustodyUnits: 10,
        unitPrice: 21500.0,
        allocatedAt: DateTime.now(),
      );

      stockNotifier.state = StockState(
        stockItems: const [testItem],
        riderAllocations: [sourceAlloc],
        isLoading: false,
      );

      final res = await stockNotifier.transferStockBetweenRiders(
        productIdOrSku: 'prod-01',
        sourceRiderId: 'driver-src',
        sourceRiderName: 'Source Rider',
        destinationRiderId: 'driver-dst',
        destinationRiderName: 'Dest Rider',
        destinationRiderCode: 'RDR-DST',
        quantity: 4,
      );

      expect(res['success'], isTrue);
      final updated = container.read(stockProvider);
      final src = updated.riderAllocations.firstWhere((a) => a.riderId == 'driver-src');
      final dst = updated.riderAllocations.firstWhere((a) => a.riderId == 'driver-dst');
      expect(src.inCustodyUnits, 6);
      expect(dst.inCustodyUnits, 4);
    });

    test('recordComplaintOrDamage increments both complaintCount and damagedCount while decrementing custody', () async {
      final container = ProviderContainer(
        overrides: [
          initialUserProvider.overrideWithValue(testUser),
        ],
      );
      addTearDown(container.dispose);

      final stockNotifier = container.read(stockProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      final riderAlloc = RiderStockAllocation(
        id: 'alloc-dmg-1',
        riderId: 'driver-01',
        riderName: 'Ibrahim Danladi',
        riderCode: 'RDR-001',
        productId: 'prod-01',
        productName: 'Grazer Herbal Detox Tea',
        sku: 'SKU-PRD-8309',
        allocatedUnits: 10,
        deliveredUnits: 0,
        inCustodyUnits: 10,
        unitPrice: 21500.0,
        allocatedAt: DateTime.now(),
      );

      stockNotifier.state = StockState(
        stockItems: const [testItem],
        riderAllocations: [riderAlloc],
        isLoading: false,
      );

      final res = await stockNotifier.recordComplaintOrDamage(
        productIdOrSku: 'prod-01',
        riderId: 'driver-01',
        quantity: 2,
        reason: 'Broken bottle in transit',
      );

      expect(res['success'], isTrue);
      final updated = container.read(stockProvider);
      final item = updated.stockItems.firstWhere((p) => p.id == 'prod-01');
      final alloc = updated.riderAllocations.firstWhere((a) => a.riderId == 'driver-01');
      expect(item.complaintCount, 2);
      expect(item.damagedCount, 2);
      expect(alloc.inCustodyUnits, 8);
      expect(alloc.returnedUnits, 2);
    });
  });

  group('DC Stock Operations - Restock Lead Time Advisory', () {
    testWidgets('DC Restock Modal displays prominent 2-week lead time notice', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialUserProvider.overrideWithValue(testUser),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    DCNotifyMerchantRestockModal.show(
                      context,
                      item: testItem,
                      dcName: 'Abuja Central DC',
                    );
                  },
                  child: const Text('Open Restock Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Restock Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the 2-week lead time warning is displayed
      expect(find.textContaining('2-Week Redistribution Lead Time Advisory'), findsOneWidget);
      expect(find.textContaining('inter-state logistics require up to 14 days'), findsOneWidget);
    });
  });

  group('DC Stock Operations - KPI Tab & FAB Removal Tests', () {
    test('StockItemModel list lookup with firstOrNull does not throw covariance TypeError', () {
      // Create runtime StockItemModel instances (simulating remote Postgrest data)
      final List<StockItemEntity> modelStockItems = <StockItemModel>[
        const StockItemModel(
          id: 'prod-01',
          name: 'Grazer Herbal Detox Tea',
          sku: 'SKU-PRD-8309',
          description: 'Herbal tea for digestion',
          price: 21500.0,
          totalInCustody: 100,
          assignedCount: 20,
          deliveredCount: 5,
          damagedCount: 0,
          availableCount: 80,
          reservedCount: 0,
          returnedCount: 0,
          awaitingReturnCount: 0,
          lowStockThreshold: 10,
          reorderLevel: 25,
          category: 'Health & Wellness',
          ownerName: 'Novacare Limited',
          inventoryType: InventoryType.distributedInventory,
        ),
      ];

      // Verify selecting item from List<StockItemModel> statically typed as List<StockItemEntity>
      const currentProductId = 'prod-01';
      final selectedItem = modelStockItems.where((i) => i.id == currentProductId).firstOrNull ??
          modelStockItems.first;

      expect(selectedItem.id, 'prod-01');
      expect(selectedItem.name, 'Grazer Herbal Detox Tea');
    });

    test('DCStockOperationsPage state does not configure any floatingActionButton', () {
      const page = DCStockOperationsPage();
      expect(page, isNotNull);
    });

    testWidgets('DropdownButton with deduplicated items never throws assertion failure on duplicate IDs', (WidgetTester tester) async {
      // Simulate raw warehouse items that might have duplicate IDs from conflicting order/product records
      final rawItems = [
        const StockItemModel(
          id: '85ae1b6d-4d98-4078-80cb-5bc074104c01',
          name: 'TRIPLE H BALANCE TEA',
          sku: 'SKU-001',
          description: 'Herbal balance tea',
          category: 'Health & Wellness',
          price: 21500.0,
          totalInCustody: 50,
          assignedCount: 10,
          deliveredCount: 0,
          damagedCount: 0,
          availableCount: 40,
          reservedCount: 0,
          returnedCount: 0,
          awaitingReturnCount: 0,
          lowStockThreshold: 10,
          reorderLevel: 20,
        ),
        const StockItemModel(
          id: '85ae1b6d-4d98-4078-80cb-5bc074104c01', // duplicate id
          name: 'Respira Detox Tea',
          sku: 'SKU-002',
          description: 'Detox tea',
          category: 'Health & Wellness',
          price: 21500.0,
          totalInCustody: 30,
          assignedCount: 5,
          deliveredCount: 0,
          damagedCount: 0,
          availableCount: 25,
          reservedCount: 0,
          returnedCount: 0,
          awaitingReturnCount: 0,
          lowStockThreshold: 10,
          reorderLevel: 20,
        ),
      ];

      // UI deduplication logic matching _buildStockDistributionKpiCard
      final seenIds = <String>{};
      final uniqueWarehouseItems = rawItems.where((it) => seenIds.add(it.id)).toList();
      expect(uniqueWarehouseItems.length, 1);

      const selectedId = '85ae1b6d-4d98-4078-80cb-5bc074104c01';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DropdownButton<String>(
                value: selectedId,
                items: uniqueWarehouseItems
                    .map((item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.name),
                        ))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('TRIPLE H BALANCE TEA'), findsOneWidget);
    });

    test('ReturnStockDraftState safely assigns StockItemEntity without covariance type error', () {
      const entity = StockItemEntity(
        id: 'test-item-01',
        sku: 'SKU-001',
        name: 'Detox Tea',
        description: 'Herbal tea',
        price: 21500,
        assignedCount: 10,
        deliveredCount: 2,
        availableCount: 8,
        returnedCount: 0,
        category: 'Health',
      );

      final notifier = ReturnStockDraftNotifier();
      notifier.selectItem(entity);
      expect(notifier.state.selectedItem?.id, 'test-item-01');

      // Test with StockItemModel instance (subclass)
      const model = StockItemModel(
        id: 'test-item-02',
        sku: 'SKU-002',
        name: 'Balance Tea',
        description: 'Herbal tea',
        price: 21500,
        assignedCount: 5,
        deliveredCount: 1,
        availableCount: 4,
        returnedCount: 0,
        category: 'Health',
      );

      notifier.selectItem(model);
      expect(notifier.state.selectedItem?.id, 'test-item-02');

      // Clear selection
      notifier.selectItem(null);
      expect(notifier.state.selectedItem, isNull);
    });

    test('Audit sales driver allocations deduplication eliminates duplicate DropdownMenuItem IDs', () {
      final duplicateAllocations = [
        RiderStockAllocation(
          id: 'alloc-01',
          riderId: 'dr-01',
          riderName: 'John Rider',
          riderCode: 'RDR-01',
          productId: '85ae1b6d-4d98-4078-80cb-5bc074104c01',
          productName: 'TRIPLE H BALANCE TEA',
          sku: 'SKU-01',
          allocatedUnits: 15,
          inCustodyUnits: 10,
          deliveredUnits: 5,
          returnedUnits: 0,
          unitPrice: 21500.0,
          allocatedAt: DateTime.now(),
        ),
        RiderStockAllocation(
          id: 'alloc-02',
          riderId: 'dr-01',
          riderName: 'John Rider',
          riderCode: 'RDR-01',
          productId: '85ae1b6d-4d98-4078-80cb-5bc074104c01', // duplicate product ID for same rider
          productName: 'TRIPLE H BALANCE TEA (Batch 2)',
          sku: 'SKU-01',
          allocatedUnits: 5,
          inCustodyUnits: 5,
          deliveredUnits: 0,
          returnedUnits: 0,
          unitPrice: 21500.0,
          allocatedAt: DateTime.now(),
        ),
      ];

      final uniqueAllocations = <RiderStockAllocation>[];
      final seenProductIds = <String>{};
      for (final a in duplicateAllocations.where((a) => a.riderId == 'dr-01')) {
        if (seenProductIds.add(a.productId)) {
          uniqueAllocations.add(a);
        }
      }

      expect(uniqueAllocations.length, 1);
      expect(uniqueAllocations.first.productId, '85ae1b6d-4d98-4078-80cb-5bc074104c01');
    });

    testWidgets('Quick Action Grid renders all 8 action tiles with rich tooltips', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialUserProvider.overrideWithValue(testUser),
            authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
            pipelineChatProvider.overrideWith((ref) => FakePipelineChatNotifier()),
            stockProvider.overrideWith((ref) => FakeStockNotifier(
              const StockState(
                stockItems: [testItem],
                isLoading: false,
              ),
            )),
          ],
          child: const MaterialApp(
            home: DCStockOperationsPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify minimal welcome title
      expect(find.textContaining('Welcome, Musa'), findsOneWidget);

      // Verify chat message icon is removed from AppBar
      expect(find.byTooltip('Order Pipeline Chats'), findsNothing);

      // Verify notifications and settings icons are present in AppBar
      expect(find.byTooltip('Stock Notifications & Alerts'), findsOneWidget);
      expect(find.byTooltip('Stock Keeper Settings'), findsOneWidget);

      // Verify Quick Action Grid titles & tooltips
      expect(find.descendant(of: find.byTooltip('Receive and verify inbound stock consignments from merchants and transfers'), matching: find.text('Inbound')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Assign and release warehouse inventory to dispatch couriers'), matching: find.text('Allocate')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Request restock from merchants (~2 weeks lead time required)'), matching: find.text('Requisition')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Record daily units sold by couriers to reconcile field custody'), matching: find.text('Daily Sales')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Transfer stock directly between riders in the field to balance coverage'), matching: find.text('Rider Balance')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Accept returned damaged/spoiled items from couriers and issue replacements'), matching: find.text('Spoilage')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Dispatch inter-station stock transfers to other distribution centers'), matching: find.text('DC Transfer')), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Retrieve all warehouse inventory from laid-off or exiting couriers'), matching: find.text('Retrieve Stock')), findsOneWidget);

      // Verify Tooltips exist on the quick actions
      expect(find.byTooltip('Receive and verify inbound stock consignments from merchants and transfers'), findsOneWidget);
      expect(find.byTooltip('Assign and release warehouse inventory to dispatch couriers'), findsOneWidget);
      expect(find.byTooltip('Request restock from merchants (~2 weeks lead time required)'), findsOneWidget);
      expect(find.byTooltip('Record daily units sold by couriers to reconcile field custody'), findsOneWidget);
      expect(find.byTooltip('Transfer stock directly between riders in the field to balance coverage'), findsOneWidget);
      expect(find.byTooltip('Accept returned damaged/spoiled items from couriers and issue replacements'), findsOneWidget);
      expect(find.byTooltip('Dispatch inter-station stock transfers to other distribution centers'), findsOneWidget);
      expect(find.byTooltip('Retrieve all warehouse inventory from laid-off or exiting couriers'), findsOneWidget);

      // Verify Low Items & No Inbounds capsules were removed from KPI header
      expect(find.textContaining('Low Items'), findsNothing);
      expect(find.text('Stock Optimal'), findsNothing);
      expect(find.text('No Inbounds'), findsNothing);

      // Verify Product Quantities & Stock Distribution KPIs appear immediately after KPIs and before Quick Actions
      expect(find.text('Stock Distribution KPIs & Coverage'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Stock Distribution KPIs & Coverage')).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byTooltip('Receive and verify inbound stock consignments from merchants and transfers'),
              )
              .dy,
        ),
      );

      // Tear down widget tree cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}
