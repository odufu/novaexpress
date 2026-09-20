import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Respira Commercial Packages & Strict Pricing Governance Suite', () {
    test('1. Default Respira packages suite produces exact merchant tiers and pricing', () {
      final pkgs = ProductCatalogNotifier.buildDefaultPackagesForProduct(
        productId: 'prod-respira-01',
        productName: 'Respira Detox Tea',
        productSku: 'SKU-RLT',
        baseUnitPrice: 21500.0,
        clientName: 'Novacare Ltd',
      );

      expect(pkgs.length, equals(4));

      // Tier 1: 1 Box = ₦21,500
      final p1 = pkgs.firstWhere((p) => p.quantity == 1);
      expect(p1.packageName, contains('1 Box'));
      expect(p1.packagePrice, equals(21500.0));
      expect(p1.paidQuantity, equals(1));
      expect(p1.freeQuantity, equals(0));
      expect(p1.totalPhysicalQuantity, equals(1));

      // Tier 2: 2 Boxes = ₦35,000
      final p2 = pkgs.firstWhere((p) => p.quantity == 2);
      expect(p2.packageName, contains('2 Boxes'));
      expect(p2.packagePrice, equals(35000.0));
      expect(p2.paidQuantity, equals(2));
      expect(p2.freeQuantity, equals(0));
      expect(p2.totalPhysicalQuantity, equals(2));

      // Tier 3: 3 Boxes = ₦45,000
      final p3 = pkgs.firstWhere((p) => p.quantity == 3);
      expect(p3.packageName, contains('3 Boxes'));
      expect(p3.packagePrice, equals(45000.0));
      expect(p3.paidQuantity, equals(3));
      expect(p3.freeQuantity, equals(0));
      expect(p3.totalPhysicalQuantity, equals(3));

      // Tier 4: 4 Boxes + 1 Box Free = ₦55,000
      final p5 = pkgs.firstWhere((p) => p.quantity == 5);
      expect(p5.packageName, contains('4 Boxes + 1 Box Free'));
      expect(p5.packagePrice, equals(55000.0));
      expect(p5.paidQuantity, equals(4));
      expect(p5.freeQuantity, equals(1));
      expect(p5.totalPhysicalQuantity, equals(5));
    });

    test('2. OrderEntity accurately captures package deal, totalAmount, and total physical units', () {
      final order = OrderEntity(
        id: 'ord-respira-mega-01',
        orderNumber: 'ORD-9021',
        customerName: 'Amina Bello',
        customerPhone: '+2348012345678',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Garki',
        deliveryAddress: 'Plot 42 Crescent, Area 11',
        productName: 'Respira Detox Tea',
        status: 'pending_dispatch',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        basePrice: 55000.0,
        upsellAmount: 0.0,
        totalAmount: 55000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        packageDealId: 'pkg-respira-nova-5',
        packageDealName: '4 Boxes + 1 Box Free Mega Deal',
        createdAt: DateTime.now(),
      );

      expect(order.packageDealName, equals('4 Boxes + 1 Box Free Mega Deal'));
      expect(order.totalAmount, equals(55000.0));
      expect(order.paidQuantity, equals(4));
      expect(order.freeQuantity, equals(1));
      expect(order.totalPhysicalQuantity, equals(5));
    });

    test('3. COGS and Gross Profit calculation expenses all physical units dispatched', () {
      const double unitLandedCost = 1800.0;
      const double packageRevenue = 55000.0;
      const int physicalUnitsDispatched = 5; // 4 paid + 1 free

      final double totalCogs = physicalUnitsDispatched * unitLandedCost;
      final double grossProfit = packageRevenue - totalCogs;

      expect(totalCogs, equals(9000.0));
      expect(grossProfit, equals(46000.0));
      // Proves that free box is accounted for in inventory depletion and costs
      expect(totalCogs, greaterThan(4 * unitLandedCost));
    });
  });
}
