import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product & Package Catalog Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Catalog initializes with clean production slate ready for DC products', () {
      final state = container.read(productCatalogProvider);
      expect(state.products, isEmpty);
    });

    test('Allows dynamic in-order creation of a new package and reuse across future orders', () {
      final catalogNotifier = container.read(productCatalogProvider.notifier);

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
      final updatedGrazer = container.read(productCatalogProvider).findProductByName('Grazer Tea');
      expect(updatedGrazer!.packages.length, 1);
      expect(updatedGrazer.packages.any((p) => p.id == createdPkg.id), true);

      // Check helper method getPackagesForProduct returns the new package for subsequent orders
      final packages = container.read(productCatalogProvider).getPackagesForProduct('Grazer Tea');
      expect(packages.length, 1);
      expect(packages.any((p) => p.packageName == '4 Packs Mega Cleanse Promo'), true);
    });

    test('Creating a package for a new product automatically registers the product and its package', () {
      final catalogNotifier = container.read(productCatalogProvider.notifier);

      final newPkg = catalogNotifier.addPackageToProduct(
        productName: 'Kojic Glow Skin Serum',
        packageName: '3 Bottles Brightening Set',
        quantity: 3,
        packagePrice: 32000.0,
        clientName: 'GlowSkin Africa',
      );

      expect(newPkg.productName, 'Kojic Glow Skin Serum');
      expect(newPkg.packagePrice, 32000.0);

      final newProd = container.read(productCatalogProvider).findProductByName('Kojic Glow Skin Serum');
      expect(newProd, isNotNull);
      expect(newProd!.clientName, 'GlowSkin Africa');
      expect(newProd.packages.length, 1);
      expect(newProd.packages.first.packageName, '3 Bottles Brightening Set');
    });
  });
}
