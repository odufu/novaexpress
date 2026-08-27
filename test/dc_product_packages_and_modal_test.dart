import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_product_detail_modal.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Product Package Entity & Calculations Unit Tests', () {
    test('1. ProductPackage calculates unit price, total units, and customer savings accurately', () {
      final pkg = ProductPackage(
        id: 'pkg_grz_5',
        productId: 'prod_grz',
        productName: 'Grazer Tea',
        productSku: 'SKU-GRZ-001',
        packageName: '5 Packs Mega Deal (5 for ₦55,000)',
        quantity: 5,
        paidQuantity: 5,
        freeQuantity: 0,
        packagePrice: 55000.0,
        clientName: 'Novacare Limited',
        createdAt: DateTime(2026, 8, 27),
      );

      const singleUnitPrice = 22000.0;

      // Effective unit rate: 55,000 / 5 = 11,000
      expect(pkg.unitPrice, 11000.0);
      expect(pkg.totalPhysicalQuantity, 5);

      // Single item total for 5 units = 5 * 22,000 = 110,000
      // Savings = 110,000 - 55,000 = 55,000 (50% discount)
      expect(pkg.savingsAmount(singleUnitPrice), 55000.0);
      expect(pkg.savingsPercent(singleUnitPrice), 50.0);
    });

    test('2. ProductPackage with bonus free units calculates correctly', () {
      final promoPkg = ProductPackage(
        id: 'pkg_bio_3',
        productId: 'prod_bio',
        productName: 'Bio-Gold Pro Capsules',
        productSku: 'SKU-BIO-001',
        packageName: '3 Bottles Premium Pack (Buy 2 Get 1 Free)',
        quantity: 3,
        paidQuantity: 2,
        freeQuantity: 1,
        packagePrice: 70000.0,
        clientName: 'Novacare Limited',
        createdAt: DateTime(2026, 8, 27),
      );

      const singleUnitPrice = 35000.0;

      expect(promoPkg.totalPhysicalQuantity, 3);
      expect(promoPkg.paidQuantity, 2);
      expect(promoPkg.freeQuantity, 1);
      // 3 * 35,000 = 105,000. Savings = 105,000 - 70,000 = 35,000
      expect(promoPkg.savingsAmount(singleUnitPrice), 35000.0);
      expect(promoPkg.savingsPercent(singleUnitPrice), closeTo(33.33, 0.05));
    });

    test('3. ProductPackage JSON serialization and deserialization roundtrip', () {
      final pkg = ProductPackage(
        id: 'pkg_test_1',
        productId: 'prod_test',
        productName: 'Herbal Colon Cleanse',
        productSku: 'SKU-CLN-01',
        packageName: '4 Boxes Cleanse Set',
        quantity: 4,
        paidQuantity: 4,
        freeQuantity: 0,
        packagePrice: 60000.0,
        clientName: 'HealthCo Ltd',
        description: 'Complete 30-day detox',
        isCustom: true,
        createdAt: DateTime(2026, 8, 27, 10, 0),
      );

      final json = pkg.toJson();
      final fromJson = ProductPackage.fromJson(json);

      expect(fromJson.id, pkg.id);
      expect(fromJson.productName, pkg.productName);
      expect(fromJson.packageName, pkg.packageName);
      expect(fromJson.quantity, 4);
      expect(fromJson.packagePrice, 60000.0);
      expect(fromJson.isCustom, true);
    });
    test('4. ProductCatalogNotifier.updatePackage modifies existing package attributes correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(productCatalogProvider.notifier);

      // Add a package first
      final pkg = notifier.addPackageToProduct(
        productName: 'Grazer Tea',
        packageName: '3-Pack Standard Set',
        quantity: 3,
        paidQuantity: 3,
        freeQuantity: 0,
        packagePrice: 50000.0,
      );

      expect(pkg.packageName, '3-Pack Standard Set');
      expect(pkg.packagePrice, 50000.0);

      // Now edit/update the package
      final updated = notifier.updatePackage(
        productName: 'Grazer Tea',
        packageId: pkg.id,
        packageName: '3-Pack Mega Promo (Buy 2 Get 1 Free)',
        quantity: 3,
        paidQuantity: 2,
        freeQuantity: 1,
        packagePrice: 42000.0,
        description: 'Special promo deal',
      );

      expect(updated, isNotNull);
      expect(updated!.packageName, '3-Pack Mega Promo (Buy 2 Get 1 Free)');
      expect(updated.packagePrice, 42000.0);
      expect(updated.paidQuantity, 2);
      expect(updated.freeQuantity, 1);
      expect(updated.description, 'Special promo deal');
    });
  });

  group('DCProductDetailModal Widget Tests', () {
    const mockStockItem = StockItemEntity(
      id: 'prod_grazer',
      sku: 'SKU-GRZ-001',
      name: 'Grazer Tea',
      description: 'Organic Herbal Slimming & Detox Tea with premium herbal ingredients and antioxidants',
      price: 22000.0,
      ownerName: 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: 100,
      assignedCount: 40,
      deliveredCount: 15,
      availableCount: 60,
      returnedCount: 0,
      complaintCount: 1,
      lowStockThreshold: 10,
      category: 'Herbal Health',
      binLocation: 'BIN-A1-01',
      batchNumber: 'LOT-2026-08',
    );

    final mockDrivers = [
      const DCFleetDriver(
        id: 'drv_1',
        driverCode: 'PDA-7000',
        name: 'Emeka Okafor',
        phone: '08031112222',
        avatarUrl: 'https://example.com/avatar.jpg',
        vehicleModel: 'Bajaj Boxer 150',
        vehiclePlate: 'LND-492-XA',
        vehicleType: 'Motorbike',
        status: 'active',
        assignedZone: 'Lekki / Phase 1',
        totalAssignedOrders: 15,
        completedOrders: 12,
        routeProgressPercent: 0.8,
        efficiencyRating: 4.9,
        cashInCustody: 45000,
        itemsInCustody: 6,
      ),
    ];

    final mockAllocations = [
      RiderStockAllocation(
        id: 'alloc_1',
        riderId: 'drv_1',
        riderName: 'Emeka Okafor',
        riderCode: 'PDA-7000',
        productId: 'prod_grazer',
        productName: 'Grazer Tea',
        sku: 'SKU-GRZ-001',
        allocatedUnits: 10,
        deliveredUnits: 4,
        inCustodyUnits: 6,
        unitPrice: 22000.0,
        allocatedAt: DateTime(2026, 8, 27),
      ),
    ];

    testWidgets('1. Renders product specs, inventory stats, commercial packages, and rider custody', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCProductDetailModal(
                item: mockStockItem,
                drivers: mockDrivers,
                allocations: mockAllocations,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Specs
      expect(find.text('Grazer Tea'), findsWidgets);
      expect(find.textContaining('SKU-GRZ-001'), findsWidgets);
      expect(find.textContaining('Novacare Limited'), findsWidgets);
      expect(find.text('BIN-A1-01'), findsOneWidget);
      expect(find.text('LOT-2026-08'), findsOneWidget);

      // Verify 4 Inventory Numbers
      expect(find.text('🏢 In DC Possession'), findsOneWidget);
      expect(find.text('60 Units'), findsOneWidget);
      expect(find.text('🛵 In Rider Custody'), findsOneWidget);
      expect(find.text('25 Units'), findsOneWidget);
      expect(find.text('✅ Delivered Units'), findsOneWidget);
      expect(find.text('15 Units'), findsOneWidget);
      expect(find.text('⚠️ Reported / Damaged'), findsOneWidget);
      expect(find.text('1 Units'), findsOneWidget);

      // Verify Commercial Packages Section
      expect(find.textContaining('Commercial Packages & Bundles'), findsOneWidget);
      expect(find.text('+ Create Package Deal'), findsOneWidget);
      expect(find.textContaining('5 Packs Mega Deal (5 for ₦55,000)'), findsOneWidget);
      expect(find.text('₦55,000.00'), findsWidgets);

      // Verify Edit Deal buttons are present
      expect(find.text('Edit Deal'), findsWidgets);

      // Verify Riders in Custody
      expect(find.textContaining('Riders Holding Vehicle Stock'), findsOneWidget);
      expect(find.text('Emeka Okafor'), findsOneWidget);
      expect(find.text('6 Units in Vehicle'), findsOneWidget);
    });

    testWidgets('2. Opening Create Package Deal dialog and submitting saves new package to catalog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCProductDetailModal(
                item: mockStockItem,
                drivers: mockDrivers,
                allocations: mockAllocations,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap + Create Package Deal button
      final createPkgBtn = find.text('+ Create Package Deal');
      expect(createPkgBtn, findsOneWidget);
      await tester.tap(createPkgBtn);
      await tester.pumpAndSettle();

      // Verify Dialog opens
      expect(find.text('Create Package for Grazer Tea'), findsOneWidget);
      expect(find.text('Effective Unit Rate:'), findsOneWidget);
      expect(find.text('Customer Savings:'), findsOneWidget);

      // Submit new package
      final saveBtn = find.text('Save Package');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Create Package for Grazer Tea'), findsNothing);
    });

    testWidgets('3. Tapping Edit Deal opens edit modal and allows updating package price and description', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCProductDetailModal(
                item: mockStockItem,
                drivers: mockDrivers,
                allocations: mockAllocations,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the first 'Edit Deal' button
      final editBtn = find.text('Edit Deal').first;
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify Edit Dialog opens with existing package details
      expect(find.textContaining('Edit Package:'), findsOneWidget);
      expect(find.text('Update Package'), findsOneWidget);

      // Tap 'Update Package'
      await tester.tap(find.text('Update Package'));
      await tester.pumpAndSettle();

      // Edit Dialog is dismissed
      expect(find.textContaining('Edit Package:'), findsNothing);
    });
  });
}
