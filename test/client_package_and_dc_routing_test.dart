import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/product_catalog_provider.dart';
import 'package:novexps/features/orders/data/models/order_model.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client Package Creation, DC Visibility, and State/LGA Order Routing Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Client creates a commercial package deal, extends it to catalog, and verifies pricing metrics', () async {
      final catalogNotifier = container.read(productCatalogProvider.notifier);

      // Register test product
      await catalogNotifier.registerNewProduct(
        name: 'Novacare Immune Booster',
        sku: 'SKU-BOOST-01',
        baseUnitPrice: 20000.0,
        category: 'Health & Wellness',
        clientName: 'Novacare Pharma',
        coveringStates: ['Lagos', 'Federal Capital Territory'],
      );

      // Client creates a custom 5-pack commercial package (4 paid + 1 free)
      final clientNotifier = container.read(clientPortalProvider.notifier);
      final createdPkg = await clientNotifier.createPackage(
        productId: 'prod-boost-01',
        productName: 'Novacare Immune Booster',
        packageName: '5-Pack Mega Value Bundle (4 + 1 Free)',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        packagePrice: 70000.0,
        description: 'Buy 4 units get 1 bonus unit free',
      );

      expect(createdPkg.packageName, '5-Pack Mega Value Bundle (4 + 1 Free)');
      expect(createdPkg.quantity, 5);
      expect(createdPkg.paidQuantity, 4);
      expect(createdPkg.freeQuantity, 1);
      expect(createdPkg.packagePrice, 70000.0);
      expect(createdPkg.unitPrice, 14000.0); // 70,000 / 5
      expect(createdPkg.totalPhysicalQuantity, 5);

      // Verify savings calculation: 5 * 20,000 = 100,000 retail. Savings = 30,000 (30%)
      expect(createdPkg.savingsAmount(20000.0), 30000.0);
      expect(createdPkg.savingsPercent(20000.0), 30.0);

      // Verify package is accessible in product catalog for DCs
      final catalogState = container.read(productCatalogProvider);
      final packagesForDc = catalogState.getPackagesForProduct('Novacare Immune Booster');
      expect(packagesForDc.any((p) => p.packageName == '5-Pack Mega Value Bundle (4 + 1 Free)'), isTrue);

      // Verify product's covering states remain preserved
      final productInCatalog = catalogState.findProductByName('Novacare Immune Booster');
      expect(productInCatalog, isNotNull);
      expect(productInCatalog!.coveringStates, contains('Lagos'));
      expect(productInCatalog.coveringStates, contains('Federal Capital Territory'));
    });

    test('2. Order routing delivers order to the correct DC based on State and Local Government (LGA)', () {
      final lagosIkejaDc = DistributionCenter(
        id: 'dc-lagos-ikeja',
        name: 'Ikeja Mainland Distribution Hub',
        code: 'DC-IKJ-01',
        state: 'Lagos',
        city: 'Ikeja',
        address: '10 Allen Avenue, Ikeja, Lagos',
        isGrandDc: false,
        isHub: true,
        isActive: true,
        operatingZones: const ['Ikeja', 'Agege', 'Oshodi-Isolo', 'Alimosho'],
      );

      final lagosIslandDc = DistributionCenter(
        id: 'dc-lagos-island',
        name: 'Lekki Island Distribution Center',
        code: 'DC-LEK-01',
        state: 'Lagos',
        city: 'Lekki',
        address: 'Admiralty Way, Lekki Phase 1, Lagos',
        isGrandDc: false,
        isHub: false,
        isActive: true,
        operatingZones: const ['Eti-Osa', 'Lagos Island', 'Ibeju-Lekki'],
      );

      final benueDc = DistributionCenter(
        id: 'dc-benue-makurdi',
        name: 'Makurdi Central Hub',
        code: 'DC-MKD-01',
        state: 'Benue',
        city: 'Makurdi',
        address: 'Bank Road, Makurdi, Benue State',
        isGrandDc: false,
        isHub: true,
        isActive: true,
        operatingZones: const [], // Empty zones = covers whole Benue state
      );

      final grandAbujaHq = DistributionCenter(
        id: 'dc-abuja-grand-hq',
        name: 'Grand DC National Headquarters',
        code: 'DC-HQ-01',
        state: 'Federal Capital Territory',
        city: 'Abuja',
        address: 'Plot 402 Central Business District, Abuja',
        isGrandDc: true,
        isHub: true,
        isActive: true,
        operatingZones: const ['Abuja Municipal (AMAC)', 'AMAC'],
      );

      final allDcs = [lagosIkejaDc, lagosIslandDc, benueDc, grandAbujaHq];
      final drivers = <DCFleetDriver>[];

      // Test Case A: Exact State + LGA coverage match
      final orderIkeja = OrderEntity(
        id: 'ord-001',
        orderNumber: 'TRK-IKJ-01',
        customerName: 'Adebayo Johnson',
        customerPhone: '08022223344',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: '24 Allen Avenue, Ikeja',
        lga: 'Ikeja',
        status: 'pending_dispatch',
        quantity: 2,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        totalAmount: 35000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        productName: 'Novacare Immune Booster',
        createdAt: DateTime.now(),
      );

      final resultIkeja = OrderRoutingService.routeOrder(
        order: orderIkeja,
        distributionCenters: allDcs,
        drivers: drivers,
        stockAllocations: const [],
      );

      expect(resultIkeja.distributionCenter?.id, 'dc-lagos-ikeja');
      expect(resultIkeja.status, RoutingStatus.routedToDcOnly);

      // Test Case B: Island LGA matches Lekki DC
      final orderLekki = OrderEntity(
        id: 'ord-002',
        orderNumber: 'TRK-LEK-01',
        customerName: 'Folake Adeleke',
        customerPhone: '08033334455',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki',
        deliveryAddress: 'Block 4, Admiralty Way, Lekki',
        lga: 'Eti-Osa',
        status: 'pending_dispatch',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        productName: 'Novacare Immune Booster',
        createdAt: DateTime.now(),
      );

      final resultLekki = OrderRoutingService.routeOrder(
        order: orderLekki,
        distributionCenters: allDcs,
        drivers: drivers,
        stockAllocations: const [],
      );

      expect(resultLekki.distributionCenter?.id, 'dc-lagos-island');

      // Test Case C: LGA not explicitly in any DC zones, but DC covers the state (Benue - Otukpo)
      // Must route to Makurdi Central Hub in Benue, NOT escalate to Grand DC in Abuja!
      final orderOtukpo = OrderEntity(
        id: 'ord-003',
        orderNumber: 'TRK-OTK-01',
        customerName: 'Oche Odeh',
        customerPhone: '08055556677',
        deliveryState: 'Benue',
        deliveryCity: 'Otukpo',
        deliveryAddress: '15 Federal Road, Otukpo',
        lga: 'Otukpo',
        status: 'pending_dispatch',
        quantity: 3,
        basePrice: 50000.0,
        upsellAmount: 0.0,
        totalAmount: 50000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        productName: 'Novacare Immune Booster',
        createdAt: DateTime.now(),
      );

      final resultOtukpo = OrderRoutingService.routeOrder(
        order: orderOtukpo,
        distributionCenters: allDcs,
        drivers: drivers,
        stockAllocations: const [],
      );

      expect(resultOtukpo.distributionCenter?.id, 'dc-benue-makurdi');
      expect(resultOtukpo.distributionCenter?.name, 'Makurdi Central Hub');

      // Test Case D: State with NO regional DC (e.g. Sokoto) -> Escalates to Grand DC HQ
      final orderSokoto = OrderEntity(
        id: 'ord-004',
        orderNumber: 'TRK-SKT-01',
        customerName: 'Aminu Bello',
        customerPhone: '08077778899',
        deliveryState: 'Sokoto',
        deliveryCity: 'Sokoto North',
        deliveryAddress: 'Sultan Palace Road, Sokoto',
        lga: 'Sokoto North',
        status: 'pending_dispatch',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        productName: 'Novacare Immune Booster',
        createdAt: DateTime.now(),
      );

      final resultSokoto = OrderRoutingService.routeOrder(
        order: orderSokoto,
        distributionCenters: allDcs,
        drivers: drivers,
        stockAllocations: const [],
      );

      expect(resultSokoto.distributionCenter?.id, 'dc-abuja-grand-hq');
      expect(resultSokoto.status, RoutingStatus.unrouted);
      expect(resultSokoto.dispatchDiagnosis, contains('Escalated to Grand DC'));
    });

    test('3. Client creates an order specifying a package deal, and OrderModel parses package deal metadata', () async {
      final clientNotifier = container.read(clientPortalProvider.notifier);

      // Create an order based on a package deal
      final order = await clientNotifier.createOrder(
        customerName: 'Chioma Nwosu',
        customerPhone: '08098765432',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        deliveryAddress: 'Plot 55 Gana Street, Maitama, Abuja',
        productId: 'prod-boost-01',
        productName: 'Novacare Immune Booster',
        packageId: 'pkg-boost-3deal',
        packageName: '3-Pack Value Deal',
        quantity: 3,
        totalAmount: 48000.0,
        paymentType: 'Pay on Delivery (Cash/POS)',
      );

      expect(order.packageDealId, 'pkg-boost-3deal');
      expect(order.packageDealName, '3-Pack Value Deal');
      expect(order.quantity, 3);
      expect(order.totalAmount, 48000.0);
      expect(order.deliveryState, 'Federal Capital Territory');
      expect(order.lga, 'Abuja Municipal (AMAC)');

      // Verify OrderModel.fromJson parses package deal metadata from direct column or delivery_notes
      final jsonDirect = {
        'id': 'ord-pkg-direct',
        'order_number': 'TRK-DIR-01',
        'customer_name': 'Emeka Okafor',
        'customer_phone': '08011112222',
        'delivery_state': 'Lagos',
        'delivery_city': 'Ikeja',
        'delivery_address': 'Ikeja',
        'status': 'pending',
        'quantity': 5,
        'package_deal_id': 'pkg-5pack-mega',
        'package_deal_name': '5-Pack Mega Deal (4 + 1 Free)',
        'total_amount': 70000.0,
      };

      final parsedDirect = OrderModel.fromJson(jsonDirect);
      expect(parsedDirect.packageDealId, 'pkg-5pack-mega');
      expect(parsedDirect.packageDealName, '5-Pack Mega Deal (4 + 1 Free)');

      final jsonFromNotes = {
        'id': 'ord-pkg-notes',
        'order_number': 'TRK-NOTE-01',
        'customer_name': 'Zainab Ahmed',
        'customer_phone': '08033334444',
        'delivery_state': 'Kano',
        'delivery_city': 'Nassarawa',
        'delivery_address': 'Nassarawa GRA',
        'status': 'pending',
        'quantity': 2,
        'delivery_notes': 'Please call before arrival. [PACKAGE_DEAL: {"id": "pkg-2pack-spec", "name": "2-Pack Special Deal", "quantity": 2, "price": 35000.0}]',
        'total_amount': 35000.0,
      };

      final parsedFromNotes = OrderModel.fromJson(jsonFromNotes);
      expect(parsedFromNotes.packageDealId, 'pkg-2pack-spec');
      expect(parsedFromNotes.packageDealName, '2-Pack Special Deal');
    });
  });
}
