import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/domain/entities/transaction_item.dart';
import 'package:novexps/features/finance/domain/repositories/finance_repository.dart';
import 'package:novexps/features/finance/presentation/pages/remittance_details_page.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

class FakeFinanceRepository implements FinanceRepository {
  final List<RemittanceEntity> predefinedRemittances;

  FakeFinanceRepository({this.predefinedRemittances = const []});

  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String agentId) async {
    return predefinedRemittances;
  }

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async {
    return {
      'channel': 'Dedicated Virtual Account (NUBAN)',
      'verification_status': 'verified',
      'payer_name': 'Aisha Bello',
      'payer_email': 'aisha@example.com',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async => [];

  @override
  Future<List<TransactionItem>> getRiderTransactions(String agentId) async => [];

  @override
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async => {};

  @override
  Future<RemittanceEntity> submitRemittance({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
  }) async {
    return RemittanceEntity(
      id: 'rem-new',
      referenceNumber: referenceNumber ?? 'PSTK-TEST',
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      failedStipendsDeducted: failedStipendsDeducted,
      associatedOrders: associatedOrders,
      createdAt: DateTime.now(),
    );
  }
}

class TestFinanceNotifier extends FinanceNotifier {
  TestFinanceNotifier(List<RemittanceEntity> initialList)
      : super(FakeFinanceRepository(predefinedRemittances: initialList), storageService: LocalStorageServiceImpl()) {
    state = state.copyWith(remittances: initialList);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Remittance Official Receipt & Itemized Order Breakdown Suite', () {
    test('1. RemittanceOrderItem calculates net contribution accurately for delivered vs failed orders', () {
      // Delivered POD Order
      final deliveredOrder = RemittanceOrderItem(
        orderId: 'ord-001',
        orderNumber: 'ORD-9001',
        customerName: 'Aisha Bello',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 30000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        failedStipend: 0.0,
        date: DateTime.now(),
      );

      expect(deliveredOrder.isDelivered, isTrue);
      expect(deliveredOrder.isFailed, isFalse);
      // Net contribution: 30,000 - 1,000 - 1,500 = 27,500
      expect(deliveredOrder.netContribution, equals(27500.0));

      // Failed Delivery Attempt Order (with ₦500 rider stipend)
      final failedOrder = RemittanceOrderItem(
        orderId: 'ord-002',
        orderNumber: 'ORD-9002-F',
        customerName: 'Tunde Bakare',
        status: 'failed',
        paymentType: 'pay_on_delivery',
        cashCollected: 0.0,
        riderCommission: 0.0,
        transportAllowance: 0.0,
        failedStipend: 500.0,
        date: DateTime.now(),
      );

      expect(failedOrder.isDelivered, isFalse);
      expect(failedOrder.isFailed, isTrue);
      // Failed order gives a negative net contribution (stipend credit reducing cash to remit)
      expect(failedOrder.netContribution, equals(-500.0));
    });

    test('2. RemittanceEntity aggregates order breakdowns and computes counts and deductions', () {
      final order1 = RemittanceOrderItem(
        orderId: 'ord-001',
        orderNumber: 'ORD-9001',
        customerName: 'Aisha Bello',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 30000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        failedStipend: 0.0,
        date: DateTime.now(),
      );

      final order2 = RemittanceOrderItem(
        orderId: 'ord-002',
        orderNumber: 'ORD-9002',
        customerName: 'Emeka Obi',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 20000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        failedStipend: 0.0,
        date: DateTime.now(),
      );

      final orderFailed = RemittanceOrderItem(
        orderId: 'ord-003',
        orderNumber: 'ORD-9003-F',
        customerName: 'Chinedu Eze',
        status: 'failed',
        paymentType: 'pay_on_delivery',
        cashCollected: 0.0,
        riderCommission: 0.0,
        transportAllowance: 0.0,
        failedStipend: 500.0,
        date: DateTime.now(),
      );

      final remittance = RemittanceEntity(
        id: 'rem-101',
        referenceNumber: 'PSTK-RMT-TEST-001',
        amount: 44500.0, // 50,000 - 2,000 - 3,000 - 500 = 44,500
        grossCollections: 50000.0,
        commissionDeducted: 2000.0,
        transportAllowanceDeducted: 3000.0,
        failedStipendsDeducted: 500.0,
        paymentMethod: 'paystack',
        status: 'verified',
        createdAt: DateTime.now(),
        associatedOrders: [order1, order2, orderFailed],
      );

      expect(remittance.ordersCount, equals(3));
      expect(remittance.deliveredOrdersCount, equals(2));
      expect(remittance.failedOrdersCount, equals(1));
      expect(remittance.totalDeductions, equals(5500.0));
      expect(remittance.grossCollections - remittance.totalDeductions, equals(44500.0));
    });

    testWidgets('3. RemittanceDetailsPage renders official receipt and order breakdown cards', (tester) async {
      final order1 = RemittanceOrderItem(
        orderId: 'ord-001',
        orderNumber: 'ORD-9001',
        customerName: 'Aisha Bello',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 30000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        failedStipend: 0.0,
        date: DateTime.now(),
      );

      final orderFailed = RemittanceOrderItem(
        orderId: 'ord-002',
        orderNumber: 'ORD-9002-F',
        customerName: 'Tunde Bakare',
        status: 'failed',
        paymentType: 'pay_on_delivery',
        cashCollected: 0.0,
        riderCommission: 0.0,
        transportAllowance: 0.0,
        failedStipend: 500.0,
        date: DateTime.now(),
      );

      final testRemittance = RemittanceEntity(
        id: 'rem-test-xyz',
        referenceNumber: 'PSTK-RMT-XYZ',
        amount: 27000.0,
        grossCollections: 30000.0,
        commissionDeducted: 1000.0,
        transportAllowanceDeducted: 1500.0,
        failedStipendsDeducted: 500.0,
        paymentMethod: 'paystack',
        status: 'verified',
        createdAt: DateTime.now(),
        associatedOrders: [order1, orderFailed],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeProvider.overrideWith((ref) => TestFinanceNotifier([testRemittance])),
            paystackTxnDetailsProvider('PSTK-RMT-XYZ').overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: RemittanceDetailsPage(remittanceId: 'rem-test-xyz'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Official Receipt Header & Reference
      expect(find.text('Official Remittance Receipt'), findsOneWidget);
      expect(find.text('PSTK-RMT-XYZ'), findsWidgets);

      // Total Paid
      expect(find.text('TOTAL REMITTANCE PAID'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatNaira(27000.0)), findsWidgets);

      // Reconciliation section
      expect(find.text('SETTLEMENT RECONCILIATION'), findsOneWidget);
      expect(find.text('Customer Collections (POD Cash)'), findsOneWidget);
      expect(find.text('Less: Failed Delivery Stipends (1 Drops)'), findsOneWidget);

      // Reconciled Orders Breakdown section
      expect(find.text('RECONCILED ORDERS BREAKDOWN'), findsOneWidget);
      expect(find.text('ORD-9001'), findsOneWidget);
      expect(find.text('Aisha Bello'), findsOneWidget);
      expect(find.text('CASH POD'), findsOneWidget);

      // Failed attempt order with stipend
      expect(find.text('ORD-9002-F'), findsOneWidget);
      expect(find.text('Tunde Bakare'), findsOneWidget);
      expect(find.text('FAILED ATTEMPT'), findsOneWidget);

      // Action Buttons
      expect(find.text('Copy & Share Receipt Summary'), findsOneWidget);
      expect(find.text('Download Receipt as Image (PNG)'), findsWidgets);
    });

    test('4. FinancialSummary dynamically accumulates remittances and reconciles custody balance', () {
      final order1 = OrderEntity(
        id: 'ord-01',
        orderNumber: 'ORD-001',
        customerName: 'Aisha Bello',
        customerPhone: '08012345678',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki',
        deliveryAddress: 'Lekki Phase 1',
        productName: 'Solar Lamp',
        quantity: 1,
        basePrice: 30000.0,
        upsellAmount: 0.0,
        totalAmount: 30000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        status: 'delivered',
        createdAt: DateTime.now(),
      );

      final order2 = OrderEntity(
        id: 'ord-02',
        orderNumber: 'ORD-002',
        customerName: 'Emeka Obi',
        customerPhone: '08098765432',
        deliveryState: 'Lagos',
        deliveryCity: 'Victoria Island',
        deliveryAddress: 'Victoria Island',
        productName: 'Power Bank',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        status: 'delivered',
        createdAt: DateTime.now(),
      );

      final orderFailed = OrderEntity(
        id: 'ord-03',
        orderNumber: 'ORD-003',
        customerName: 'Tunde Bakare',
        customerPhone: '08011223344',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Ikeja',
        productName: 'Headphones',
        quantity: 1,
        basePrice: 15000.0,
        upsellAmount: 0.0,
        totalAmount: 15000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        status: 'failed',
        createdAt: DateTime.now(),
      );

      final List<OrderEntity> orders = [order1, order2, orderFailed];

      const mockUser = UserEntity(
        id: 'usr-01',
        email: 'rider@novaexpress.ng',
        firstName: 'Joel',
        lastName: 'Odufu',
        phone: '08012345678',
        role: 'delivery_agent',
        personnelType: 'pda',
        compensationType: 'commission',
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
        failedDeliveryAllowance: 500.0,
        vehiclePlateNumber: 'KJA-123-XY',
        operatingState: 'Lagos',
        operatingCity: 'Ikeja',
        bankName: 'GTBank',
        bankAccountNumber: '0123456789',
        bankAccountName: 'Joel Odufu',
        agentStatus: 'available',
      );

      // Initial state: 0 remittances submitted
      // Gross Cash POD: 50,000.
      // Earnings retained: (1,000 commission + 1,500 transport) * 2 = 5,000 + 500 failed stipend = 5,500.
      // Expected to remit: 50,000 - 5,500 = 44,500.
      final summaryBefore = FinancialSummary.calculate(
        orders: orders,
        remittances: const [],
        user: mockUser,
      );

      expect(summaryBefore.cashCollectedAllTime, equals(50000.0));
      expect(summaryBefore.totalCommissionRetained, equals(2000.0));
      expect(summaryBefore.totalTransportRetained, equals(3000.0));
      expect(summaryBefore.totalEarningRetained, equals(5500.0));
      expect(summaryBefore.totalVerifiedRemitted, equals(0.0));
      expect(summaryBefore.pendingRemittanceToDC, equals(44500.0));

      // Rider submits partial remittance of ₦20,000
      final partialRemittance = RemittanceEntity(
        id: 'rem-part',
        referenceNumber: 'PSTK-RMT-PART',
        amount: 20000.0,
        paymentMethod: 'paystack',
        status: 'verified',
        createdAt: DateTime.now(),
      );

      final summaryPartial = FinancialSummary.calculate(
        orders: orders,
        remittances: [partialRemittance],
        user: mockUser,
      );

      expect(summaryPartial.totalVerifiedRemitted, equals(20000.0));
      expect(summaryPartial.totalRemittedAllTime, equals(20000.0));
      // Remaining custody to remit: 44,500 - 20,000 = 24,500
      expect(summaryPartial.pendingRemittanceToDC, equals(24500.0));

      // Rider submits final remittance of ₦24,500
      final finalRemittance = RemittanceEntity(
        id: 'rem-final',
        referenceNumber: 'PSTK-RMT-FINAL',
        amount: 24500.0,
        paymentMethod: 'paystack',
        status: 'verified',
        createdAt: DateTime.now(),
      );

      final summaryCleared = FinancialSummary.calculate(
        orders: orders,
        remittances: [partialRemittance, finalRemittance],
        user: mockUser,
      );

      expect(summaryCleared.totalVerifiedRemitted, equals(44500.0));
      expect(summaryCleared.totalRemittedAllTime, equals(44500.0));
      // Completely reconciled!
      expect(summaryCleared.pendingRemittanceToDC, equals(0.0));
    });
  });
}
