import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_detail_page.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_distribution_centers_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

// Mock Notifiers
class _MockFinanceNotifier extends StateNotifier<FinanceState> implements FinanceNotifier {
  _MockFinanceNotifier() : super(FinanceState(isLoading: false));

  @override
  Future<void> loadRemittances([String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier(List<OrderEntity> initialOrders)
      : super(OrdersState(orders: initialOrders, isLoading: false));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  Future<void> loadOrders([String? agentId]) async {}

  @override
  Future<void> filterOrdersByDc(String dcId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier([List<StockItemEntity> items = const []])
      : super(StockState(stockItems: items, isLoading: false));

  @override
  Future<void> fetchStockItems([String? category, String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalStorageService implements LocalStorageService {
  List<DistributionCenter>? cachedDcs;
  @override
  Future<List<DistributionCenter>?> getCachedDistributionCenters() async => cachedDcs;
  @override
  Future<void> cacheDistributionCenters(List<DistributionCenter> dcs) async => cachedDcs = dcs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testDc = DistributionCenter(
    id: 'dc_otukpo_01',
    name: 'Otukpo Regional Distribution Hub',
    code: 'DC-OTK-01',
    state: 'Benue State',
    city: 'Otukpo',
    address: '42 Commercial Avenue, Otukpo',
    contactPhone: '+234 808 123 4567',
    contactEmail: 'otukpo.hub@novaexpress.ng',
    managerName: 'Audu Ogbeh',
    isGrandDc: true,
    isHub: true,
    isActive: true,
    operatingZones: const ['Otukpo', 'Ohimini', 'Konshisha'],
    storageCapacityUnits: 25000,
  );

  final testOrders = [
    OrderEntity(
      id: 'ord_1',
      orderNumber: '#TRK-2591',
      customerName: 'Jackson Lawal',
      customerPhone: '08087957684',
      deliveryAddress: 'Jackrill, Otukpo',
      deliveryCity: 'Otukpo',
      deliveryState: 'Benue State',
      lga: 'Otukpo',
      productName: 'Respira Detox Tea',
      quantity: 5,
      paidQuantity: 5,
      freeQuantity: 0,
      basePrice: 11000.0,
      upsellAmount: 0.0,
      totalAmount: 55000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      fulfillmentType: 'distributed_inventory',
      clientName: 'Novacale Admin',
      clientCompany: 'Novacale Limited',
      clientDeliveryFee: 5000.0,
      agentEntitlement: 2500.0,
      status: 'delivered',
      deliveryAgentName: 'Daniel Onyanwu',
      deliveryAgentId: 'rider_1',
      distributionCenterId: 'dc_otukpo_01',
      createdAt: DateTime.now(),
    ),
    OrderEntity(
      id: 'ord_2',
      orderNumber: '#TRK-8712',
      customerName: 'Kugara Smail sunday',
      customerPhone: '08085040346',
      deliveryAddress: 'Stadium road Kahi, Ohimini',
      deliveryCity: 'Ohimini',
      deliveryState: 'Benue State',
      lga: 'Ohimini',
      productName: 'Grazer Herbal Detox Tea',
      quantity: 3,
      paidQuantity: 3,
      freeQuantity: 0,
      basePrice: 16666.6,
      upsellAmount: 0.0,
      totalAmount: 50000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      fulfillmentType: 'distributed_inventory',
      clientName: 'Novacale Admin',
      clientCompany: 'Novacale Limited',
      clientDeliveryFee: 5000.0,
      agentEntitlement: 2500.0,
      status: 'in_transit',
      deliveryAgentName: 'Daniel Onyanwu',
      deliveryAgentId: 'rider_1',
      distributionCenterId: 'dc_otukpo_01',
      createdAt: DateTime.now(),
    ),
  ];

  final testStock = [
    const StockItemEntity(
      id: 'prod_1',
      name: 'Respira Detox Tea',
      sku: 'SKU-RDT-01',
      description: 'Herbal detox tea',
      category: 'Herbal Wellness',
      price: 11000.0,
      ownerName: 'Novacale Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 500,
      reservedCount: 0,
      assignedCount: 50,
      deliveredCount: 0,
      availableCount: 450,
      returnedCount: 0,
      awaitingReturnCount: 0,
      complaintCount: 0,
      lowStockThreshold: 100,
      reorderLevel: 50,
    ),
  ];

  final testRider = const DCFleetDriver(
    id: 'rider_1',
    driverCode: 'PDA-7454',
    name: 'Daniel Onyanwu',
    phone: '+234 808 555 1234',
    avatarUrl: '',
    vehicleModel: 'Bajaj Boxer 150',
    vehiclePlate: 'ABJ-452-XY',
    vehicleType: 'Motorcycle',
    status: 'active',
    assignedZone: 'Otukpo',
    distributionCenterId: 'dc_otukpo_01',
    totalAssignedOrders: 2,
    completedOrders: 1,
    routeProgressPercent: 50.0,
    efficiencyRating: 4.9,
    cashInCustody: 55000,
    itemsInCustody: 1,
  );

  group('DC Distribution Centers Network Page & Detail View Tests', () {
    testWidgets('DC Page displays Data Table on Desktop and switches to Cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Table View default on Desktop
      expect(find.text('DISTRIBUTION CENTER'), findsOneWidget);
      expect(find.text('STORAGE VOLUME'), findsOneWidget);
      expect(find.text('Open Console'), findsWidgets);

      // Switch to Cards View using the toolbar switcher
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();

      // Verify Cards are displayed
      expect(find.text('Open DC Hub Console & Operations ➜'), findsWidgets);

      // Switch back to Table View
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      expect(find.text('DISTRIBUTION CENTER'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Tapping Open Console or Table Row navigates to DCDetailPage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(testStock)),
            financeProvider.overrideWith((ref) => _MockFinanceNotifier()),
          ],
          child: const MaterialApp(
            home: DCDistributionCentersPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Cards then tap Open DC Hub Console
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open DC Hub Console & Operations ➜').first);
      await tester.pumpAndSettle();

      // Verify DCDetailPage is now displayed
      expect(find.text('All Distribution Centers'), findsOneWidget);
      expect(find.textContaining('Orders'), findsWidgets);
      expect(find.textContaining('Remittances'), findsWidgets);
      expect(find.textContaining('Inventory'), findsWidgets);
      expect(find.textContaining('Riders'), findsWidgets);
      expect(find.textContaining('Settings'), findsWidgets);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('DCDetailPage renders and interacts with all 5 entity tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      bool backCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcConsoleProvider.overrideWith((ref) => DCConsoleNotifier(MockLocalStorageService())),
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier(testOrders)),
            stockProvider.overrideWith((ref) => _MockStockNotifier(testStock)),
            financeProvider.overrideWith((ref) => _MockFinanceNotifier()),
          ],
          child: MaterialApp(
            home: DCDetailPage(
              dc: testDc,
              onBack: () => backCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Orders Tab (Default)
      expect(find.text('Total Filtered Orders'), findsOneWidget);
      expect(find.text('Fulfilled / POD'), findsOneWidget);
      expect(find.text('#TRK-2591'), findsOneWidget);
      expect(find.text('Jackson Lawal'), findsOneWidget);

      // 2. Remittance Tab
      await tester.tap(find.textContaining('Remittances'));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL MONITORED VALUE'), findsOneWidget);
      expect(find.text('REMITTED & RECONCILED'), findsOneWidget);

      // 3. Inventory & Stocks Tab
      await tester.tap(find.textContaining('Inventory'));
      await tester.pumpAndSettle();

      expect(find.text('Respira Detox Tea'), findsOneWidget);
      expect(find.textContaining('SKU-RDT-01'), findsOneWidget);

      // 4. Riders & Fleet Tab
      await tester.tap(find.textContaining('Riders'));
      await tester.pumpAndSettle();

      expect(find.text('Total Attached Fleet'), findsOneWidget);
      expect(find.text('Active On-Duty'), findsOneWidget);
      expect(find.text('+ Onboard Rider to this Hub'), findsOneWidget);

      // 5. Settings Tab
      await tester.tap(find.textContaining('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Hub Supervisor Credentials & Password Reset'), findsOneWidget);
      expect(find.text('Operational Coverage Zones (LGAs)'), findsOneWidget);
      expect(find.text('Save Facility Details'), findsOneWidget);

      // Back navigation
      await tester.tap(find.text('All Distribution Centers'));
      await tester.pumpAndSettle();
      expect(backCalled, isTrue);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
