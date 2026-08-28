import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/constants/paystack_constants.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/core/services/paystack_service.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';
import 'package:novexps/features/finance/presentation/pages/remittance_details_page.dart';
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
        ProviderScope(
          child: MaterialApp(
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
        ProviderScope(
          child: MaterialApp(
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
        ),
      );

      expect(find.textContaining('Paystack Remittance'), findsOneWidget);
      expect(find.text('PAYSTACK'), findsOneWidget);
      expect(find.text('AMOUNT TO REMIT'), findsOneWidget);
      expect(find.text('₦71,000.00'), findsOneWidget);
      expect(find.textContaining('I Have Transferred • Verify'), findsOneWidget);
      expect(confirmedRef, isNull);
    });

    test('7. Partial Remittance properly reconciles actual amount and maintains remaining balance liability', () {
      final now = DateTime.now();

      // Order with gross collections: ₦78,500 across 3 deliveries
      final order1 = OrderEntity(
        id: 'ord-01',
        orderNumber: 'ORD-01',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Wuse 2 Hub St',
        productName: 'Pack A',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 78500.0,
        upsellAmount: 0.0,
        totalAmount: 78500.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        agentEntitlement: 7500.0,
        createdAt: now,
      );

      // Rider owed ₦71,000, but paid ₦50,000 via Paystack
      final partialRemittance = RemittanceEntity(
        id: 'rem-partial-01',
        referenceNumber: 'PSTK-RMT-PARTIAL-01',
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: testRider.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111',
        amount: 50000.0,
        paymentMethod: 'paystack',
        status: 'verified',
        discrepancyAmount: -21000.0,
        discrepancyReason: 'Partial Remittance via Paystack',
        notes: '[PAYSTACK PARTIAL] Paid ₦50,000 of expected ₦71,000.',
        createdAt: now,
      );

      final summary = FinancialSummary.calculate(
        orders: [order1],
        remittances: [partialRemittance],
        user: testRider,
      );

      expect(summary.cashCollectedAllTime, equals(78500.0));
      expect(summary.totalEarningRetained, equals(2500.0));
      expect(summary.totalVerifiedRemitted, equals(50000.0));
      // Remaining pending remittance is exactly ₦26,000 (78500 - 2500 - 50000)
      expect(summary.pendingRemittanceToDC, equals(26000.0));
    });

    test('8. RemittanceModel correctly serializes and deserializes partial fields & remaining shortage', () {
      final now = DateTime.now();
      final jsonPayload = {
        'id': 'rem-json-01',
        'reference_number': 'REM-PARTIAL-JSON',
        'company_id': 'comp-01',
        'delivery_agent_id': 'agent-01',
        'amount': 50000.0,
        'expected_amount': 71000.0,
        'is_partial': true,
        'discrepancy_amount': -21000.0,
        'discrepancy_reason': 'Rider partial payment',
        'status': 'verified',
        'payment_method': 'paystack',
        'created_at': now.toIso8601String(),
      };

      final model = RemittanceModel.fromJson(jsonPayload);
      expect(model.amount, equals(50000.0));
      expect(model.expectedAmount, equals(71000.0));
      expect(model.isPartialRemittance, isTrue);
      expect(model.remainingShortage, equals(21000.0));
      expect(model.discrepancyReason, equals('Rider partial payment'));

      final backToJson = model.toJson();
      expect(backToJson['expected_amount'], equals(71000.0));
      expect(backToJson['is_partial'], isTrue);
      expect(backToJson['discrepancy_amount'], equals(-21000.0));
    });

    test('9. RemittanceModel preserves Paystack transaction channels, processor banks, and auth codes', () {
      final now = DateTime.now();
      final jsonPayload = {
        'id': 'rem-paystack-full',
        'reference_number': 'PSTK-RMT-PDA7182-835804',
        'company_id': 'comp-01',
        'delivery_agent_id': 'agent-01',
        'amount': 20000.0,
        'expected_amount': 20000.0,
        'gross_collections': 128500.0,
        'commission_deducted': 5000.0,
        'transport_allowance_deducted': 7500.0,
        'is_partial': false,
        'status': 'verified',
        'payment_method': 'paystack',
        'paystack_channel': 'Dedicated Virtual Account (NUBAN)',
        'paystack_bank': 'Titan Trust Bank / Paystack',
        'paystack_auth_code': 'AUTH_PSTK_991823',
        'payer_name': 'Joel Odufu',
        'payer_email': 'joel.odufu@novaexpress.ng',
        'gateway_response': 'Approved / Successful (200 OK)',
        'destination_bank_name': 'Zenith Bank',
        'destination_account_number': '1012398412',
        'destination_account_name': 'NovaExpress Logistics Limited',
        'created_at': now.toIso8601String(),
        'paystack_paid_at': now.toIso8601String(),
      };

      final model = RemittanceModel.fromJson(jsonPayload);
      expect(model.referenceNumber, equals('PSTK-RMT-PDA7182-835804'));
      expect(model.paystackChannel, equals('Dedicated Virtual Account (NUBAN)'));
      expect(model.paystackBank, equals('Titan Trust Bank / Paystack'));
      expect(model.paystackAuthCode, equals('AUTH_PSTK_991823'));
      expect(model.payerName, equals('Joel Odufu'));
      expect(model.payerEmail, equals('joel.odufu@novaexpress.ng'));
      expect(model.gatewayResponse, equals('Approved / Successful (200 OK)'));
      expect(model.destinationBankName, equals('Zenith Bank'));

      final json = model.toJson();
      expect(json['paystack_channel'], equals('Dedicated Virtual Account (NUBAN)'));
      expect(json['paystack_bank'], equals('Titan Trust Bank / Paystack'));
      expect(json['paystack_auth_code'], equals('AUTH_PSTK_991823'));
      expect(json['payer_name'], equals('Joel Odufu'));
      expect(json['payer_email'], equals('joel.odufu@novaexpress.ng'));
    });

    testWidgets('10. RemittanceDetailsPage renders reconciliation matrix and Paystack audit metadata', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RemittanceDetailsPage(
              remittanceId: 'PSTK-RMT-PDA7182-835804',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Official Remittance Receipt'), findsOneWidget);
      expect(find.text('PSTK-RMT-PDA7182-835804'), findsWidgets);
      expect(find.text('SETTLEMENT RECONCILIATION'), findsOneWidget);
      expect(find.text('AUDIT & TRANSACTION DETAILS'), findsOneWidget);
      expect(find.text('Customer Collections (POD Cash)'), findsOneWidget);
      expect(find.text('Less: Delivery Commission Retained'), findsOneWidget);
      expect(find.text('Less: Transport Allowance Retained'), findsOneWidget);
      expect(find.text('Expected Handover Due'), findsOneWidget);
      expect(find.text('Actual Remitted Amount'), findsOneWidget);
      expect(find.text('Remitted To'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Transaction Reference'), findsOneWidget);
      expect(find.text('Paystack Channel'), findsOneWidget);
      expect(find.text('Bank / Processor'), findsOneWidget);
      expect(find.text('Share Receipt'), findsOneWidget);
      expect(find.text('Download Statement (PDF)'), findsOneWidget);
    });

    test('11. Multiple delivered cash orders accumulate cash in custody and pending remittance correctly', () {
      final now = DateTime.now();

      final order1 = OrderEntity(
        id: 'ord-cash-1',
        orderNumber: 'ORD-CASH-001',
        customerName: 'Customer One',
        customerPhone: '08011111111',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Area 11',
        productName: 'Herbal Pack 1',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 25000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        createdAt: now.subtract(const Duration(hours: 4)),
      );

      final order2 = OrderEntity(
        id: 'ord-cash-2',
        orderNumber: 'ORD-CASH-002',
        customerName: 'Customer Two',
        customerPhone: '08022222222',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Wuse',
        deliveryAddress: 'Wuse 2',
        productName: 'Herbal Pack 2',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        totalAmount: 35000.0,
        paymentType: 'cash',
        paymentStatus: 'collected',
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final order3 = OrderEntity(
        id: 'ord-cash-3',
        orderNumber: 'ORD-CASH-003',
        customerName: 'Customer Three',
        customerPhone: '08033333333',
        deliveryState: 'FCT - Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: 'Maitama Main',
        productName: 'Herbal Pack 3',
        status: 'delivered',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'cod',
        paymentStatus: 'collected',
        createdAt: now,
      );

      // Accumulation after 3 orders
      final summaryAfter3Orders = FinancialSummary.calculate(
        orders: [order1, order2, order3],
        remittances: <RemittanceEntity>[],
        user: testRider,
      );

      // Gross: 25k + 35k + 20k = 80k
      expect(summaryAfter3Orders.cashCollectedAllTime, equals(80000.0));
      expect(summaryAfter3Orders.deliveredCashOrdersCount, equals(3));
      // Earning retained: 3 orders * (1000 commission + 1500 transport) = 7,500
      expect(summaryAfter3Orders.totalEarningRetained, equals(7500.0));
      // Transfer charges: 0.0
      expect(summaryAfter3Orders.totalTransferFeesRetained, equals(0.0));
      // Pending Remittance to DC: 80,000 - 7,500 = 72,500
      expect(summaryAfter3Orders.pendingRemittanceToDC, equals(72500.0));

      // After partial remittance of 40,000
      final partialRemittance = RemittanceEntity(
        id: 'rem-partial-88',
        referenceNumber: 'PSTK-RMT-PART-88',
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: testRider.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111',
        amount: 40000.0,
        paymentMethod: 'paystack',
        status: 'verified',
        isPartial: true,
        discrepancyAmount: -32500.0,
        createdAt: now,
      );

      final summaryAfterPartialRemittance = FinancialSummary.calculate(
        orders: [order1, order2, order3],
        remittances: [partialRemittance],
        user: testRider,
      );

      // Remaining pending remittance is: 72,500 - 40,000 = 32,500
      expect(summaryAfterPartialRemittance.pendingRemittanceToDC, equals(32500.0));
    });
  });
}
