import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/core/services/paystack_service.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/pages/confirm_delivery_pod_page.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testOrder = OrderEntity(
    id: 'ord-test-paystack-001',
    orderNumber: 'ORD-EMEKA-0046',
    customerName: 'Aba Resident',
    customerPhone: '08031234567',
    customerAltPhone: '08099887766',
    deliveryState: 'Rivers',
    deliveryCity: 'Port Harcourt',
    deliveryAddress: '5 Aba Road, Port Harcourt, Nigeria',
    status: 'in_transit',
    quantity: 1,
    basePrice: 18500.0,
    upsellAmount: 0.0,
    totalAmount: 18500.0,
    paymentType: 'pay_on_delivery',
    paymentStatus: 'pending',
    createdAt: DateTime.now(),
  );

  const testRider = UserEntity(
    id: 'c32c038f-ff3d-4a4f-867d-a749092fb2a9',
    companyId: '11111111-1111-4111-8111-111111111111',
    email: 'joel.odufu@novaexpress.ng',
    phone: '08031234567',
    firstName: 'Joel',
    lastName: 'Odufu',
    role: 'delivery_agent',
    deliveryAgentId: 'c32c038f-ff3d-4a4f-867d-a749092fb2a9',
    deliveryAgentCode: 'PDA-7182',
    personnelType: 'pda',
    commissionRate: 1000.0,
    transportAllowance: 1500.0,
  );

  group('POD Payment Methods & Paystack Flow Tests', () {
    test('OrderEntity correctly identifies Cash POD vs Paystack Direct Transfer', () {
      final cashOrder = testOrder.copyWith(paymentType: 'pay_on_delivery', paymentStatus: 'pending');
      expect(cashOrder.isCashPod, isTrue);
      expect(cashOrder.isDirectTransfer, isFalse);

      final paystackOrder = testOrder.copyWith(paymentType: 'prepaid', paymentStatus: 'paid');
      expect(paystackOrder.isDirectTransfer, isTrue);
      expect(paystackOrder.isCashPod, isFalse);

      final transferOrder = testOrder.copyWith(paymentType: 'paystack', paymentStatus: 'paid');
      expect(transferOrder.isDirectTransfer, isTrue);
      expect(transferOrder.isCashPod, isFalse);
    });

    test('TransactionFeeCalculator dynamically computes ₦100 per ₦5,000 block', () {
      expect(TransactionFeeCalculator.calculateTransferFee(5000.0), equals(100.0));
      expect(TransactionFeeCalculator.calculateTransferFee(5200.0), equals(200.0));
      expect(TransactionFeeCalculator.calculateTransferFee(18500.0), equals(400.0));
      expect(TransactionFeeCalculator.calculateTransferFee(35000.0), equals(700.0));
    });

    test('Deterministic Paystack Virtual Account generation is stable', () {
      final va1 = PaystackService.generateDeterministicAccountNumber('ORD-EMEKA-0046');
      final va2 = PaystackService.generateDeterministicAccountNumber('ORD-EMEKA-0046');
      expect(va1, equals(va2));
      expect(va1.length, equals(10));
      expect(va1.startsWith('99'), isTrue);
    });

    test('FinancialSummary factors in commission, transport and transfer charge in remittance', () {
      final cashOrder = testOrder.copyWith(status: 'delivered', paymentType: 'pay_on_delivery');
      final paystackOrder = testOrder.copyWith(
        id: 'ord-test-002',
        status: 'delivered',
        paymentType: 'prepaid',
        agentEntitlement: 2500.0,
      );

      final summary = FinancialSummary.calculate(
        orders: [cashOrder, paystackOrder],
        remittances: [],
        user: testRider,
      );

      // Cash in custody comes from Cash POD (18,500 - 1,000 commission - 1,500 transport - 400 transfer fee = 15,600 pending remittance)
      expect(summary.cashCollectedAllTime, equals(18500.0));
      expect(summary.totalTransferFeesRetained, equals(400.0));
      expect(summary.pendingRemittanceToDC, equals(15600.0));

      // Direct transfer earnings credit to myDirectTransfersBalance
      expect(summary.myDirectTransfersBalance, equals(2500.0));
    });

    testWidgets('ConfirmDeliveryPodPage renders Payment Breakdown and Cash Remittance Matrix', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([testOrder])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testRider)),
          ],
          child: const MaterialApp(
            home: ConfirmDeliveryPodPage(orderId: 'ord-test-paystack-001'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Hero Card
      expect(find.text('CONFIRM POD PAYMENT'), findsOneWidget);
      expect(find.text('#ORD-EMEKA-0046'), findsOneWidget);
      expect(find.text('₦18,500.00'), findsWidgets);

      // Verify EXACTLY TWO payment methods: Cash and Direct Transfer (Paystack)
      expect(find.text('💵 Cash'), findsOneWidget);
      expect(find.text('Direct Transfer (Paystack)'), findsOneWidget);

      // Verify POS IS COMPLETELY REMOVED
      expect(find.text('💳 POS'), findsNothing);
      expect(find.text('POS'), findsNothing);

      // By default Cash is selected -> Cash breakdown is rendered with dynamic fee
      expect(find.text('Enter Physical Cash Collected'), findsOneWidget);
      expect(find.text('CASH REMITTANCE BREAKDOWN'), findsOneWidget);
      expect(find.text('Less: Transfer Fee (Dynamic)'), findsOneWidget);
      expect(find.text('NET CASH TO REMIT TO DC'), findsOneWidget);

      // Switch to Direct Transfer (Paystack)
      await tester.tap(find.text('Direct Transfer (Paystack)'));
      await tester.pumpAndSettle();

      // Verify Paystack Payment Breakdown UI appears
      expect(find.text('PAYSTACK PAYMENT BREAKDOWN'), findsOneWidget);
      expect(find.text('RETURNING TO "MY BALANCE"'), findsOneWidget);
      expect(find.text('Proceed to Pay via Paystack'), findsOneWidget);
      expect(find.text('Check Status'), findsOneWidget);
      expect(find.text('Settled Directly to Company'), findsOneWidget);
      expect(find.text('Enter Physical Cash Collected'), findsNothing);

      // Switch back to Cash
      await tester.tap(find.text('💵 Cash'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Physical Cash Collected'), findsOneWidget);
      expect(find.text('PAYSTACK PAYMENT BREAKDOWN'), findsNothing);
    });
  });
}

class MockTestOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  MockTestOrdersNotifier(List<OrderEntity> orders) : super(OrdersState(orders: orders));

  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
  }) async => {'status': 'success'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockTestAuthNotifier(UserEntity user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
