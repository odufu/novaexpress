import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';

void main() {
  group('DC Order Routing & Cross-DC Isolation Tests', () {
    final wuseGrandDc = DistributionCenter(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Wuse Central Distribution Hub',
      code: 'DC-WUSE-01',
      state: 'Abuja (FCT)',
      city: 'Wuse 2',
      address: 'Plot 102 Wuse 2, Abuja',
      isGrandDc: true,
      isHub: true,
      isActive: true,
      operatingZones: const [],
    );

    final otukpoDc = DistributionCenter(
      id: '00000000-0000-4000-8000-788825051520',
      name: 'Otukpo DC',
      code: 'DC-OTUKPODC',
      state: 'Benue',
      city: 'Otukpo',
      address: '14 Federal Road, Otukpo',
      isGrandDc: false,
      isHub: false,
      isActive: true,
      operatingZones: const [
        'Ado', 'Agatu', 'Apa', 'Buruku', 'Gboko', 'Guma', 'Gwer East',
        'Katsina-Ala', 'Konshisha', 'Kwande', 'Makurdi', 'Obi', 'Ogbadibo',
        'Ohimini', 'Okpokwu', 'Tarka', 'Ushongo', 'Vandeikya', 'Otukpo'
      ],
    );

    final allDcs = [wuseGrandDc, otukpoDc];

    // Orders
    final abujaOrder = OrderEntity(
      id: 'ord-abj-01',
      orderNumber: 'NOV-2026-7941',
      customerName: 'Akogwu Samson',
      customerPhone: '08085040146',
      deliveryAddress: 'Back Of Hakimi F01',
      deliveryCity: 'Abuja Municipal (AMAC)',
      deliveryState: 'Federal Capital Territory',
      // deliveryLga: 'Abuja Municipal (AMAC)',
      lga: 'Abuja Municipal (AMAC)',
      productName: 'Alpha Man',
      quantity: 5,
      upsellAmount: 0.0,
      basePrice: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      totalAmount: 55000.0,
      distributionCenterId: '22222222-2222-4222-8222-222222222222',
      status: 'delivered',
      createdAt: DateTime.now(),
    );

    final otukpoOrder = OrderEntity(
      id: 'ord-otk-01',
      orderNumber: 'NOV-2026-7332',
      customerName: 'Samuel Jackson',
      customerPhone: '08085040146',
      deliveryAddress: 'Back of redeemed church',
      deliveryCity: 'Otukpo',
      deliveryState: 'Benue',
      // deliveryLga: 'Otukpo',
      lga: 'Otukpo',
      productName: 'Alpha Man',
      quantity: 5,
      upsellAmount: 0.0,
      basePrice: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      totalAmount: 55000.0,
      distributionCenterId: '00000000-0000-4000-8000-788825051520',
      status: 'delivered',
      createdAt: DateTime.now(),
    );

    final katsinaAlaOrder = OrderEntity(
      id: 'ord-otk-02',
      orderNumber: 'NOV-2026-5855',
      customerName: 'Lukman Samuel',
      customerPhone: '08085040146',
      deliveryAddress: 'Back of LGEA Primary school',
      deliveryCity: 'Katsina-Ala',
      deliveryState: 'Benue',
      // deliveryLga: 'Katsina-Ala',
      lga: 'Katsina-Ala',
      productName: 'Respira Lungs Detox Tea',
      quantity: 2,
      upsellAmount: 0.0,
      basePrice: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      totalAmount: 36550.0,
      distributionCenterId: '00000000-0000-4000-8000-788825051520',
      status: 'pending_dispatch',
      createdAt: DateTime.now(),
    );

    final unroutedKanoOrder = OrderEntity(
      id: 'ord-kano-01',
      orderNumber: 'NOV-2026-9999',
      customerName: 'Ibrahim Danladi',
      customerPhone: '08012345678',
      deliveryAddress: 'Kano Main Market',
      deliveryCity: 'Kano Municipal',
      deliveryState: 'Kano',
      // deliveryLga: 'Kano Municipal',
      lga: 'Kano Municipal',
      productName: 'Alpha Man',
      quantity: 1,
      upsellAmount: 0.0,
      basePrice: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      totalAmount: 15000.0,
      distributionCenterId: null,
      status: 'pending_dispatch',
      createdAt: DateTime.now(),
    );

    test('1. Otukpo DC ONLY sees Benue orders and NEVER sees Abuja orders', () {
      final abujaInOtukpo = OrderRoutingService.doesOrderBelongToDc(
        order: abujaOrder,
        currentDc: otukpoDc,
        allDcs: allDcs,
      );
      expect(abujaInOtukpo, isFalse, reason: 'Abuja order must not leak into Otukpo DC');

      final otukpoInOtukpo = OrderRoutingService.doesOrderBelongToDc(
        order: otukpoOrder,
        currentDc: otukpoDc,
        allDcs: allDcs,
      );
      expect(otukpoInOtukpo, isTrue, reason: 'Otukpo order belongs to Otukpo DC');

      final katsinaAlaInOtukpo = OrderRoutingService.doesOrderBelongToDc(
        order: katsinaAlaOrder,
        currentDc: otukpoDc,
        allDcs: allDcs,
      );
      expect(katsinaAlaInOtukpo, isTrue, reason: 'Katsina-Ala (Benue) order belongs to Otukpo DC');

      final kanoInOtukpo = OrderRoutingService.doesOrderBelongToDc(
        order: unroutedKanoOrder,
        currentDc: otukpoDc,
        allDcs: allDcs,
      );
      expect(kanoInOtukpo, isFalse, reason: 'Kano order must not belong to Otukpo DC');
    });

    test('2. Wuse Central Hub (Grand DC) sees Abuja orders and excludes dedicated Otukpo orders', () {
      final abujaInWuse = OrderRoutingService.doesOrderBelongToDc(
        order: abujaOrder,
        currentDc: wuseGrandDc,
        allDcs: allDcs,
      );
      expect(abujaInWuse, isTrue, reason: 'Abuja order belongs to Wuse Central Hub');

      final otukpoInWuse = OrderRoutingService.doesOrderBelongToDc(
        order: otukpoOrder,
        currentDc: wuseGrandDc,
        allDcs: allDcs,
      );
      expect(otukpoInWuse, isFalse, reason: 'Otukpo order must not show in Grand DC when dedicated DC exists');

      final katsinaAlaInWuse = OrderRoutingService.doesOrderBelongToDc(
        order: katsinaAlaOrder,
        currentDc: wuseGrandDc,
        allDcs: allDcs,
      );
      expect(katsinaAlaInWuse, isFalse, reason: 'Benue regional order must not show in Grand DC when dedicated DC exists');
    });

    test('3. Unrouted/orphan orders (e.g. Kano) escalate to Grand DC when no regional DC exists', () {
      final kanoInWuse = OrderRoutingService.doesOrderBelongToDc(
        order: unroutedKanoOrder,
        currentDc: wuseGrandDc,
        allDcs: allDcs,
      );
      expect(kanoInWuse, isTrue, reason: 'Orders with no dedicated regional DC must escalate to Grand DC');
    });

    test('4. If Otukpo DC is removed, Benue orders escalate to Grand DC', () {
      final dcsWithoutOtukpo = [wuseGrandDc];
      final unassignedBenueOrder = OrderEntity(
        id: 'ord-otk-unassigned',
        orderNumber: 'NOV-2026-7332',
        customerName: 'Samuel Jackson',
        customerPhone: '08085040146',
        deliveryAddress: 'Back of redeemed church',
        deliveryCity: 'Otukpo',
        deliveryState: 'Benue',
        lga: 'Otukpo',
        productName: 'Alpha Man',
        quantity: 5,
        upsellAmount: 0.0,
        basePrice: 10000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        totalAmount: 55000.0,
        distributionCenterId: null,
        status: 'pending_dispatch',
        createdAt: DateTime.now(),
      );

      final otukpoWithoutRegionalDc = OrderRoutingService.doesOrderBelongToDc(
        order: unassignedBenueOrder,
        currentDc: wuseGrandDc,
        allDcs: dcsWithoutOtukpo,
      );
      expect(otukpoWithoutRegionalDc, isTrue,
          reason: 'When no dedicated regional DC exists for Benue, orders escalate to Grand DC');
    });
  });
}
