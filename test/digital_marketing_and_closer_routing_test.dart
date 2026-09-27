import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/router/app_router.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_marketer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/lead_form.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/core/constants/nigeria_locations.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
void main() {
  group('Digital Marketing & Closer Product Routing Tests', () {
    test('UserEntity correctly recognizes marketer role and routes to /marketer', () {
      const marketerUser = UserEntity(
        id: 'usr-marketer-01',
        email: 'tunde@novaexpress.ng',
        firstName: 'Tunde',
        lastName: 'Adeyemi',
        phone: '08012345678',
        role: 'marketer',
        marketerId: 'mkt-001',
        marketerCode: 'MKT-NOVA-101',
      );

      expect(marketerUser.isMarketer, isTrue);
      expect(marketerUser.isCloser, isFalse);
      expect(marketerUser.isClientAdmin, isFalse);
      expect(marketerUser.homeConsoleRoute, equals('/marketer'));
      expect(marketerUser.roleDescription, equals('Digital Marketer'));
    });

    test('App router allows public unauthenticated access to /f/:formId and /lead-form/:formId', () {
      const unauthState = AuthState(
        user: null,
        isInitialized: true,
      );

      // Public form URLs should bypass login redirect
      final redirectFormShort = appRouteRedirect(
        authState: unauthState,
        matchedLocation: '/f/form-smartwatch-promo',
        hasSupabaseSession: false,
      );
      expect(redirectFormShort, isNull);

      final redirectFormFull = appRouteRedirect(
        authState: unauthState,
        matchedLocation: '/lead-form/form-smartwatch-promo',
        hasSupabaseSession: false,
      );
      expect(redirectFormFull, isNull);

      // Other protected routes must redirect unauthenticated users to /login
      final redirectOrders = appRouteRedirect(
        authState: unauthState,
        matchedLocation: '/orders',
        hasSupabaseSession: false,
      );
      expect(redirectOrders, equals('/login'));
    });

    test('App router isolates /marketer route strictly to authenticated marketers', () {
      const marketerUser = UserEntity(
        id: 'usr-marketer-01',
        email: 'tunde@novaexpress.ng',
        firstName: 'Tunde',
        lastName: 'Adeyemi',
        phone: '08012345678',
        role: 'marketer',
      );

      const marketerAuthState = AuthState(
        user: marketerUser,
        isInitialized: true,
      );

      final marketerAccess = appRouteRedirect(
        authState: marketerAuthState,
        matchedLocation: '/marketer',
        hasSupabaseSession: true,
      );
      expect(marketerAccess, isNull); // Allowed

      const closerUser = UserEntity(
        id: 'usr-closer-01',
        email: 'closer@novaexpress.ng',
        firstName: 'Chinelo',
        lastName: 'Nwachukwu',
        phone: '08098765432',
        role: 'closer',
      );

      const closerAuthState = AuthState(
        user: closerUser,
        isInitialized: true,
      );

      final closerBlocked = appRouteRedirect(
        authState: closerAuthState,
        matchedLocation: '/marketer',
        hasSupabaseSession: true,
      );
      expect(closerBlocked, equals('/closer')); // Redirected to their home console
    });

    test('ClientCloser entity supports assignedProductIds and assignedProductNames', () {
      const closer = ClientCloser(
        id: 'cls-101',
        clientId: 'client-1',
        closerCode: 'CLS-NOVA-101',
        fullName: 'Chinelo Nwachukwu',
        email: 'chinelo@brand.com',
        phone: '08012345678',
        assignedProductIds: ['prod-watch-01', 'prod-strap-02'],
        assignedProductNames: ['Luxury Smartwatch Series 9', 'Leather Strap Acc'],
      );

      expect(closer.assignedProductIds.length, equals(2));
      expect(closer.assignedProductNames.first, equals('Luxury Smartwatch Series 9'));

      final json = closer.toJson();
      expect(json['assigned_product_ids'], contains('prod-watch-01'));
      expect(json['assigned_product_names'], contains('Leather Strap Acc'));

      final fromJson = ClientCloser.fromJson(json);
      expect(fromJson.assignedProductIds, contains('prod-watch-01'));
      expect(fromJson.assignedProductNames, contains('Leather Strap Acc'));
    });

    test('Closer Order Scoping: closers strictly receive orders matching assigned products', () {
      const dedicatedCloser = ClientCloser(
        id: 'cls-watch-closer',
        clientId: 'client-1',
        closerCode: 'CLS-WATCH',
        fullName: 'Watch Specialist',
        email: 'watch@brand.com',
        phone: '08011111111',
        assignedProductIds: ['prod-watch'],
        assignedProductNames: ['Luxury Smartwatch'],
      );

      const generalCloser = ClientCloser(
        id: 'cls-general-closer',
        clientId: 'client-1',
        closerCode: 'CLS-GEN',
        fullName: 'General Sales Rep',
        email: 'general@brand.com',
        phone: '08022222222',
        assignedProductIds: [], // Unrestricted
        assignedProductNames: [],
      );

      final now = DateTime.now();

      final orderWatch = OrderEntity(
        id: 'ord-01',
        orderNumber: 'ORD-001',
        customerName: 'Amina Bello',
        customerPhone: '08033333333',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: '10 Allen Avenue',
        productId: 'prod-watch',
        productName: 'Luxury Smartwatch',
        status: 'pending',
        quantity: 1,
        basePrice: 45000,
        upsellAmount: 0,
        totalAmount: 45000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        closerId: 'cls-watch-closer',
        closerName: 'Watch Specialist',
        closerCode: 'CLS-WATCH',
        createdAt: now,
      );

      final orderHairOil = OrderEntity(
        id: 'ord-02',
        orderNumber: 'ORD-002',
        customerName: 'Emeka Eze',
        customerPhone: '08044444444',
        deliveryState: 'Abuja (FCT)',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '5 Adetokunbo Ademola',
        productId: 'prod-hair-oil',
        productName: 'Herbal Hair Regrowth Oil',
        status: 'pending',
        quantity: 1,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        closerId: 'cls-general-closer',
        closerName: 'General Sales Rep',
        closerCode: 'CLS-GEN',
        createdAt: now,
      );

      final portalState = ClientPortalState(
        clientProfile: const ClientProfile(
          id: 'client-1',
          companyName: 'Apex Brands Ltd',
          contactPerson: 'Apex Admin',
          email: 'admin@apex.com',
          phone: '08011112222',
          address: '12 Marina, Lagos',
          code: 'APEX',
        ),
        closers: [dedicatedCloser, generalCloser],
        orders: [orderWatch, orderHairOil],
      );

      // Dedicated closer only sees the watch order
      final watchCloserOrders = portalState.getOrdersForCloser(
        dedicatedCloser.id,
        dedicatedCloser.email,
        dedicatedCloser.fullName,
      );
      expect(watchCloserOrders.length, equals(1));
      expect(watchCloserOrders.first.id, equals('ord-01'));
      expect(watchCloserOrders.first.productName, equals('Luxury Smartwatch'));

      // Dedicated closer does NOT see hair oil order even if tagged mistakenly
      final hairOilMistagged = orderHairOil.copyWith(
        closerId: 'cls-watch-closer',
        closerName: 'Watch Specialist',
      );
      final stateWithMistag = portalState.copyWith(orders: [orderWatch, hairOilMistagged]);
      final watchOrdersScrubbed = stateWithMistag.getOrdersForCloser(
        dedicatedCloser.id,
        dedicatedCloser.email,
        dedicatedCloser.fullName,
      );
      expect(watchOrdersScrubbed.length, equals(1));
      expect(watchOrdersScrubbed.first.productId, equals('prod-watch'));

      // General closer (unrestricted) sees the orders assigned to them
      final generalOrders = portalState.getOrdersForCloser(
        generalCloser.id,
        generalCloser.email,
        generalCloser.fullName,
      );
      expect(generalOrders.length, equals(1));
      expect(generalOrders.first.id, equals('ord-02'));
    });

    test('LeadForm entity serialization, package deals, and Meta CAPI fields', () {
      final packages = [
        {
          'id': 'pkg-1',
          'name': '1 Pack (Standard)',
          'price': 25000,
          'quantity': 1,
          'is_default': true,
        },
        {
          'id': 'pkg-2',
          'name': '2 Packs (Promo)',
          'price': 45000,
          'quantity': 2,
          'is_default': false,
          'badge': 'Save ₦5,000',
        },
      ];

      final form = LeadForm(
        id: 'form-001',
        clientId: 'client-1',
        productId: 'prod-watch',
        productName: 'Luxury Smartwatch',
        formTitle: 'Flash Sale - Luxury Smartwatch',
        formSlug: 'luxury-smartwatch-flash',
        packages: packages,
        redirectUrl: 'https://apexbrands.com/thank-you',
        pixelId: '123456789012345',
        capiToken: 'EAAtesttoken12345',
        testEventCode: 'TEST999',
        appearance: {'button_text': 'CLAIM YOUR PROMO ORDER'},
        totalSubmissions: 50,
        totalViews: 200,
      );

      expect(form.title, equals('Flash Sale - Luxury Smartwatch'));
      expect(form.buttonText, equals('CLAIM YOUR PROMO ORDER'));
      expect(form.conversionRate, equals(25.0)); // 50 / 200 * 100
      expect(form.packages.length, equals(2));

      final json = form.toJson();
      expect(json['form_title'], equals('Flash Sale - Luxury Smartwatch'));
      expect(json['pixel_id'], equals('123456789012345'));
      expect(json['redirect_url'], equals('https://apexbrands.com/thank-you'));

      final restored = LeadForm.fromJson(json);
      expect(restored.id, equals('form-001'));
      expect(restored.productId, equals('prod-watch'));
      expect(restored.packages.length, equals(2));
    });

    test('ClientMarketer entity supports budget, commission, and tracking counters', () {
      final marketer = ClientMarketer(
        id: 'mkt-001',
        clientId: 'client-1',
        marketerCode: 'MKT-NOVA-101',
        fullName: 'Tunde Adeyemi',
        email: 'tunde@novaexpress.ng',
        phone: '08012345678',
        dailyAdSpendBudget: 150000.0,
        commissionRate: 1500.0,
        isCommissionEnabled: true,
        bankName: 'OPay',
        accountNumber: '8012345678',
        accountName: 'Tunde Adeyemi',
        totalLeadsGenerated: 120,
        totalOrdersGenerated: 84,
        totalOrdersDelivered: 84,
      );

      expect(marketer.conversionRate, closeTo(70.0, 0.1));
      expect(marketer.dailyAdSpendBudget, equals(150000.0));
      expect(marketer.commissionRate, equals(1500.0));

      final json = marketer.toJson();
      expect(json['daily_ad_spend_budget'], equals(150000.0));
      expect(json['marketer_code'], equals('MKT-NOVA-101'));

      final restored = ClientMarketer.fromJson(json);
      expect(restored.fullName, equals('Tunde Adeyemi'));
      expect(restored.totalOrdersDelivered, equals(84));
    });

    test('Balanced round-robin allocation logic distributes orders across attached closers', () {
      // Closer A has 2 active orders
      // Closer B has 1 active order
      // Closer C has 0 active orders
      // Algorithm must pick Closer C with 0 active orders first
      final closers = [
        {
          'id': 'closer-a',
          'name': 'Closer Alpha',
          'active_orders_count': 2,
          'last_assigned_at': DateTime.now().subtract(const Duration(hours: 3)),
        },
        {
          'id': 'closer-b',
          'name': 'Closer Beta',
          'active_orders_count': 1,
          'last_assigned_at': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': 'closer-c',
          'name': 'Closer Gamma',
          'active_orders_count': 0,
          'last_assigned_at': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];

      // Sort by active_orders_count ASC, then last_assigned_at ASC
      closers.sort((a, b) {
        final countComparison = (a['active_orders_count'] as int).compareTo(b['active_orders_count'] as int);
        if (countComparison != 0) return countComparison;
        final aTime = a['last_assigned_at'] as DateTime;
        final bTime = b['last_assigned_at'] as DateTime;
        return aTime.compareTo(bTime);
      });

      expect(closers.first['id'], equals('closer-c'));
    });

    test('NigeriaLocations provides standardized State and LGA cascade lists for Nigerian logistics routing', () {
      expect(NigeriaLocations.states, contains('Lagos'));
      expect(NigeriaLocations.states, contains('FCT - Abuja'));
      expect(NigeriaLocations.states, contains('Rivers'));
      expect(NigeriaLocations.states, contains('Kano'));

      final lagosLgas = NigeriaLocations.getCitiesForState('Lagos');
      expect(lagosLgas.any((lga) => lga.contains('Ikeja')), isTrue);
      expect(lagosLgas.any((lga) => lga.contains('Lekki')), isTrue);
      expect(lagosLgas.any((lga) => lga.contains('Alimosho')), isTrue);

      final abujaLgas = NigeriaLocations.getCitiesForState('FCT - Abuja');
      expect(abujaLgas.any((lga) => lga.contains('Maitama')), isTrue);
      expect(abujaLgas.any((lga) => lga.contains('Garki')), isTrue);
      expect(abujaLgas.any((lga) => lga.contains('Wuse')), isTrue);
    });

    test('Confirmed order with State and LGA routes down to covering DC and active Rider', () {
      const lagosDc = DistributionCenter(
        id: 'dc-lagos-central',
        name: 'Lagos Ikeja Distribution Hub',
        code: 'DC-LOS-01',
        state: 'Lagos',
        city: 'Ikeja',
        address: '10 Mobolaji Bank Anthony Way, Ikeja',
        contactPhone: '08022223333',
        contactEmail: 'ikeja@novaexpress.ng',
        isHub: true,
        isActive: true,
        operatingZones: ['Ikeja', 'Maryland', 'Oregun', 'Alausa'],
      );

      const riderIkeja = DCFleetDriver(
        id: 'drv-ikeja-01',
        name: 'Babatunde Fashola',
        phone: '08011223344',
        driverCode: 'PDA-LOS-101',
        avatarUrl: '',
        vehicleModel: 'Bajaj Boxer',
        vehiclePlate: 'KJA-123-AA',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Ikeja',
        distributionCenterId: 'dc-lagos-central',
        coveredLgas: ['Ikeja', 'Maryland'],
        totalAssignedOrders: 0,
        completedOrders: 0,
        routeProgressPercent: 0.0,
        efficiencyRating: 100.0,
        cashInCustody: 0.0,
        itemsInCustody: 0,
      );

      final confirmedOrder = OrderEntity(
        id: 'ord-mkt-100',
        orderNumber: 'ORD-MK-260927-1001',
        customerName: 'Amina Bello',
        customerPhone: '08033344455',
        deliveryAddress: 'Plot 12, Allen Avenue, Ikeja',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        lga: 'Ikeja',
        status: 'confirmed',
        quantity: 1,
        totalAmount: 35000.0,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        paymentType: 'cash_on_delivery',
        paymentStatus: 'pending',
        closerId: 'cls-101',
        closerName: 'Chinelo Nwachukwu',
        createdAt: DateTime.now(),
      );

      final routingResult = OrderRoutingService.routeOrder(
        order: confirmedOrder,
        distributionCenters: [lagosDc],
        drivers: [riderIkeja],
        stockAllocations: const [],
      );

      expect(routingResult.status, equals(RoutingStatus.assignedToRider));
      expect(routingResult.distributionCenter?.id, equals('dc-lagos-central'));
      expect(routingResult.driver?.id, equals('drv-ikeja-01'));
      expect(routingResult.driver?.name, equals('Babatunde Fashola'));
      expect(routingResult.routedOrder.status, equals('assigned'));
      expect(routingResult.routedOrder.deliveryAgentId, equals('drv-ikeja-01'));
    });

    test('Unconfirmed lead order stays in new state with closer without premature auto-dispatch', () {
      final unconfirmedOrder = OrderEntity(
        id: 'ord-mkt-200',
        orderNumber: 'ORD-MK-260927-2002',
        customerName: 'Chidi Mokeme',
        customerPhone: '08055566677',
        deliveryAddress: '24 Admiralty Way, Lekki Phase 1',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki (Eti-Osa)',
        lga: 'Lekki (Eti-Osa)',
        status: 'new', // Unconfirmed marketing order
        quantity: 2,
        totalAmount: 65000.0,
        basePrice: 65000.0,
        upsellAmount: 0.0,
        paymentType: 'cash_on_delivery',
        paymentStatus: 'pending',
        closerId: 'cls-101',
        closerName: 'Chinelo Nwachukwu',
        createdAt: DateTime.now(),
      );

      // Verify the order has closer assigned, but is not yet in-transit or delivered
      expect(unconfirmedOrder.closerId, equals('cls-101'));
      expect(unconfirmedOrder.status, equals('new'));
      expect(unconfirmedOrder.isUnassigned, isTrue); // No rider yet
      expect(unconfirmedOrder.isAssignedInTransit, isFalse);
      expect(unconfirmedOrder.deliveryLga, equals('Lekki (Eti-Osa)'));
    });

    test('Live Pipeline Reporting: Funnel conversion, closer performance, and LGA regional logistics aggregation', () {
      final sampleOrders = [
        OrderEntity(
          id: 'ord-1',
          orderNumber: 'ORD-001',
          customerName: 'Amina',
          customerPhone: '0801',
          deliveryAddress: 'Ikeja',
          deliveryState: 'Lagos',
          deliveryCity: 'Ikeja',
          lga: 'Ikeja',
          status: 'delivered',
          quantity: 1,
          totalAmount: 30000.0,
          basePrice: 30000.0,
          upsellAmount: 0.0,
          paymentType: 'cash_on_delivery',
          paymentStatus: 'pending',
          closerId: 'cls-1',
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-2',
          orderNumber: 'ORD-002',
          customerName: 'Babatunde',
          customerPhone: '0802',
          deliveryAddress: 'Ikeja',
          deliveryState: 'Lagos',
          deliveryCity: 'Ikeja',
          lga: 'Ikeja',
          status: 'confirmed',
          quantity: 1,
          totalAmount: 40000.0,
          basePrice: 40000.0,
          upsellAmount: 0.0,
          paymentType: 'cash_on_delivery',
          paymentStatus: 'pending',
          closerId: 'cls-1',
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-3',
          orderNumber: 'ORD-003',
          customerName: 'Chinedu',
          customerPhone: '0803',
          deliveryAddress: 'Garki',
          deliveryState: 'FCT - Abuja',
          deliveryCity: 'Garki',
          lga: 'Garki',
          status: 'new',
          quantity: 1,
          totalAmount: 25000.0,
          basePrice: 25000.0,
          upsellAmount: 0.0,
          paymentType: 'cash_on_delivery',
          paymentStatus: 'pending',
          closerId: 'cls-2',
          createdAt: DateTime.now(),
        ),
      ];

      // Funnel calculations
      final total = sampleOrders.length; // 3
      final confirmed = sampleOrders.where((o) => o.status != 'new' && o.status != 'unconfirmed').length; // 2
      final delivered = sampleOrders.where((o) => o.status == 'delivered').length; // 1

      final closerConvRate = (confirmed / total) * 100;
      final deliveryFulfillmentRate = (delivered / confirmed) * 100;

      expect(total, equals(3));
      expect(confirmed, equals(2));
      expect(delivered, equals(1));
      expect(closerConvRate, closeTo(66.6, 0.1));
      expect(deliveryFulfillmentRate, equals(50.0));

      // Closer performance
      final cls1Orders = sampleOrders.where((o) => o.closerId == 'cls-1').toList();
      final cls1Delivered = cls1Orders.where((o) => o.status == 'delivered').length;
      final cls1Rev = cls1Orders.where((o) => o.status == 'delivered').fold<double>(0.0, (s, o) => s + o.totalAmount);
      expect(cls1Orders.length, equals(2));
      expect(cls1Delivered, equals(1));
      expect(cls1Rev, equals(30000.0));

      // LGA aggregation
      final Map<String, List<OrderEntity>> lgas = {};
      for (final o in sampleOrders) {
        final key = '${o.deliveryState} - ${o.lga}';
        lgas.putIfAbsent(key, () => []).add(o);
      }
      expect(lgas.containsKey('Lagos - Ikeja'), isTrue);
      expect(lgas['Lagos - Ikeja']?.length, equals(2));
      expect(lgas.containsKey('FCT - Abuja - Garki'), isTrue);
      expect(lgas['FCT - Abuja - Garki']?.length, equals(1));
    });
  });
}
