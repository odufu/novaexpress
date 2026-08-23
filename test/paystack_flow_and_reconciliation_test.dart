import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/constants/paystack_constants.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/services/paystack_service.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/widgets/paystack_transfer_modal.dart';
import 'package:novexps/features/finance/presentation/widgets/paystack_remittance_modal.dart';

void main() {
  group('Paystack Remittance & Direct Transfer Verification Suite', () {
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

    test('1. Paystack Constants and API credentials are appropriately configured', () {
      expect(PaystackConstants.secretKey, equals('sk_test_94f116e6e978f0e75dc42f8a789837931b487006'));
      expect(PaystackConstants.publicKey, equals('pk_test_0ac140673685b32b2e9613b548991cd9563e917a'));
      expect(PaystackConstants.webhookUrl, contains('paystack-webhook'));
      expect(SupabaseConstants.paystackTransactionsTable, equals('paystack_transactions'));
    });

    test('2. PaystackService deterministically generates 10-digit Nuban accounts for order settlement', () {
      final account1 = PaystackService.generateDeterministicAccountNumber('ORD-892401');
      final account2 = PaystackService.generateDeterministicAccountNumber('NX-9012');

      expect(account1.length, equals(10));
      expect(account2.length, equals(10));
      expect(account1.startsWith('99'), isTrue);
      expect(account2.startsWith('99'), isTrue);
    });

    test('3. Paystack Direct Transfer populates My Balance and holds ₦0 cash from customer', () {
      final now = DateTime.now();
      final paystackOrder = OrderEntity(
        id: 'ord-pstk-01',
        orderNumber: 'ORD-PSTK-01',
        customerName: 'Chief Emeka',
        customerPhone: '08039876543',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: '22 Gana Street',
        productName: 'Respira Herbal Blend',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        totalAmount: 35000.0,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        deliveryNotes: '[POD Paid via Paystack Direct Transfer • Ref: PSTK-ORD8924] ₦0 cash held by PDA. Commission credited to My Balance.',
        agentEntitlement: 2500.0,
        createdAt: now,
      );

      expect(paystackOrder.isDirectTransfer, isTrue);
      expect(paystackOrder.isCashPod, isFalse);

      final summary = FinancialSummary.calculate(
        orders: [paystackOrder],
        remittances: <RemittanceEntity>[],
        user: testRider,
      );

      // Rider cash in custody is 0
      expect(summary.cashCollectedAllTime, equals(0.0));
      expect(summary.pendingRemittanceToDC, equals(0.0));

      // ₦2,500 full entitlement credited to My Balance
      expect(summary.myDirectTransfersBalance, equals(2500.0));
      expect(summary.totalMonthEarnings, equals(2500.0));
    });

    test('4. Paystack Remittance instantly auto-reconciles and clears cash-to-remit ledger', () {
      final now = DateTime.now();
      // Order delivered for cash POD
      final cashOrder = OrderEntity(
        id: 'ord-cash-99',
        orderNumber: 'ORD-CASH-99',
        customerName: 'Senator David',
        customerPhone: '08023456789',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Asokoro',
        deliveryAddress: '10 Yakubu Gowon Crescent',
        productName: 'Vitality Booster Pack',
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

      // Rider made an instant Paystack remittance for net amount: ₦22,500
      final verifiedPaystackRemittance = RemittanceEntity(
        id: 'rem-pstk-01',
        referenceNumber: 'PSTK-RMT-89021',
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: testRider.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111',
        amount: 22500.0,
        paymentMethod: 'paystack',
        status: 'verified',
        notes: '[PAYSTACK] Ref: PSTK-RMT-89021 - Auto-verified instant remittance.',
        createdAt: now,
      );

      final summary = FinancialSummary.calculate(
        orders: [cashOrder],
        remittances: [verifiedPaystackRemittance],
        user: testRider,
      );

      // Gross collected ₦25,000, ₦2,500 retained by rider, ₦22,500 remitted via Paystack
      expect(summary.cashCollectedAllTime, equals(25000.0));
      expect(summary.totalEarningRetained, equals(2500.0));
      expect(summary.totalVerifiedRemitted, equals(22500.0));
      // Net pending to DC is now fully cleared to ₦0.00!
      expect(summary.pendingRemittanceToDC, equals(0.0));
    });

    testWidgets('5. PaystackTransferModal renders amount and Paystack branding correctly', (WidgetTester tester) async {
      bool wasConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaystackTransferModal(
              orderNumber: 'ORD-9821',
              amount: 25000.0,
              customerEmail: 'customer@novaexpress.ng',
              customerName: 'Alhaji Gambo',
              onPaymentConfirmed: () {
                wasConfirmed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Paystack Direct Transfer'), findsOneWidget);
      expect(find.text('PAYSTACK'), findsOneWidget);
      expect(find.text('Titan Trust Bank / Paystack'), findsOneWidget);
      expect(find.text('Check Payment Status'), findsOneWidget);
      expect(wasConfirmed, isFalse);
    });

    testWidgets('6. PaystackRemittanceModal renders amount, interactive portal and instant settlement actions', (WidgetTester tester) async {
      String? confirmedRef;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaystackRemittanceModal(
              amount: 71000.0,
              riderName: 'Joel Rider',
              riderCode: 'PDA-7000',
              onRemittanceConfirmed: (ref) {
                confirmedRef = ref;
              },
            ),
          ),
        ),
      );

      expect(find.text('Paystack Remittance'), findsOneWidget);
      expect(find.text('PAYSTACK'), findsOneWidget);
      expect(find.text('AMOUNT TO REMIT'), findsOneWidget);
      expect(find.text('₦71,000.00'), findsOneWidget);
      expect(find.text('PAYSTACK INTERACTIVE PORTAL'), findsOneWidget);
      expect(find.text('Card 💳'), findsOneWidget);
      expect(find.text('Transfer 🏦'), findsOneWidget);
      expect(find.text('USSD 📱'), findsOneWidget);
      expect(find.text('I Have Transferred • Verify Settlement'), findsOneWidget);
      expect(confirmedRef, isNull);
    });
  });
}
