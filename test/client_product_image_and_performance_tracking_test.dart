import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client Product Image Attachment and Performance Tracking Suite', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Client creates a product with image, verifying image is attached across catalog & stock', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      const testImageUrl = 'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=500';

      final createdProduct = await clientNotifier.createProduct(
        name: 'Glow Radiance Herbal Serum',
        sku: 'SKU-GLOW-001',
        unitPrice: 28000.0,
        category: 'Cosmetics & Beauty',
        description: 'Organic vitamin C & collagen facial serum for glowing skin.',
        imageUrl: testImageUrl,
        coveringStates: ['Lagos', 'Federal Capital Territory', 'Rivers'],
      );

      // Verify product entity has the image attached
      expect(createdProduct.name, 'Glow Radiance Herbal Serum');
      expect(createdProduct.sku, 'SKU-GLOW-001');
      expect(createdProduct.imageUrl, testImageUrl);
      expect(createdProduct.coveringStates, contains('Lagos'));
      expect(createdProduct.coveringStates, contains('Federal Capital Territory'));

      // Verify ProductCatalogProvider has this product with image
      final catalogState = container.read(productCatalogProvider);
      final catalogProduct = catalogState.products.firstWhere(
        (p) => p.sku == 'SKU-GLOW-001',
      );
      expect(catalogProduct.imageUrl, testImageUrl);

      // Verify ClientPortalProvider has this product registered with image
      final clientProduct = container.read(clientPortalProvider).products.firstWhere(
        (p) => p.sku == 'SKU-GLOW-001',
      );
      expect(clientProduct.imageUrl, testImageUrl);
    });

    test('2. Product sales metrics tracking correctly computes units sold, revenue, and active orders', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // 1. Create a product with image
      final product = await clientNotifier.createProduct(
        name: 'Respira Herbal Detox Tea',
        sku: 'SKU-RESP-02',
        unitPrice: 15000.0,
        category: 'Beverages & Teas',
        imageUrl: 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=500',
        coveringStates: ['Lagos', 'Federal Capital Territory'],
      );

      // 2. Add commercial packages for this product
      final pkg1 = await clientNotifier.createPackage(
        productId: product.id,
        productName: product.name,
        packageName: 'Single Pack',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        packagePrice: 15000.0,
      );

      final pkg2 = await clientNotifier.createPackage(
        productId: product.id,
        productName: product.name,
        packageName: '3-Pack Family Bundle (2 + 1 Free)',
        quantity: 3,
        paidQuantity: 2,
        freeQuantity: 1,
        packagePrice: 30000.0,
      );

      // 3. Populate state with orders for this product
      final testOrders = <OrderEntity>[
        // Order 1: Delivered Single Pack (1 unit sold, ₦15,000)
        OrderEntity(
          id: 'ord-01',
          orderNumber: 'NX-ORD-1001',
          customerName: 'Amina Bello',
          customerPhone: '08012345678',
          deliveryState: 'Lagos',
          deliveryCity: 'Ikeja',
          deliveryAddress: '14 Allen Avenue',
          productName: 'Respira Herbal Detox Tea',
          productSku: 'SKU-RESP-02',
          status: 'delivered',
          quantity: 1,
          paidQuantity: 1,
          freeQuantity: 0,
          basePrice: 15000.0,
          upsellAmount: 0.0,
          totalAmount: 15000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'paid',
          fulfillmentType: 'client_package',
          clientName: 'Dr. Chuka Okafor',
          clientCompany: 'Novacale Limited',
          packageDealId: pkg1.id,
          packageDealName: pkg1.packageName,
          clientDeliveryFee: 3000.0,
          agentEntitlement: 2000.0,
          transportFee: 0.0,
          remittanceStatus: 'cleared',
          financialSettlementStatus: 'cash_remitted_verified',
          deliveredAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),

        // Order 2: Delivered 3-Pack Bundle (3 units physical, 2 paid + 1 free, ₦30,000)
        OrderEntity(
          id: 'ord-02',
          orderNumber: 'NX-ORD-1002',
          customerName: 'Emeka Nwosu',
          customerPhone: '08098765432',
          deliveryState: 'Federal Capital Territory',
          deliveryCity: 'Abuja',
          deliveryAddress: 'Plot 45 Wuse II',
          productName: 'Respira Herbal Detox Tea',
          productSku: 'SKU-RESP-02',
          status: 'delivered',
          quantity: 3,
          paidQuantity: 2,
          freeQuantity: 1,
          basePrice: 15000.0,
          upsellAmount: 0.0,
          totalAmount: 30000.0,
          paymentType: 'prepaid',
          paymentStatus: 'paid',
          fulfillmentType: 'client_package',
          clientName: 'Dr. Chuka Okafor',
          clientCompany: 'Novacale Limited',
          packageDealId: pkg2.id,
          packageDealName: pkg2.packageName,
          clientDeliveryFee: 3000.0,
          agentEntitlement: 2000.0,
          transportFee: 0.0,
          remittanceStatus: 'cleared',
          financialSettlementStatus: 'direct_transfer_settled',
          deliveredAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),

        // Order 3: In-Transit Order (3 units, ₦30,000)
        OrderEntity(
          id: 'ord-03',
          orderNumber: 'NX-ORD-1003',
          customerName: 'Kemi Adeyemi',
          customerPhone: '08022223333',
          deliveryState: 'Lagos',
          deliveryCity: 'Lekki',
          deliveryAddress: 'Block 3 Admiralty Way',
          productName: 'Respira Herbal Detox Tea',
          productSku: 'SKU-RESP-02',
          status: 'in_transit',
          quantity: 3,
          paidQuantity: 2,
          freeQuantity: 1,
          basePrice: 15000.0,
          upsellAmount: 0.0,
          totalAmount: 30000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          fulfillmentType: 'client_package',
          clientName: 'Dr. Chuka Okafor',
          clientCompany: 'Novacale Limited',
          packageDealId: pkg2.id,
          packageDealName: pkg2.packageName,
          clientDeliveryFee: 3000.0,
          agentEntitlement: 2000.0,
          transportFee: 0.0,
          remittanceStatus: 'unremitted',
          financialSettlementStatus: 'pending_remittance',
          createdAt: DateTime.now(),
        ),

        // Order 4: Order for a DIFFERENT product (should NOT be counted)
        OrderEntity(
          id: 'ord-04',
          orderNumber: 'NX-ORD-1004',
          customerName: 'Tunde Bakare',
          customerPhone: '08055556666',
          deliveryState: 'Lagos',
          deliveryCity: 'Surulere',
          deliveryAddress: '28 Adeniran Ogunsanya',
          productName: 'Other Unrelated Product',
          productSku: 'SKU-OTHER-99',
          status: 'delivered',
          quantity: 5,
          paidQuantity: 5,
          freeQuantity: 0,
          basePrice: 10000.0,
          upsellAmount: 0.0,
          totalAmount: 50000.0,
          paymentType: 'prepaid',
          paymentStatus: 'paid',
          fulfillmentType: 'standard',
          clientName: 'Dr. Chuka Okafor',
          clientCompany: 'Novacale Limited',
          clientDeliveryFee: 3000.0,
          agentEntitlement: 2000.0,
          transportFee: 0.0,
          remittanceStatus: 'cleared',
          financialSettlementStatus: 'direct_transfer_settled',
          createdAt: DateTime.now(),
        ),
      ];

      // Update client portal state with orders
      clientNotifier.state = clientNotifier.state.copyWith(orders: testOrders);

      // Verify product filtering
      final clientState = container.read(clientPortalProvider);
      final productOrders = clientState.orders.where((o) {
        final matchName = o.productName.trim().toLowerCase() == product.name.trim().toLowerCase();
        final matchSku = o.productSku != null &&
            o.productSku!.trim().isNotEmpty &&
            o.productSku!.trim().toLowerCase() == product.sku.trim().toLowerCase();
        return matchName || matchSku;
      }).toList();

      expect(productOrders.length, 3); // 3 orders for Respira Tea

      final deliveredOrders = productOrders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'delivered' || s == 'completed';
      }).toList();

      expect(deliveredOrders.length, 2);

      // Verify Units Sold (1 unit from Ord 1 + 3 units from Ord 2 = 4 units total)
      final totalUnitsSold = deliveredOrders.fold<int>(
        0,
        (sum, o) => sum + (o.quantity > 0 ? o.quantity : 1),
      );
      expect(totalUnitsSold, 4);

      // Verify Paid vs Free units
      final paidUnits = deliveredOrders.fold<int>(
        0,
        (sum, o) => sum + (o.paidQuantity > 0 ? o.paidQuantity : (o.quantity > 0 ? o.quantity : 1)),
      );
      final freeUnits = deliveredOrders.fold<int>(
        0,
        (sum, o) => sum + o.freeQuantity,
      );
      expect(paidUnits, 3);
      expect(freeUnits, 1);

      // Verify Total Sales Revenue (₦15,000 + ₦30,000 = ₦45,000)
      final totalRevenue = deliveredOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.totalAmount,
      );
      expect(totalRevenue, 45000.0);

      // Verify In-Transit Count
      final inTransitCount = productOrders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
      }).length;
      expect(inTransitCount, 1);

      // Verify Package Deals Usage Breakdown
      final pkg1Orders = productOrders.where((o) => o.packageDealId == pkg1.id).length;
      final pkg2Orders = productOrders.where((o) => o.packageDealId == pkg2.id).length;
      expect(pkg1Orders, 1);
      expect(pkg2Orders, 2); // 1 delivered + 1 in transit
    });
  });
}
