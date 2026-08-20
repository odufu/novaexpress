import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';

void main() {
  group('Product & Package Catalog Tests', () {
    late ProductCatalogNotifier catalogNotifier;

    setUp(() {
      catalogNotifier = ProductCatalogNotifier();
    });

    test('Catalog initializes with default seller products and commercial packages', () {
      final state = catalogNotifier.debugState;
      expect(state.products.isNotEmpty, true);

      // Check Grazer Tea
      final grazer = state.findProductByName('Grazer Tea');
      expect(grazer, isNotNull);
      expect(grazer!.packages.length, 4);
      expect(grazer.packages.any((p) => p.packageName.contains('1 Pack') && p.packagePrice == 22000.0), true);
      expect(grazer.packages.any((p) => p.packageName.contains('5 Packs') && p.packagePrice == 55000.0), true);

      // Check Alpha Man
      final alpha = state.findProductByName('Alpha Man');
      expect(alpha, isNotNull);
      expect(alpha!.packages.any((p) => p.packageName.contains('1 Bottle') && p.packagePrice == 20000.0), true);
      expect(alpha.packages.any((p) => p.packageName.contains('5 Bottles') && p.packagePrice == 75000.0), true);
    });

    test('Allows dynamic in-order creation of a new package and reuse across future orders', () {
      // Create custom 4-Pack promo deal for Grazer Tea
      final createdPkg = catalogNotifier.addPackageToProduct(
        productName: 'Grazer Tea',
        packageName: '4 Packs Mega Cleanse Promo',
        quantity: 4,
        packagePrice: 45000.0,
        clientName: 'Novacare Limited',
      );

      expect(createdPkg.packageName, '4 Packs Mega Cleanse Promo');
      expect(createdPkg.quantity, 4);
      expect(createdPkg.packagePrice, 45000.0);
      expect(createdPkg.unitPrice, 11250.0);

      // Verify the package is now in the persistent catalog for Grazer Tea
      final updatedGrazer = catalogNotifier.debugState.findProductByName('Grazer Tea');
      expect(updatedGrazer!.packages.length, 5);
      expect(updatedGrazer.packages.any((p) => p.id == createdPkg.id), true);

      // Check helper method getPackagesForProduct returns the new package for subsequent orders
      final packages = catalogNotifier.debugState.getPackagesForProduct('Grazer Tea');
      expect(packages.length, 5);
      expect(packages.any((p) => p.packageName == '4 Packs Mega Cleanse Promo'), true);
    });

    test('Creating a package for a new product automatically registers the product and its package', () {
      final newPkg = catalogNotifier.addPackageToProduct(
        productName: 'Kojic Glow Skin Serum',
        packageName: '3 Bottles Brightening Set',
        quantity: 3,
        packagePrice: 32000.0,
        clientName: 'GlowSkin Africa',
      );

      expect(newPkg.productName, 'Kojic Glow Skin Serum');
      expect(newPkg.packagePrice, 32000.0);

      final newProd = catalogNotifier.debugState.findProductByName('Kojic Glow Skin Serum');
      expect(newProd, isNotNull);
      expect(newProd!.clientName, 'GlowSkin Africa');
      expect(newProd.packages.length, 1);
      expect(newProd.packages.first.packageName, '3 Bottles Brightening Set');
    });
  });
}
