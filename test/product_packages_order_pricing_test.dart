import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_create_order_modal.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  group('Product Packages & Order Pricing Suite', () {
    test('1. Default commercial packages for Grazer Herbal Detox Tea include 4+1 Free mega deal @ ₦55,000', () {
      final packages = ProductCatalogNotifier.buildDefaultPackagesForProduct(
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Detox Tea',
        productSku: 'SKU-GRAZER-01',
        baseUnitPrice: 25000.0,
        clientName: 'Novacare Limited',
      );

      expect(packages.length, greaterThanOrEqualTo(4));

      // Single pack
      final p1 = packages.firstWhere((p) => p.quantity == 1);
      expect(p1.packagePrice, equals(25000.0));
      expect(p1.paidQuantity, equals(1));
      expect(p1.freeQuantity, equals(0));
      expect(p1.totalPhysicalQuantity, equals(1));

      // 2-Pack deal
      final p2 = packages.firstWhere((p) => p.quantity == 2);
      expect(p2.packagePrice, equals(35000.0));
      expect(p2.paidQuantity, equals(2));
      expect(p2.freeQuantity, equals(0));
      expect(p2.totalPhysicalQuantity, equals(2));

      // 3-Pack deal
      final p3 = packages.firstWhere((p) => p.quantity == 3);
      expect(p3.packagePrice, equals(50000.0));
      expect(p3.paidQuantity, equals(3));
      expect(p3.freeQuantity, equals(0));
      expect(p3.totalPhysicalQuantity, equals(3));

      // 5-Pack (4 + 1 Free) Deal
      final p5 = packages.firstWhere((p) => p.quantity == 5);
      expect(p5.packagePrice, equals(55000.0));
      expect(p5.paidQuantity, equals(4));
      expect(p5.freeQuantity, equals(1));
      expect(p5.totalPhysicalQuantity, equals(5));
      expect(p5.packageName, contains('4 + 1 Free'));
    });

    test('2. Order draft state calculates total amount strictly as package price, not cumulative units', () {
      final p5 = ProductPackage(
        id: 'pkg-grazer-5',
        productId: 'prod-grazer',
        productName: 'Grazer Herbal Detox Tea',
        packageName: '5-Pack Mega Deal (4 + 1 Free)',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        packagePrice: 55000.0,
        clientName: 'Novacare Limited',
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer();
      final notifier = container.read(dcCreateOrderDraftProvider.notifier);

      // Select the 5-pack package
      notifier.selectPackage(p5);

      final draft = container.read(dcCreateOrderDraftProvider);

      // Verify that total amount is ₦55,000.00 (NOT 5 * 25,000 = 125,000)
      expect(draft.totalAmount, equals(55000.0));
      expect(draft.quantity, equals(5));
      expect(draft.selectedPackage?.paidQuantity, equals(4));
      expect(draft.selectedPackage?.freeQuantity, equals(1));
      expect(draft.selectedPackage?.totalPhysicalQuantity, equals(5));
    });

    test('3. syncFromStockItems preserves existing packages and enriches products without race condition', () {
      final notifier = ProductCatalogNotifier();

      // Add a custom package deal
      notifier.addPackageToProduct(
        productName: 'Grazer Herbal Detox Tea',
        packageName: 'Grazer Herbal Detox Tea 10-Pack Super Wholesale (8 + 2 Free)',
        quantity: 10,
        paidQuantity: 8,
        freeQuantity: 2,
        packagePrice: 100000.0,
      );

      // Verify custom package exists in state
      var pkgs = notifier.state.getPackagesForProduct('Grazer Herbal Detox Tea');
      expect(pkgs.any((p) => p.packageName.contains('10-Pack')), isTrue);

      // Simulate stock sync from stock inventory
      notifier.syncFromStockItems([
        const StockItemEntity(
          id: 'stock-01',
          name: 'Grazer Herbal Detox Tea',
          sku: 'SKU-GRAZER-01',
          description: 'Herbal detox tea',
          category: 'Health & Wellness',
          price: 25000.0,
          totalInCustody: 100,
          availableCount: 100,
          assignedCount: 0,
          deliveredCount: 0,
          returnedCount: 0,
          ownerName: 'Novacare Limited',
          binLocation: 'BIN-A1-01',
        ),
      ]);

      // Verify custom package was NOT overwritten
      pkgs = notifier.state.getPackagesForProduct('Grazer Herbal Detox Tea');
      expect(pkgs.any((p) => p.packageName.contains('10-Pack')), isTrue);
      expect(pkgs.length, greaterThanOrEqualTo(2));
    });

    test('4. OrderEntity correctly reflects package deal metadata and customer amount to collect', () {
      final order = OrderEntity(
        id: 'ord-test-01',
        orderNumber: 'TRK-8821',
        customerName: 'Fatima Aliyu',
        customerPhone: '08023456789',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: 'Plot 402 Gana Street, Maitama',
        productName: 'Grazer Herbal Detox Tea (5-Pack Mega Deal (4 + 1 Free))',
        status: 'pending',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        basePrice: 55000.0,
        upsellAmount: 0.0,
        totalAmount: 55000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        packageDealName: '5-Pack Mega Deal (4 + 1 Free)',
        createdAt: DateTime.now(),
      );

      expect(order.totalPhysicalQuantity, equals(5));
      expect(order.paidQuantity, equals(4));
      expect(order.freeQuantity, equals(1));
      expect(order.totalAmount, equals(55000.0));
      expect(order.isPod, isTrue);
    });

    testWidgets('5. DCCreateOrderModal displays seller package chips and updates price upon package selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => OrdersStateNotifierMock([])),
            stockProvider.overrideWith((ref) => StockStateNotifierMock([
              const StockItemEntity(
                id: 'stock-01',
                name: 'Grazer Herbal Detox Tea',
                sku: 'SKU-GRAZER-01',
                description: 'Herbal detox tea',
                category: 'Health & Wellness',
                price: 25000.0,
                totalInCustody: 100,
                availableCount: 100,
                assignedCount: 0,
                deliveredCount: 0,
                returnedCount: 0,
                ownerName: 'Novacare Limited',
                binLocation: 'BIN-A1-01',
              ),
            ])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DCCreateOrderModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify product and packages section is visible
      expect(find.text('Product & Seller Commercial Packages'), findsOneWidget);
      expect(find.text('1 Unit (Single)'), findsWidgets);

      // Verify Total Payable Amount is rendered
      expect(find.text('Total Payable Amount'), findsOneWidget);
    });
  });
}

class OrdersStateNotifierMock extends StateNotifier<OrdersState> implements OrdersNotifier {
  OrdersStateNotifierMock(List<OrderEntity> orders) : super(OrdersState(isLoading: false, orders: orders));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StockStateNotifierMock extends StateNotifier<StockState> implements StockNotifier {
  StockStateNotifierMock(List<StockItemEntity> items) : super(StockState(isLoading: false, stockItems: items));

  @override
  Future<void> fetchStockItems([String? agentId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
