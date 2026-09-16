import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Client Live Daily Accumulator & 10:00 PM Closeout Tests', () {
    final clientProfile = ClientProfile(
      id: '00000000-0000-4000-8000-789382731303',
      companyName: 'Novacare Health Ltd',
      contactPerson: 'Joel Odufu',
      email: 'joel@novacare.com',
      phone: '+2348012345678',
      address: 'Plot 10 Wuse Zone 2',
      bankName: 'Access Bank',
      accountNumber: '0123456789',
      accountName: 'Novacare Health Ltd',
    );

    final order1 = OrderEntity(
      id: 'ord-1001',
      orderNumber: 'ORD-NOV-1001',
      customerName: 'Fatima Aliyu',
      customerPhone: '08031112233',
      deliveryState: 'FCT - Abuja',
      deliveryCity: 'Wuse 2',
      deliveryAddress: 'No 12 Adetokunbo Ademola Crescent',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 52000.0,
      upsellAmount: 0.0,
      totalAmount: 52000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      clientDeliveryFee: 1500.0,
      financialSettlementStatus: 'in_dc_custody',
      remittanceStatus: 'unremitted',
      deliveredAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final order2 = OrderEntity(
      id: 'ord-1002',
      orderNumber: 'ORD-NOV-1002',
      customerName: 'Chinedu Okafor',
      customerPhone: '08092223344',
      deliveryState: 'FCT - Abuja',
      deliveryCity: 'Gwarinpa',
      deliveryAddress: '3rd Avenue, House 24',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 22000.0,
      upsellAmount: 0.0,
      totalAmount: 22000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      clientDeliveryFee: 1500.0,
      financialSettlementStatus: 'in_dc_custody',
      remittanceStatus: 'unremitted',
      deliveredAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final order3 = OrderEntity(
      id: 'ord-1003',
      orderNumber: 'ORD-NOV-1003',
      customerName: 'Ibrahim Musa',
      customerPhone: '08123334455',
      deliveryState: 'FCT - Abuja',
      deliveryCity: 'Maitama',
      deliveryAddress: 'Aguiyi Ironsi Way',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 2,
      basePrice: 57000.0,
      upsellAmount: 0.0,
      totalAmount: 57000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      clientDeliveryFee: 1500.0,
      financialSettlementStatus: 'in_dc_custody',
      remittanceStatus: 'unremitted',
      deliveredAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final orderInTransit = OrderEntity(
      id: 'ord-in-transit',
      orderNumber: 'ORD-NOV-9999',
      customerName: 'Amina Bello',
      customerPhone: '08076543210',
      deliveryState: 'FCT - Abuja',
      deliveryCity: 'Jabi',
      deliveryAddress: 'Jabi Lake Mall',
      productName: 'Respira Detox Tea',
      status: 'in_transit',
      quantity: 1,
      basePrice: 30000.0,
      upsellAmount: 0.0,
      totalAmount: 30000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      clientDeliveryFee: 2000.0,
      financialSettlementStatus: 'pending_remittance',
      remittanceStatus: 'unremitted',
      createdAt: DateTime.now(),
    );

    final orderAlreadySettled = OrderEntity(
      id: 'ord-settled',
      orderNumber: 'ORD-NOV-0001',
      customerName: 'Emeka Nwosu',
      customerPhone: '08055554433',
      deliveryState: 'FCT - Abuja',
      deliveryCity: 'Asokoro',
      deliveryAddress: 'Yakubu Gowon Crescent',
      productName: 'Respira Detox Tea',
      status: 'delivered',
      quantity: 1,
      basePrice: 40000.0,
      upsellAmount: 0.0,
      totalAmount: 40000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'collected',
      clientDeliveryFee: 2500.0,
      financialSettlementStatus: 'client_settled',
      remittanceStatus: 'remitted',
      deliveredAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );

    test('completedOrdersAwaitingRemittance accurately filters unremitted delivered orders', () {
      final state = ClientPortalState(
        clientProfile: clientProfile,
        orders: [order1, order2, order3, orderInTransit, orderAlreadySettled],
      );

      expect(state.todayCompletedOrdersCount, equals(3));
      final orderNumbers = state.completedOrdersAwaitingRemittance.map((o) => o.orderNumber).toList();
      expect(orderNumbers, containsAll(['ORD-NOV-1001', 'ORD-NOV-1002', 'ORD-NOV-1003']));
      expect(orderNumbers.contains('ORD-NOV-9999'), isFalse);
      expect(orderNumbers.contains('ORD-NOV-0001'), isFalse);
    });

    test('todayGrossCashHolding correctly aggregates total gross collected across delivered orders', () {
      final state = ClientPortalState(
        clientProfile: clientProfile,
        orders: [order1, order2, order3, orderInTransit],
      );

      // 52000 + 22000 + 57000 = 131000
      expect(state.todayGrossCashHolding, equals(131000.0));
      expect(state.todayPhysicalCodInVault, equals(131000.0));
      expect(state.todayDigitalDirectTransfers, equals(0.0));
    });

    test('todayLogisticsDeliveryFees and todayNetExpectedPayout accurately deduct charges', () {
      final state = ClientPortalState(
        clientProfile: clientProfile,
        orders: [order1, order2, order3],
      );

      // Fees: 1500 * 3 = 4500
      expect(state.todayLogisticsDeliveryFees, equals(4500.0));
      expect(state.todayTotalChargesDeducted, equals(4500.0));

      // Net: 131000 - 4500 = 126500
      expect(state.todayNetExpectedPayout, equals(126500.0));
    });

    test('status filter awaiting_closeout yields only unremitted delivered orders', () {
      final state = ClientPortalState(
        clientProfile: clientProfile,
        orders: [order1, order2, order3, orderInTransit, orderAlreadySettled],
        selectedStatusFilter: 'awaiting_closeout',
      );

      expect(state.filteredOrders.length, equals(3));
      expect(state.filteredOrders.every((o) => o.isDelivered && !o.isRemitted), isTrue);
    });
  });
}
