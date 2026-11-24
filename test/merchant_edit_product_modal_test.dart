import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/merchant_inventory_models.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_inventory_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_edit_product_modal.dart';

void main() {
  group('MerchantEditProductModal Tests', () {
    testWidgets('Renders product fields, updates metadata and images, and saves changes', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testProduct = MerchantProductStockView(
        id: 'prod-grazer-01',
        name: 'Grazer Herbal Tea',
        sku: 'NOVA-GRAZER-01',
        unitPrice: 18500.0,
        category: 'Herbal Wellness',
        description: 'Weight loss and Liver Detox tea',
        imageUrl: 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?auto=format&fit=crop&w=400&q=80',
        dcShelves: {
          'Abuja Central DC': 350,
          'Lagos Central DC': 580,
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MerchantEditProductModal.show(context, testProduct),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify header and initial values
      expect(find.text('Edit Product Catalog'), findsOneWidget);
      expect(find.text('SKU: NOVA-GRAZER-01'), findsOneWidget);
      expect(find.text('Grazer Herbal Tea'), findsOneWidget);
      expect(find.text('Weight loss and Liver Detox tea'), findsOneWidget);
      expect(find.text('18500'), findsOneWidget);

      // Verify preset catalog image chips
      expect(find.text('Herbal Tea / Detox'), findsOneWidget);
      expect(find.text('Cleanse Infusion'), findsOneWidget);

      // Tap 'Cleanse Infusion' preset chip to update image
      await tester.tap(find.text('Cleanse Infusion'));
      await tester.pumpAndSettle();

      // Update name and description
      final nameField = find.widgetWithText(TextFormField, 'Product Name *');
      await tester.enterText(nameField, 'Grazer Herbal Tea (Ultra Detox)');

      final descField = find.widgetWithText(TextFormField, 'Product Subtitle / Description');
      await tester.enterText(descField, 'Formulated with organic mint and dandelion root');

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify updated product in state
      final updatedProducts = container.read(merchantInventoryProvider).products;
      final savedProduct = updatedProducts.firstWhere((p) => p.sku == 'NOVA-GRAZER-01');
      expect(savedProduct.name, equals('Grazer Herbal Tea (Ultra Detox)'));
      expect(savedProduct.description, equals('Formulated with organic mint and dandelion root'));
      expect(savedProduct.imageUrl, contains('1544787219'));
    });
  });
}
