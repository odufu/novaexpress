import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dashboard/presentation/pages/main_bottom_nav_shell.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/repositories/stock_repository.dart';
import 'package:novexps/features/stock/presentation/pages/inventory_audit_page.dart';
import 'package:novexps/features/stock/presentation/pages/stock_details_grazer_page.dart';
import 'package:novexps/features/stock/presentation/pages/stock_page.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(UserEntity user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStockRepository implements StockRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async => [];
}

class MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  MockOrdersNotifier(List<OrderEntity> orders) : super(OrdersState(orders: orders, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadOrders([String? agentId]) async {}
}

class FakeNotificationsNotifier extends StateNotifier<NotificationsState> implements NotificationsNotifier {
  FakeNotificationsNotifier() : super(const NotificationsState(notifications: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchNotifications([String? agentId]) async {}
}

class MockFinanceNotifier extends StateNotifier<FinanceState> implements FinanceNotifier {
  MockFinanceNotifier() : super(FinanceState(remittances: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadRemittances([String? agentId]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const mockUser = UserEntity(
    id: 'user_1',
    firstName: 'Emeka',
    lastName: 'Rider',
    email: 'emeka@example.com',
    phone: '08031112222',
    role: 'delivery_agent',
    deliveryAgentId: 'drv_emeka_1',
    deliveryAgentCode: 'PDA-7000',
    operatingState: 'Lagos',
    operatingCity: 'Lekki Phase 1',
    rating: 4.9,
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
  );

  const mockStockItem = StockItemEntity(
    id: 'prod_grazer_02',
    sku: 'SKU-GRAZ-02',
    name: 'Grazer Herbal Tea',
    description: 'Weight loss metabolic enhancement organic tea',
    price: 22000.0,
    ownerName: 'Novacare Limited',
    inventoryType: InventoryType.distributedInventory,
    totalInCustody: 20,
    assignedCount: 20,
    deliveredCount: 8,
    availableCount: 12,
    returnedCount: 0,
    complaintCount: 0,
    lowStockThreshold: 3,
    category: 'Health & Wellness',
    binLocation: 'BIN-A1-02',
    batchNumber: 'LOT-2026-08',
  );

  final mockAllocation = RiderStockAllocation(
    id: 'alloc_grazer_1',
    riderId: 'drv_emeka_1',
    riderName: 'Emeka Rider',
    riderCode: 'PDA-7000',
    productId: 'prod_grazer_02',
    productName: 'Grazer Herbal Tea',
    sku: 'SKU-GRAZ-02',
    allocatedUnits: 20,
    deliveredUnits: 8,
    inCustodyUnits: 12,
    unitPrice: 22000.0,
    allocatedAt: DateTime(2026, 8, 27),
  );

  final mockTiedOrder = OrderEntity(
    id: 'ord_tied_1',
    orderNumber: 'TRK-9001-LAG',
    customerName: 'Amina Bello',
    customerPhone: '08031234567',
    deliveryCity: 'Lekki Phase 1',
    deliveryState: 'Lagos',
    deliveryAddress: 'Plot 12 Admiralty Way, Lekki Phase 1',
    status: 'in_transit',
    productName: 'Grazer Herbal Tea',
    quantity: 5,
    paidQuantity: 5,
    freeQuantity: 0,
    basePrice: 55000.0,
    upsellAmount: 0.0,
    totalAmount: 55000.0,
    paymentType: 'pay_on_delivery',
    paymentStatus: 'pending',
    createdAt: DateTime(2026, 8, 27),
  );

  group('Rider Stock Tab, Details, Packages, and Auto-Deduction Suite', () {
    testWidgets('1. Bottom Navigation renders tab label "Stock" instead of "Inventory"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
            stockProvider.overrideWith(
              (ref) => StockNotifier(repository: FakeStockRepository())
                ..state = StockState(
                  stockItems: [mockStockItem],
                  riderAllocations: [mockAllocation],
                  isLoading: false,
                ),
            ),
            ordersProvider.overrideWith((ref) => MockOrdersNotifier([])),
            notificationsProvider.overrideWith((ref) => FakeNotificationsNotifier()),
            financeProvider.overrideWith((ref) => MockFinanceNotifier()),
          ],
          child: const MaterialApp(
            home: MainBottomNavShell(),
          ),
        ),
      );

      // Verify bottom nav item is 'Stock'
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Inventory'), findsNothing);
    });

    testWidgets('2. StockPage displays assigned vehicle stock, metrics, and no Request Stock FAB', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
            notificationsProvider.overrideWith((ref) => FakeNotificationsNotifier()),
            stockProvider.overrideWith(
              (ref) => StockNotifier(repository: FakeStockRepository())
                ..state = StockState(
                  stockItems: [mockStockItem],
                  riderAllocations: [mockAllocation],
                  isLoading: false,
                ),
            ),
          ],
          child: const MaterialApp(
            home: StockPage(),
          ),
        ),
      );

      await tester.pump();

      // Verify Page Title & Subtitle
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Vehicle stock allocated by Distribution Center'), findsOneWidget);

      // Verify 4 Metrics Cards
      expect(find.text('In Vehicle'), findsWidgets);
      expect(find.text('Delivered'), findsWidgets);
      expect(find.text('Assigned'), findsWidgets);
      expect(find.text('Returned'), findsWidgets);

      // Verify Product Card Content
      expect(find.text('Grazer Herbal Tea'), findsOneWidget);
      expect(find.text('SKU: SKU-GRAZ-02'), findsOneWidget);
      expect(find.textContaining('12 units'), findsWidgets);

      // Verify Return Stock FAB exists
      expect(find.text('Return Stock'), findsWidgets);

      // Verify Stock Reconciliation Banner
      expect(find.text('Stock Reconciliation'), findsWidgets);
    });

    testWidgets('3. StockDetailsGrazerPage renders vehicle custody breakdown, commercial packages from catalog, and tied active orders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final List<ProductPackage> testPackages = [
        ProductPackage(
          id: 'pkg_grz_5',
          productId: 'prod_grazer_02',
          productName: 'Grazer Herbal Tea',
          packageName: '5 Packs Mega Deal (5 for ₦55,000)',
          clientName: 'Novacare Limited',
          quantity: 5,
          paidQuantity: 5,
          freeQuantity: 0,
          packagePrice: 55000.0,
          description: 'Special 5-Pack Bulk Discount Deal',
          createdAt: DateTime(2026, 8, 27),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
            stockProvider.overrideWith(
              (ref) => StockNotifier(repository: FakeStockRepository())
                ..state = StockState(
                  stockItems: [mockStockItem],
                  riderAllocations: [mockAllocation],
                  isLoading: false,
                ),
            ),
            productCatalogProvider.overrideWith(
              (ref) => ProductCatalogNotifier()
                ..state = ProductCatalogState(
                  products: [
                    CatalogProduct(
                      id: 'prod_grazer_02',
                      name: 'Grazer Herbal Tea',
                      sku: 'SKU-GRAZ-02',
                      clientName: 'Novacare Limited',
                      defaultUnitPrice: 22000.0,
                      packages: testPackages,
                    ),
                  ],
                ),
            ),
            ordersProvider.overrideWith(
              (ref) => MockOrdersNotifier([mockTiedOrder]),
            ),
          ],
          child: const MaterialApp(
            home: StockDetailsGrazerPage(productName: 'Grazer Herbal Tea'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Custody Matrix
      expect(find.text('Stock Details'), findsOneWidget);
      expect(find.text('Grazer Herbal Tea'), findsOneWidget);
      expect(find.text('IN VEHICLE CUSTODY'), findsOneWidget);
      expect(find.text('🏢 Assigned by DC'), findsOneWidget);
      expect(find.text('20 Units'), findsOneWidget);
      expect(find.text('✅ Delivered'), findsOneWidget);
      expect(find.text('8 Units'), findsOneWidget);

      // Verify Commercial Package Deal Visibility
      expect(find.textContaining('Commercial Packages & Deals'), findsOneWidget);
      expect(find.textContaining('5 Packs Mega Deal'), findsOneWidget);
      expect(find.text('₦55,000.00'), findsWidgets);
      expect(find.textContaining('5 Physical Stock Units'), findsOneWidget);
      expect(find.textContaining('Save ₦55,000.00 (50% OFF)'), findsOneWidget);

      // Verify Tied Active Orders
      expect(find.textContaining('Active Orders Requiring this Stock'), findsOneWidget);
      expect(find.text('TRK-9001-LAG'), findsOneWidget);
      expect(find.text('Amina Bello • Lekki Phase 1'), findsOneWidget);
      expect(find.text('5 Physical Units'), findsOneWidget);

      // Verify Action CTAs (Return to DC and Reconcile Stock)
      expect(find.text('Return to DC'), findsOneWidget);
      expect(find.text('Reconcile Stock'), findsOneWidget);
    });

    testWidgets('4. InventoryAuditPage updates physical count on hand and records audit', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          stockRepositoryProvider.overrideWithValue(FakeStockRepository()),
          stockProvider.overrideWith(
            (ref) => StockNotifier(repository: FakeStockRepository())
              ..state = StockState(
                stockItems: [mockStockItem],
                riderAllocations: [mockAllocation],
                isLoading: false,
              ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InventoryAuditPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Subtitle
      expect(find.text('Stock Reconciliation'), findsOneWidget);
      expect(find.text('PHYSICAL STOCK AUDIT'), findsOneWidget);
      expect(find.text('VEHICLE CUSTODY AUDIT'), findsOneWidget);

      // Decrement physical count to test variance reporting
      final decrementBtn = find.byIcon(Icons.remove_circle_outline_rounded).first;
      await tester.tap(decrementBtn);
      await tester.pumpAndSettle();

      // Verify Variance alert is triggered
      expect(find.textContaining('Variance: -1 units'), findsOneWidget);

      // Tap Submit Stock Reconciliation
      final submitBtn = find.text('Submit Stock Reconciliation');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Check that stock state was reconciled to 11 units
      final updatedState = container.read(stockProvider);
      final updatedAlloc = updatedState.riderAllocations.firstWhere((a) => a.productId == 'prod_grazer_02');
      expect(updatedAlloc.inCustodyUnits, 11);
    });

    test('5. StockNotifier.recordDeliveredOrderStock automatically deducts vehicle custody and increments delivered count', () async {
      final container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(FakeStockRepository()),
        ],
      );
      final notifier = container.read(stockProvider.notifier);

      notifier.state = StockState(
        stockItems: [mockStockItem],
        riderAllocations: [mockAllocation],
        isLoading: false,
      );

      // Initially: In Custody = 12, Delivered = 8
      expect(notifier.state.riderAllocations.first.inCustodyUnits, 12);
      expect(notifier.state.riderAllocations.first.deliveredUnits, 8);
      expect(notifier.state.stockItems.first.availableCount, 12);
      expect(notifier.state.stockItems.first.deliveredCount, 8);

      // Deliver 5 physical units from order TRK-9001-LAG
      await notifier.recordDeliveredOrderStock(
        productNameOrSku: 'Grazer Herbal Tea',
        riderId: 'drv_emeka_1',
        physicalQuantity: 5,
      );

      // After Delivery: In Custody = 7 (12 - 5), Delivered = 13 (8 + 5)
      expect(notifier.state.riderAllocations.first.inCustodyUnits, 7);
      expect(notifier.state.riderAllocations.first.deliveredUnits, 13);
      expect(notifier.state.stockItems.first.availableCount, 7);
      expect(notifier.state.stockItems.first.deliveredCount, 13);
    });

    test('6. StockNotifier.returnStockToDC returns physical stock to host DC and reconciles custody', () async {
      final container = ProviderContainer(
        overrides: [
          stockRepositoryProvider.overrideWithValue(FakeStockRepository()),
        ],
      );
      final notifier = container.read(stockProvider.notifier);

      notifier.state = StockState(
        stockItems: [mockStockItem],
        riderAllocations: [mockAllocation],
        isLoading: false,
      );

      // Initially: In Custody = 12, Returned = 0
      expect(notifier.state.riderAllocations.first.inCustodyUnits, 12);
      expect(notifier.state.riderAllocations.first.returnedUnits, 0);

      // Rider returns 3 unsold units back to host DC hub
      final res = await notifier.returnStockToDC(
        productIdOrSku: 'prod_grazer_02',
        riderId: 'drv_emeka_1',
        quantity: 3,
        reason: 'End of Day Unsold Hub Drop-off',
      );

      expect(res['success'], true);
      expect(res['remainingInVehicle'], 9);

      // After Return: In Custody = 9 (12 - 3), Returned = 3 (0 + 3)
      expect(notifier.state.riderAllocations.first.inCustodyUnits, 9);
      expect(notifier.state.riderAllocations.first.returnedUnits, 3);
      expect(notifier.state.stockItems.first.availableCount, 9);
      expect(notifier.state.stockItems.first.returnedCount, 3);
    });
  });
}
