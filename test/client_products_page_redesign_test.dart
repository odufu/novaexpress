import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_products_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_product_detail_modal.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class FakeProductCatalogNotifier extends StateNotifier<ProductCatalogState>
    implements ProductCatalogNotifier {
  FakeProductCatalogNotifier(List<CatalogProduct> products)
      : super(ProductCatalogState(products: products));

  @override
  Future<void> reloadCatalog() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClientPortalNotifier extends StateNotifier<ClientPortalState>
    implements ClientPortalNotifier {
  FakeClientPortalNotifier(List<CatalogProduct> products)
      : super(ClientPortalState(
          isLoading: false,
          products: products,
          clientProfile: const ClientProfile(
            id: 'cli-01',
            companyName: 'Novacale Limited',
            contactPerson: 'Dr. Chuka Okafor',
            email: 'client@novacale.com',
            phone: '08012345678',
            address: 'Plot 12 Central Business District',
          ),
        ));

  @override
  Future<void> loadClientData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  FakeStockNotifier() : super(const StockState(isLoading: false, stockItems: []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDCConsoleNotifier extends StateNotifier<DCConsoleState> implements DCConsoleNotifier {
  FakeDCConsoleNotifier() : super(DCConsoleState(distributionCenters: defaultDistributionCenters));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Client Products Page Redesign & Views Test Suite', () {
    testWidgets('1. Desktop viewport defaults to Data Table view with KPIs and no giant deals cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<CatalogProduct> testProducts = [
        CatalogProduct(
          id: 'prod-01',
          name: 'Omega 3 Pure Fish Oil',
          sku: 'SKU-OMG-01',
          category: 'Supplements',
          clientName: 'Novacale Limited',
          defaultUnitPrice: 12500.0,
          coveringStates: const ['Lagos', 'Abuja'],
          totalStockAcrossHubs: 50,
          packages: [
            ProductPackage(
              id: 'pkg-01',
              productId: 'prod-01',
              productName: 'Omega 3 Pure Fish Oil',
              productSku: 'SKU-OMG-01',
              packageName: 'Omega Trio Deal (Buy 2 Get 1 Free)',
              packagePrice: 25000.0,
              quantity: 3,
              paidQuantity: 2,
              freeQuantity: 1,
              clientName: 'Novacale Limited',
              createdAt: DateTime.now(),
            ),
          ],
        ),
        const CatalogProduct(
          id: 'prod-02',
          name: 'Alpha Collagen Serum',
          sku: 'SKU-COL-02',
          category: 'Cosmetics',
          clientName: 'Novacale Limited',
          defaultUnitPrice: 22000.0,
          coveringStates: ['Lagos'],
          totalStockAcrossHubs: 0,
          packages: [],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productCatalogProvider.overrideWith((ref) => FakeProductCatalogNotifier(testProducts)),
            clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(testProducts)),
            stockProvider.overrideWith((ref) => FakeStockNotifier()),
            dcConsoleProvider.overrideWith((ref) => FakeDCConsoleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClientProductsPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header & Top KPIs
      expect(find.text('Products & Catalog Management'), findsOneWidget);
      expect(find.text('Catalog Products'), findsOneWidget);
      expect(find.text('Delivered Units'), findsOneWidget);
      expect(find.text('Delivered Revenue'), findsOneWidget);
      expect(find.text('Hub Shelf Stock'), findsOneWidget);
      expect(find.text('Package Deals'), findsOneWidget);

      // On desktop, default view MUST be Data Table
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('RETAIL PRICE'), findsOneWidget);
      expect(find.text('UNITS SOLD'), findsOneWidget);
      expect(find.text('HUB STOCK'), findsOneWidget);

      // Verify products are in table
      expect(find.text('Omega 3 Pure Fish Oil'), findsOneWidget);
      expect(find.text('Alpha Collagen Serum'), findsOneWidget);

      // Verify deals are shown as compact badge, NOT huge deal cards
      expect(find.text('1 Deals'), findsOneWidget);
      expect(find.text('4 Deals'), findsOneWidget);
      // Ensure the giant deal card headline from the old UI is NOT present
      expect(find.textContaining('Commercial Deal Packages ('), findsNothing);

      // Switch to Cards View using the toggle button
      final cardsButton = find.text('Cards');
      expect(cardsButton, findsOneWidget);
      await tester.tap(cardsButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In card view on desktop, it should render GridView of cards and no DataTable
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('1 Package Deals Available'), findsOneWidget);
    });

    testWidgets('2. Mobile viewport defaults to Card view, search/filtering works, and deal badge opens modal', (tester) async {
      tester.view.physicalSize = const Size(420, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<CatalogProduct> testProducts = [
        CatalogProduct(
          id: 'prod-soap',
          name: 'Glow Herbal Soap',
          sku: 'SKU-GLOW-SOAP',
          category: 'Skin Care',
          clientName: 'Novacale Limited',
          defaultUnitPrice: 5000.0,
          coveringStates: const ['Lagos'],
          totalStockAcrossHubs: 20,
          packages: [
            ProductPackage(
              id: 'pkg-soap',
              productId: 'prod-soap',
              productName: 'Glow Herbal Soap',
              productSku: 'SKU-GLOW-SOAP',
              packageName: 'Soap 5-Pack Promo',
              packagePrice: 20000.0,
              quantity: 5,
              paidQuantity: 4,
              freeQuantity: 1,
              clientName: 'Novacale Limited',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productCatalogProvider.overrideWith((ref) => FakeProductCatalogNotifier(testProducts)),
            clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(testProducts)),
            stockProvider.overrideWith((ref) => FakeStockNotifier()),
            dcConsoleProvider.overrideWith((ref) => FakeDCConsoleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClientProductsPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // On mobile, default view MUST be Card view (no DataTable)
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Glow Herbal Soap'), findsOneWidget);
      expect(find.text('1 Package Deals Available'), findsOneWidget);

      // Test Search Filter: Searching for a non-existing product shows empty search result
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'NonExistentXYZ');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No products match your search or filters'), findsOneWidget);

      // Clear search query and unfocus
      await tester.enterText(searchField, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Glow Herbal Soap'), findsOneWidget);

      // Tapping the deal packages strip opens the Product Detail Modal
      final dealStrip = find.text('Manage Deals →');
      expect(dealStrip, findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(dealStrip);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify modal is open and shows the Deal Packages tab
      expect(find.byType(ClientProductDetailModal), findsOneWidget);
      expect(find.text('Soap 5-Pack Promo'), findsOneWidget);
      expect(find.text('+1 FREE PROMO'), findsOneWidget);

      // Dismiss modal before ending test
      Navigator.of(tester.element(find.byType(ClientProductDetailModal))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
