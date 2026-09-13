import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';

void main() {
  group('1. Client Onboarding & User Auth Scoping', () {
    test('Client merchant model resolves distinct clientId without Novacale defaults', () {
      final clientMerchantJson = {
        'id': 'u-daniels-001',
        'email': 'pharmacy@daniels.ng',
        'first_name': 'Daniel',
        'last_name': 'Okonkwo',
        'phone': '08099887766',
        'role': 'client',
        'client_id': 'c-daniels-uuid-1111',
        'client_company_name': 'Daniels Pharmacy Ltd',
      };

      final user = UserModel.fromJson(clientMerchantJson);

      expect(user.role, equals('client'));
      expect(user.isClientAdmin, isTrue);
      expect(user.clientId, equals('c-daniels-uuid-1111'));
      expect(user.clientCompanyName, equals('Daniels Pharmacy Ltd'));
      expect(user.fullName, equals('Daniel Okonkwo'));
    });

    test('Novacale seed account retains official Novacale identification', () {
      final novacaleJson = {
        'id': '33333333-3333-4333-8333-333333333333',
        'email': 'client.novacale@novaexpress.ng',
        'role': 'client',
      };

      final user = UserModel.fromJson(novacaleJson);

      expect(user.clientId, equals('33333333-3333-4333-8333-333333333333'));
      expect(user.clientCompanyName, equals('Novacale Limited'));
      expect(user.firstName, equals('Dr. Chuka'));
      expect(user.lastName, equals('Okafor'));
    });
  });

  group('2. Multi-Tenant Product & Package Isolation', () {
    test('Products and commercial packages are strictly scoped to their respective clientId', () {
      const novacaleClientId = '33333333-3333-4333-8333-333333333333';
      const danielsClientId = 'c-daniels-uuid-1111';

      final novacaleProduct = CatalogProduct(
        id: 'prod-grazer-01',
        name: 'Grazer Tea',
        sku: 'GRZ-TEA-01',
        clientName: 'Novacale Limited',
        clientId: novacaleClientId,
        defaultUnitPrice: 22000.0,
        totalStockAcrossHubs: 150,
        packages: [
          ProductPackage(
            id: 'pkg-grz-1',
            productId: 'prod-grazer-01',
            productName: 'Grazer Tea',
            packageName: '1 Pack (Standard Retail)',
            quantity: 1,
            paidQuantity: 1,
            freeQuantity: 0,
            packagePrice: 22000.0,
            clientName: 'Novacale Limited',
            clientId: novacaleClientId,
            createdAt: DateTime.now(),
          ),
          ProductPackage(
            id: 'pkg-grz-2',
            productId: 'prod-grazer-01',
            productName: 'Grazer Tea',
            packageName: '2 Packs Promo Deal',
            quantity: 2,
            paidQuantity: 2,
            freeQuantity: 0,
            packagePrice: 35000.0,
            clientName: 'Novacale Limited',
            clientId: novacaleClientId,
            createdAt: DateTime.now(),
          ),
        ],
      );

      final danielsProduct = CatalogProduct(
        id: 'prod-dan-01',
        name: 'Daniels Multivitamins',
        sku: 'DAN-VIT-01',
        clientName: 'Daniels Pharmacy Ltd',
        clientId: danielsClientId,
        defaultUnitPrice: 18000.0,
        totalStockAcrossHubs: 80,
        packages: [
          ProductPackage(
            id: 'pkg-dan-1',
            productId: 'prod-dan-01',
            productName: 'Daniels Multivitamins',
            packageName: '1 Bottle',
            quantity: 1,
            paidQuantity: 1,
            freeQuantity: 0,
            packagePrice: 18000.0,
            clientName: 'Daniels Pharmacy Ltd',
            clientId: danielsClientId,
            createdAt: DateTime.now(),
          ),
        ],
      );

      final allPlatformProducts = [novacaleProduct, danielsProduct];

      // Scope for Daniels Pharmacy
      final danielsScoped = allPlatformProducts.where((p) {
        if (p.clientId != null && p.clientId == danielsClientId) return true;
        if (p.clientName.toLowerCase() == 'daniels pharmacy ltd') return true;
        return false;
      }).toList();

      expect(danielsScoped.length, equals(1));
      expect(danielsScoped.first.name, equals('Daniels Multivitamins'));
      expect(danielsScoped.first.clientId, equals(danielsClientId));
      expect(danielsScoped.first.packages.length, equals(1));
      expect(danielsScoped.first.packages.first.packageName, equals('1 Bottle'));

      // Scope for a brand new merchant with zero products
      const newMerchantClientId = 'c-brand-new-merchant';
      final newMerchantScoped = allPlatformProducts.where((p) {
        if (p.clientId != null && p.clientId == newMerchantClientId) return true;
        if (p.clientName.toLowerCase() == 'new merchant') return true;
        return false;
      }).toList();

      expect(newMerchantScoped.isEmpty, isTrue, reason: 'New merchant must have 0 products and not leak other merchants');
    });

    test('Package deal calculations compute unitPrice, savings, and physical units accurately', () {
      final dealPackage = ProductPackage(
        id: 'pkg-promo-5',
        productId: 'prod-grazer-01',
        productName: 'Grazer Tea',
        packageName: '5-Pack Mega Deal (4 + 1 Free)',
        quantity: 5,
        paidQuantity: 4,
        freeQuantity: 1,
        packagePrice: 55000.0,
        clientName: 'Novacale Limited',
        clientId: '33333333-3333-4333-8333-333333333333',
        createdAt: DateTime.now(),
      );

      expect(dealPackage.totalPhysicalQuantity, equals(5));
      expect(dealPackage.unitPrice, equals(11000.0));
      // Base single unit price = 22,000. 5 units regular = 110,000
      expect(dealPackage.savingsAmount(22000.0), equals(55000.0));
      expect(dealPackage.savingsPercent(22000.0), equals(50.0));
    });
  });

  group('3. Client Order Creation & Routing Scoping', () {
    test('Orders created with clientId and routed to correct DC according to State and LGA', () {
      const wuseDcId = '22222222-2222-4222-8222-222222222222';
      const ikejaDcId = '55555555-5555-4555-8555-555555555555';

      final dcs = <DistributionCenter>[
        const DistributionCenter(
          id: wuseDcId,
          code: 'DC-ABUJA-WUSE',
          name: 'Wuse Central Distribution Hub',
          state: 'Federal Capital Territory',
          city: 'Abuja',
          address: 'Wuse Zone 2',
          isHub: true,
          operatingZones: ['Abuja Municipal (AMAC)', 'Bwari', 'Gwagwalada', 'Kuje'],
        ),
        const DistributionCenter(
          id: ikejaDcId,
          code: 'DC-LAGOS-IKEJA',
          name: 'Ikeja Distribution Hub',
          state: 'Lagos',
          city: 'Ikeja',
          address: 'Ikeja Industrial Estate',
          isHub: true,
          operatingZones: ['Ikeja', 'Kosofe', 'Oshodi-Isolo', 'Alimosho'],
        ),
      ];

      final orderAbuja = OrderEntity(
        id: 'ord-daniels-001',
        orderNumber: 'NOV-2026-901',
        customerName: 'Fatima Bello',
        customerPhone: '08022334455',
        deliveryAddress: 'Wuse 2, Abuja',
        deliveryCity: 'Abuja Municipal (AMAC)',
        deliveryState: 'Federal Capital Territory',
        lga: 'Abuja Municipal (AMAC)',
        status: 'pending_dispatch',
        paymentStatus: 'pending',
        paymentType: 'Pay on Delivery (Cash/POS)',
        totalAmount: 35000.0,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        quantity: 2,
        productName: 'Daniels Multivitamins',
        clientName: 'Daniels Pharmacy Ltd',
        clientId: 'c-daniels-uuid-1111',
        createdAt: DateTime.now(),
      );

      final resultAbuja = OrderRoutingService.routeOrder(
        order: orderAbuja,
        distributionCenters: dcs,
        drivers: const [],
        stockAllocations: const [],
      );

      expect(resultAbuja.distributionCenter?.id, equals(wuseDcId));
      expect(resultAbuja.distributionCenter?.name, equals('Wuse Central Distribution Hub'));

      final orderLagos = OrderEntity(
        id: 'ord-daniels-002',
        orderNumber: 'NOV-2026-902',
        customerName: 'Tunde Bakare',
        customerPhone: '08033445566',
        deliveryAddress: 'Allen Avenue, Ikeja',
        deliveryCity: 'Ikeja',
        deliveryState: 'Lagos',
        lga: 'Ikeja',
        status: 'pending_dispatch',
        paymentStatus: 'pending',
        paymentType: 'Pay on Delivery (Cash/POS)',
        totalAmount: 18000.0,
        basePrice: 18000.0,
        upsellAmount: 0.0,
        quantity: 1,
        productName: 'Daniels Multivitamins',
        clientName: 'Daniels Pharmacy Ltd',
        clientId: 'c-daniels-uuid-1111',
        createdAt: DateTime.now(),
      );

      final resultLagos = OrderRoutingService.routeOrder(
        order: orderLagos,
        distributionCenters: dcs,
        drivers: const [],
        stockAllocations: const [],
      );

      expect(resultLagos.distributionCenter?.id, equals(ikejaDcId));
      expect(resultLagos.distributionCenter?.name, equals('Ikeja Distribution Hub'));
    });
  });

  group('4. Live Stock Tracking & Financial Metrics Scoping', () {
    test('Client financial metrics isolate money outside, custody awaiting remittance, and realized revenue', () {
      const danielsClientId = 'c-daniels-uuid-1111';

      final orders = <OrderEntity>[
        // 1. Delivered COD order: total ₦35,000, fee ₦3,000 -> ₦32,000 awaiting remittance in DC custody
        OrderEntity(
          id: 'o-1',
          orderNumber: 'ORD-001',
          customerName: 'Customer A',
          customerPhone: '08011111111',
          deliveryAddress: 'Abuja',
          deliveryCity: 'Abuja',
          deliveryState: 'Federal Capital Territory',
          status: 'delivered',
          paymentStatus: 'collected',
          paymentType: 'pay_on_delivery',
          totalAmount: 35000.0,
          basePrice: 35000.0,
          upsellAmount: 0.0,
          quantity: 2,
          clientDeliveryFee: 3000.0,
          productName: 'Daniels Multivitamins',
          clientId: danielsClientId,
          clientName: 'Daniels Pharmacy Ltd',
          createdAt: DateTime.now(),
          deliveredAt: DateTime.now(),
        ),
        // 2. Delivered COD order: total ₦50,000, fee ₦4,000, already remitted to merchant bank -> ₦46,000 remitted
        OrderEntity(
          id: 'o-2',
          orderNumber: 'ORD-002',
          customerName: 'Customer B',
          customerPhone: '08022222222',
          deliveryAddress: 'Abuja',
          deliveryCity: 'Abuja',
          deliveryState: 'Federal Capital Territory',
          status: 'delivered',
          paymentStatus: 'collected',
          paymentType: 'pay_on_delivery',
          remittanceStatus: 'remitted',
          totalAmount: 50000.0,
          basePrice: 50000.0,
          upsellAmount: 0.0,
          quantity: 3,
          clientDeliveryFee: 4000.0,
          productName: 'Daniels Multivitamins',
          clientId: danielsClientId,
          clientName: 'Daniels Pharmacy Ltd',
          createdAt: DateTime.now(),
          deliveredAt: DateTime.now(),
        ),
        // 3. In-transit COD order with rider: total ₦25,000 -> ₦25,000 Money Outside
        OrderEntity(
          id: 'o-3',
          orderNumber: 'ORD-003',
          customerName: 'Customer C',
          customerPhone: '08033333333',
          deliveryAddress: 'Abuja',
          deliveryCity: 'Abuja',
          deliveryState: 'Federal Capital Territory',
          status: 'in_transit',
          paymentStatus: 'pending',
          paymentType: 'pay_on_delivery',
          totalAmount: 25000.0,
          basePrice: 25000.0,
          upsellAmount: 0.0,
          quantity: 1,
          clientDeliveryFee: 2500.0,
          productName: 'Daniels Multivitamins',
          clientId: danielsClientId,
          clientName: 'Daniels Pharmacy Ltd',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = ClientProductFinanceSummary.calculate(
        orders: orders,
        productName: 'Daniels Multivitamins',
        productSku: 'DAN-VIT-01',
      );

      expect(summary.totalOrders, equals(3));
      expect(summary.deliveredOrders, equals(2));
      expect(summary.inTransitOrders, equals(1));
      expect(summary.unitsDelivered, equals(5)); // 2 + 3 units
      expect(summary.grossDeliveredValue, equals(85000.0)); // 35k + 50k
      expect(summary.logisticsDeliveryFees, equals(7000.0)); // 3k + 4k
      expect(summary.netRealizedRevenue, equals(78000.0)); // 85k - 7k
      expect(summary.awaitingRemittance, equals(32000.0)); // Order 1 in DC custody
      expect(summary.remittedToBank, equals(46000.0)); // Order 2 settled
      expect(summary.moneyOutside, equals(25000.0)); // Order 3 in transit
    });
  });
}
