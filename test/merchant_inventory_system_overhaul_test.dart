import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/domain/entities/client_supplier.dart';
import 'package:novexps/features/client_portal/domain/entities/client_supplier_expanded.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_dashboard_page.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_inventory_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSupplier = ClientSupplier(
    id: 'sup-1',
    clientId: 'cli-test',
    supplierName: 'Apex Botanical Labs Ltd',
    category: 'Herbal Formulations & Pharma',
    contactPerson: 'Dr. Chinedu Okafor',
    phone: '+2348031234567',
    email: 'procurement@apexlabs.ng',
    leadTimeDays: 7,
    paymentTerms: 'Net 30 Days',
    suppliedProducts: ['Respira Herbal Lung Tea', 'Grazer Herbal Detox Tea'],
    createdAt: DateTime(2026, 9, 1),
  );

  final testProduct1 = CatalogProduct(
    id: 'prod-1',
    name: 'Respira Herbal Lung Tea',
    sku: 'NOV-RESP-01',
    clientName: 'Novacare Ltd',
    defaultUnitPrice: 12000.0,
    costPrice: 4500.0,
    totalStockAcrossHubs: 5, // Below lowStockThreshold (10) -> Low Stock
    lowStockThreshold: 10,
    preferredSupplierId: 'sup-1',
    category: 'Health & Wellness',
  );

  final testProduct2 = CatalogProduct(
    id: 'prod-2',
    name: 'Grazer Herbal Detox Tea',
    sku: 'NOV-GRAZ-02',
    clientName: 'Novacare Ltd',
    defaultUnitPrice: 15000.0,
    costPrice: 5500.0,
    totalStockAcrossHubs: 150,
    lowStockThreshold: 20,
    preferredSupplierId: 'sup-1',
    category: 'Health & Wellness',
  );

  group('Merchant Inventory System Overhaul Unit & Entity Tests', () {
    test('ClientSupplierExpanded calculates remaining units and inventory health accurately', () {
      final expanded = ClientSupplierExpanded.fromData(
        supplier: testSupplier,
        allProducts: [testProduct1, testProduct2],
      );

      expect(expanded.linkedProducts.length, 2);
      expect(expanded.totalUnitsRemaining, 155);
      expect(expanded.lowStockProductsCount, 1);
      expect(expanded.stockHealthStatus, 'LOW STOCK');
    });

    test('ClientSupplierExpanded triggers CRITICAL REORDER when a product has 0 units', () {
      final outOfStockProduct = testProduct1.copyWith(totalStockAcrossHubs: 0);
      final expanded = ClientSupplierExpanded.fromData(
        supplier: testSupplier,
        allProducts: [outOfStockProduct],
      );

      expect(expanded.hasCriticalLowStock, true);
      expect(expanded.stockHealthStatus, 'CRITICAL REORDER');
    });

    test('ClientProfile supports operatingStates and brand identity fields', () {
      final profile = ClientProfile(
        id: 'cli-test',
        companyName: 'Novacare Health & Wellness Ltd',
        contactPerson: 'Dr. Chuke Okafor',
        email: 'info@novacare.ng',
        phone: '+2348000000000',
        address: '14 Ademola Adetokunbo Crescent, Wuse 2, Abuja',
        operatingStates: ['Lagos', 'Abuja (FCT)', 'Rivers', 'Kano'],
        hasInventoryManagement: true,
        primaryColor: '#0D9488',
        secondaryColor: '#F37021',
      );

      expect(profile.operatingStates, contains('Abuja (FCT)'));
      expect(profile.hasInventoryManagement, true);

      final json = profile.toJson();
      expect(json['operating_states'], isA<List>());
      expect((json['operating_states'] as List).length, 4);

      final revived = ClientProfile.fromJson(json);
      expect(revived.operatingStates, equals(profile.operatingStates));
    });
  });

  group('Expanded Merchant Executive Dashboard Widget Tests', () {
    testWidgets('Renders Critical Reorder Banner and Landed Valuation on Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = ClientProfile(
        id: 'cli-test',
        companyName: 'Novacare Health & Wellness Ltd',
        contactPerson: 'Dr. Chuke Okafor',
        email: 'info@novacare.ng',
        phone: '+2348000000000',
        address: '14 Ademola Adetokunbo Crescent, Wuse 2, Abuja',
        hasInventoryManagement: true,
      );

      final stockBalance = ClientStockBalance(
        id: 'bal-1',
        clientId: 'cli-test',
        warehouse: 'Abuja Distribution Center',
        itemCode: 'NOV-RESP-01',
        itemName: 'Respira Herbal Lung Tea',
        balanceQty: 5,
        balanceValue: 22500.0,
        valuationRate: 4500.0,
        updatedAt: DateTime(2026, 9, 18),
      );

      final state = ClientPortalState(
        clientProfile: profile,
        products: [testProduct1, testProduct2],
        stockBalances: [stockBalance],
        suppliers: [testSupplier],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientPortalProvider.overrideWith((ref) => _MockDashboardPortalNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ClientDashboardPage(
                onNavigateToOrders: () {},
                onNavigateToProducts: () {},
                onNavigateToInventory: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Welcome Banner displays Stock Intake button
      expect(find.text('Stock Intake'), findsWidgets);

      // 2. Verify Critical Reorder Alert Banner is triggered
      expect(find.text('CRITICAL REORDER ALERT'), findsOneWidget);
      expect(find.textContaining('Respira Herbal Lung Tea'), findsWidgets);

      // 3. Verify Physical Inventory Custody & Landed Valuation Card
      expect(find.text('Physical Inventory Custody & Landed Valuation'), findsOneWidget);
      expect(find.text('Consolidated Landed Value'), findsOneWidget);
      expect(find.text('Physical Network Units'), findsOneWidget);
    });

    testWidgets('Renders Suppliers Directory Pangea table with live stock & health badges', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = ClientProfile(
        id: 'cli-test',
        companyName: 'Novacare Health & Wellness Ltd',
        contactPerson: 'Dr. Chuke Okafor',
        email: 'info@novacare.ng',
        phone: '+2348000000000',
        address: '14 Ademola Adetokunbo Crescent, Wuse 2, Abuja',
        hasInventoryManagement: true,
      );

      final state = ClientPortalState(
        clientProfile: profile,
        products: [testProduct1, testProduct2],
        stockBalances: [],
        suppliers: [testSupplier],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientPortalProvider.overrideWith((ref) => _MockDashboardPortalNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClientInventoryPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Tab 3: Suppliers Directory
      final tab3 = find.textContaining('Suppliers Directory');
      expect(tab3, findsOneWidget);
      await tester.tap(tab3);
      await tester.pumpAndSettle();

      // Verify Table Header & Column Labels
      expect(find.text('SUPPLIER / VENDOR'), findsOneWidget);
      expect(find.text('LINKED PRODUCTS'), findsOneWidget);
      expect(find.text('NETWORK STOCK'), findsOneWidget);
      expect(find.text('INVENTORY HEALTH'), findsOneWidget);

      // Verify row data
      expect(find.text('Apex Botanical Labs Ltd'), findsOneWidget);
      expect(find.text('LOW STOCK'), findsOneWidget);
      expect(find.text('Intake'), findsOneWidget);
    });
  });
}

class _MockDashboardPortalNotifier extends StateNotifier<ClientPortalState> implements ClientPortalNotifier {
  _MockDashboardPortalNotifier(super.state);

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
