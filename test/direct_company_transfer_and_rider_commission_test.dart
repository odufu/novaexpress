import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Direct Company Transfer and Rider Entitlement Verification', () {
    const testUser = UserEntity(
      id: 'rider-001',
      deliveryAgentId: 'agent-001',
      role: 'rider',
      firstName: 'Sunday',
      lastName: 'Joshua',
      email: 'sunday@novaxpress.ng',
      phone: '08012345678',
      personnelType: 'pda',
      commissionRate: 1000.0,
      transportAllowance: 1500.0,
      fuelAllowance: 800.0,
      failedDeliveryAllowance: 500.0,
    );

    test('1. DCFinanceSettings supports multiple company receiving bank accounts with default selection', () {
      final settings = DCFinanceSettings(
        companyBankAccounts: [
          const CompanyBankAccount(
            id: 'cba-01',
            bankName: 'Titan Trust Bank',
            accountNumber: '0098234123',
            accountName: 'NovaXpress Logistics Limited',
            isDefault: true,
          ),
          const CompanyBankAccount(
            id: 'cba-02',
            bankName: 'Zenith Bank',
            accountNumber: '1224567890',
            accountName: 'NovaXpress Logistics Limited',
            isDefault: false,
          ),
        ],
      );

      expect(settings.companyBankAccounts.length, 2);
      expect(settings.primaryCompanyAccount.bankName, 'Titan Trust Bank');
      expect(settings.primaryCompanyAccount.accountNumber, '0098234123');

      final serialized = settings.toJson();
      final deserialized = DCFinanceSettings.fromJson(serialized);
      expect(deserialized.companyBankAccounts.length, 2);
      expect(deserialized.primaryCompanyAccount.bankName, 'Titan Trust Bank');
      expect(deserialized.companyBankAccounts[1].bankName, 'Zenith Bank');
    });

    test('2. Direct Company Transfer order is marked as cleared and does NOT count towards unremitted cash POD', () {
      final directTransferOrder = OrderEntity(
        id: 'ord-direct-001',
        orderNumber: 'NX-DIR-101',
        customerName: 'Amina Bello',
        customerPhone: '08012345678',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: '12 Allen Avenue, Ikeja',
        status: 'delivered',
        quantity: 1,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        remittanceStatus: 'direct_transfer',
        financialSettlementStatus: 'direct_transfer_settled',
        deliveryNotes: '[DIRECT COMPANY TRANSFER to Titan Trust Bank (0098234123) • Ref: AMINA-ZENITH-492] Credited +₦2,500 to My Balance. 0 cash held.',
        totalAmount: 35000.0,
        createdAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );

      // Verify domain flags
      expect(directTransferOrder.isDirectTransfer, isTrue);
      expect(directTransferOrder.isPod, isFalse);
      expect(directTransferOrder.isCashPod, isFalse);
      expect(directTransferOrder.isDelivered, isTrue);
      expect(directTransferOrder.isRemitted, isTrue);
      expect(directTransferOrder.isUnremitted, isFalse);
      expect(directTransferOrder.isPendingClearance, isFalse);
    });

    test('3. FinancialSummary calculations accurately reflect 0 cash custody and credit rider wallet with entitlement', () {
      final directTransferOrder = OrderEntity(
        id: 'ord-direct-001',
        orderNumber: 'NX-DIR-101',
        customerName: 'Amina Bello',
        customerPhone: '08012345678',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: '12 Allen Avenue, Ikeja',
        status: 'delivered',
        quantity: 1,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        remittanceStatus: 'direct_transfer',
        financialSettlementStatus: 'direct_transfer_settled',
        deliveryNotes: '[DIRECT COMPANY TRANSFER to Titan Trust Bank (0098234123) • Ref: AMINA-ZENITH-492] Credited +₦2,500 to My Balance.',
        totalAmount: 35000.0,
        createdAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );

      final summary = FinancialSummary.calculate(
        orders: [directTransferOrder],
        remittances: const [],
        user: testUser,
      );

      // Cash in custody must be ZERO because customer paid company directly
      expect(summary.cashCollectedAllTime, 0.0);
      expect(summary.cashCollectedToday, 0.0);
      expect(summary.pendingRemittanceToDC, 0.0);
      expect(summary.deliveredCashOrdersCount, 0);

      // Prepaid/Direct transfer count must be 1
      expect(summary.deliveredPrepaidOrdersCount, 1);
      expect(summary.totalDeliveredOrdersCount, 1);

      // Rider's My Balance (direct transfer balance) must be credited with Commission (1000) + Transport (1500) = 2500
      expect(summary.myDirectTransfersBalance, 2500.0);
      expect(summary.totalMonthEarnings, 2500.0);
    });

    test('4. Mixed fleet day: 1 Cash POD order and 1 Direct Transfer order correctly segregate cash custody from wallet balance', () {
      final cashOrder = OrderEntity(
        id: 'ord-cash-001',
        orderNumber: 'NX-CSH-202',
        customerName: 'Emeka Okafor',
        customerPhone: '08087654321',
        deliveryState: 'Lagos',
        deliveryCity: 'Surulere',
        deliveryAddress: '45 Bode Thomas, Surulere',
        status: 'delivered',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        remittanceStatus: 'unremitted',
        totalAmount: 20000.0,
        createdAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );

      final directTransferOrder = OrderEntity(
        id: 'ord-direct-002',
        orderNumber: 'NX-DIR-203',
        customerName: 'Chiamaka Nnamdi',
        customerPhone: '08099887766',
        deliveryState: 'Lagos',
        deliveryCity: 'Yaba',
        deliveryAddress: '10 Commercial Avenue, Yaba',
        status: 'delivered',
        quantity: 1,
        basePrice: 50000.0,
        upsellAmount: 0.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        remittanceStatus: 'direct_transfer',
        financialSettlementStatus: 'direct_transfer_settled',
        deliveryNotes: '[DIRECT COMPANY TRANSFER to Zenith Bank (1224567890) • Ref: CHIA-TRANSFER] Credited +₦2,500 to My Balance.',
        totalAmount: 50000.0,
        createdAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );

      final summary = FinancialSummary.calculate(
        orders: [cashOrder, directTransferOrder],
        remittances: const [],
        user: testUser,
        posFee: 100.0,
      );

      // Cash collected is ONLY from the Cash POD order (20,000)
      expect(summary.cashCollectedAllTime, 20000.0);
      expect(summary.deliveredCashOrdersCount, 1);
      expect(summary.deliveredPrepaidOrdersCount, 1);
      expect(summary.totalDeliveredOrdersCount, 2);

      // Net cash remittance to DC = 20,000 - 1,000 commission - 1,500 transport - 100 POS fee = 17,400
      expect(summary.pendingRemittanceToDC, 17400.0);

      // My Balance (Withdrawable Asset for Direct Transfer) = 2,500 from the direct transfer order
      expect(summary.myDirectTransfersBalance, 2500.0);

      // Total earnings across both orders = 2,500 (from cash retained) + 2,500 (from company direct transfer) = 5,000
      expect(summary.totalMonthEarnings, 5000.0);
    });
  });
}
