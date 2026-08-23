import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Direct Transfer & "My Balance" Population Verification Suite', () {
    const testRider = UserModel(
      id: 'b1111111-1111-4111-8111-111111111111',
      email: 'joel.odufu@novaexpress.ng',
      firstName: 'Joel',
      lastName: 'Odufu',
      phone: '08031234567',
      role: 'delivery_agent',
      deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
      deliveryAgentCode: 'PDA-7000',
      commissionRate: 1000.0,
      transportAllowance: 1500.0,
      failedDeliveryAllowance: 500.0,
      compensationType: 'commission',
    );

    final now = DateTime.now();

    test('1. Direct transfer orders populate My Balance and do NOT inflate physical cash to remit', () {
      final directTransferOrder = OrderEntity(
        id: 'ord-mnfy-001',
        orderNumber: 'ORD-MNFY-01',
        customerName: 'Alhaji Gambo',
        customerPhone: '08034567890',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '15 Aminu Kano Crescent',
        productName: 'Respira Detox Vitality',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        deliveryNotes: '[POD Paid via Monnify Direct Transfer • Ref: MNFY-001] ₦0 cash held by PDA. Commission credited to My Balance.',
        agentEntitlement: 2500.0,
        createdAt: now,
      );

      expect(directTransferOrder.isDirectTransfer, isTrue);
      expect(directTransferOrder.isCashPod, isFalse);

      final summary = FinancialSummary.calculate(
        orders: [directTransferOrder],
        remittances: <RemittanceEntity>[],
        user: testRider,
      );

      // Rider holds ₦0 cash
      expect(summary.cashCollectedAllTime, equals(0.0));
      expect(summary.cashCollectedToday, equals(0.0));
      expect(summary.pendingRemittanceToDC, equals(0.0));

      // Rider's My Balance is populated with their full ₦2,500 earnings!
      expect(summary.myDirectTransfersBalance, equals(2500.0));
      expect(summary.totalMonthEarnings, equals(2500.0));
      expect(summary.deliveredPrepaidOrdersCount, equals(1));
      expect(summary.deliveredCashOrdersCount, equals(0));
    });

    test('2. Cash POD orders allow rider to retain earnings in hand and remit the net to DC', () {
      final cashOrder = OrderEntity(
        id: 'ord-cash-001',
        orderNumber: 'ORD-CASH-01',
        customerName: 'Madam Comfort',
        customerPhone: '08098765432',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: '20 Moshood Abiola Way',
        productName: 'Alpha Man Vitality',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        agentEntitlement: 2500.0,
        createdAt: now,
      );

      expect(cashOrder.isDirectTransfer, isFalse);
      expect(cashOrder.isCashPod, isTrue);

      final summary = FinancialSummary.calculate(
        orders: [cashOrder],
        remittances: <RemittanceEntity>[],
        user: testRider,
      );

      // Rider collected ₦25,000 cash, retained ₦2,500, owes ₦22,500 to DC
      expect(summary.cashCollectedAllTime, equals(25000.0));
      expect(summary.totalEarningRetained, equals(2500.0));
      expect(summary.pendingRemittanceToDC, equals(22500.0));

      // My Balance from direct transfers is 0 since rider already held cash
      expect(summary.myDirectTransfersBalance, equals(0.0));
      expect(summary.totalMonthEarnings, equals(2500.0));
      expect(summary.deliveredCashOrdersCount, equals(1));
      expect(summary.deliveredPrepaidOrdersCount, equals(0));
    });

    test('3. Mixed manifest with both Direct Transfer and Cash POD computes both ledgers accurately', () {
      final directTransferOrder = OrderEntity(
        id: 'ord-dt-01',
        orderNumber: 'ORD-DT-01',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: '15 Aminu Kano Crescent',
        productName: 'Respira Tea',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        deliveryNotes: '[POD Paid via Monnify Direct Transfer • Ref: MNFY-001] ₦0 cash held by PDA. Commission credited to My Balance.',
        agentEntitlement: 2500.0,
        createdAt: now,
      );

      final cashOrder = OrderEntity(
        id: 'ord-cash-01',
        orderNumber: 'ORD-CASH-01',
        customerName: 'Customer B',
        customerPhone: '08022222222',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: '20 Moshood Abiola Way',
        productName: 'Alpha Man Vitality',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        agentEntitlement: 2500.0,
        createdAt: now,
      );

      final summary = FinancialSummary.calculate(
        orders: [directTransferOrder, cashOrder],
        remittances: <RemittanceEntity>[],
        user: testRider,
      );

      // Physical cash collected = ₦25,000 (from order B only)
      expect(summary.cashCollectedAllTime, equals(25000.0));
      // Net to remit to DC = ₦22,500
      expect(summary.pendingRemittanceToDC, equals(22500.0));
      // My Balance to withdraw = ₦2,500 (from order A direct transfer)
      expect(summary.myDirectTransfersBalance, equals(2500.0));
      // Total monthly earnings = ₦5,000 (₦2,500 + ₦2,500)
      expect(summary.totalMonthEarnings, equals(5000.0));
    });
  });
}
