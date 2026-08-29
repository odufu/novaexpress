import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/finance/domain/entities/financial_summary.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/domain/entities/transaction_item.dart';
import 'package:novexps/features/finance/domain/repositories/finance_repository.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/repositories/orders_repository.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

class MockFinanceRepository implements FinanceRepository {
  List<RemittanceEntity> storedRemittances = [];
  List<TransactionItem> storedTransactions = [];

  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String agentId) async => storedRemittances;

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async => null;

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async => [];

  @override
  Future<List<TransactionItem>> getRiderTransactions(String agentId) async => storedTransactions;

  @override
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async => {'status': 'success'};

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
    final rem = RemittanceEntity(
      id: 'rem-101',
      referenceNumber: referenceNumber ?? 'PSTK-RMT-101',
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      failedStipendsDeducted: failedStipendsDeducted,
      posFee: posFee,
      paymentMethod: paymentMethod,
      status: 'verified',
      associatedOrders: associatedOrders,
      createdAt: DateTime.now(),
      verifiedAt: DateTime.now(),
    );
    storedRemittances.add(rem);
    return rem;
  }
}

class MockOrdersRepository implements OrdersRepository {
  List<OrderEntity> ordersList = [];

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async => ordersList;

  @override
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async => ordersList;

  @override
  Future<OrderEntity> getOrderById(String orderId) async =>
      ordersList.firstWhere((o) => o.id == orderId);

  @override
  Future<OrderEntity> createOrder(Map<String, dynamic> orderData) async {
    return OrderEntity(
      id: orderData['id'] ?? 'ord-new',
      orderNumber: orderData['order_number'] ?? 'ORD-NEW',
      customerName: orderData['customer_name'] ?? 'Test Customer',
      customerPhone: orderData['customer_phone'] ?? '08000000000',
      deliveryState: orderData['delivery_state'] ?? 'Lagos',
      deliveryCity: orderData['delivery_city'] ?? 'Ikeja',
      deliveryAddress: orderData['delivery_address'] ?? 'Street 1',
      status: orderData['status'] ?? 'pending',
      quantity: orderData['quantity'] ?? 1,
      basePrice: orderData['base_price'] ?? 10000.0,
      upsellAmount: orderData['upsell_amount'] ?? 0.0,
      totalAmount: orderData['total_amount'] ?? 10000.0,
      paymentType: orderData['payment_type'] ?? 'pay_on_delivery',
      paymentStatus: orderData['payment_status'] ?? 'pending',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {}

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async {}

  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async => {'status': 'success'};

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cash Remittance, Order Tagging, POS Charges & Rider Balance Suite', () {
    late MockFinanceRepository mockFinanceRepo;
    late MockOrdersRepository mockOrdersRepo;
    late ProviderContainer container;

    setUp(() async {
      mockFinanceRepo = MockFinanceRepository();
      mockOrdersRepo = MockOrdersRepository();
      container = ProviderContainer(
        overrides: [
          financeRepositoryProvider.overrideWithValue(mockFinanceRepo),
          ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
          localStorageServiceProvider.overrideWithValue(LocalStorageServiceImpl()),
        ],
      );
      try {
        await container.read(authProvider.notifier).checkCurrentUser();
      } catch (_) {}
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Each order in remittance breakdown calculates exact net money (cash - personal commission - transport allowance)', () {
      final item1 = RemittanceOrderItem(
        orderId: 'ord-101',
        orderNumber: 'ORD-101',
        customerName: 'Chief Aliyu',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 35000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        posFee: 0.0, // POS charge is per remittance, not per order
        date: DateTime.now(),
      );

      final item2 = RemittanceOrderItem(
        orderId: 'ord-102',
        orderNumber: 'ORD-102',
        customerName: 'Mrs. Fatima Bello',
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        cashCollected: 25000.0,
        riderCommission: 1000.0,
        transportAllowance: 1500.0,
        posFee: 0.0, // POS charge is per remittance, not per order
        date: DateTime.now(),
      );

      // Order 1: 35,000 - 1,000 (commission) - 1,500 (transport) = 32,500
      expect(item1.netContribution, equals(32500.0));
      // Order 2: 25,000 - 1,000 (commission) - 1,500 (transport) = 22,500
      expect(item2.netContribution, equals(22500.0));

      final double totalOrderNet = item1.netContribution + item2.netContribution;
      expect(totalOrderNet, equals(55000.0));

      // Remittance-level POS charge from DC settings (e.g. ₦350 flat or dynamic)
      const dcSettings = DCFinanceSettings(posChargeMode: 'flat', posFlatRate: 350.0);
      final double remittancePosFee = dcSettings.computePosFee(60000.0);
      expect(remittancePosFee, equals(350.0));

      final double finalRemittanceAmount = totalOrderNet - remittancePosFee;
      expect(finalRemittanceAmount, equals(54650.0));
    });

    test('2. DC Console Settings properly calculates dynamic and flat POS charges per remittance', () {
      // Dynamic tiered settings: ₦100 per ₦5,000 tier, capped at ₦1,500
      const dynamicSettings = DCFinanceSettings(
        posChargeMode: 'dynamic',
        posTierAmount: 5000.0,
        posTierFee: 100.0,
        posMaxCapFee: 1500.0,
      );

      // ₦35,000 = (35,000 / 5,000) = 7 tiers * ₦100 = ₦700
      expect(dynamicSettings.computePosFee(35000.0), equals(700.0));

      // ₦100,000 = 20 tiers * ₦100 = ₦2,000 -> capped at ₦1,500
      expect(dynamicSettings.computePosFee(100000.0), equals(1500.0));

      // Flat settings: ₦350 per remittance
      const flatSettings = DCFinanceSettings(
        posChargeMode: 'flat',
        posFlatRate: 350.0,
      );
      expect(flatSettings.computePosFee(50000.0), equals(350.0));
    });

    test('3. Submitting remittance marks contributing orders as remitted in ordersProvider and database', () async {
      final activeUser = container.read(authProvider).user;
      final agentId = activeUser?.deliveryAgentId ?? activeUser?.id ?? 'agent-100';

      final order1 = OrderEntity(
        id: 'ord-101',
        orderNumber: 'NX-901',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: '12 Allen Avenue',
        deliveryAgentId: agentId,
        status: 'delivered',
        quantity: 2,
        basePrice: 15000.0,
        upsellAmount: 0.0,
        totalAmount: 30000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        remittanceStatus: 'unremitted',
        createdAt: DateTime.now(),
      );

      final order2 = OrderEntity(
        id: 'ord-102',
        orderNumber: 'NX-902',
        customerName: 'Customer B',
        customerPhone: '08022222222',
        deliveryState: 'Lagos',
        deliveryCity: 'Lekki',
        deliveryAddress: '5 Admiralty Way',
        deliveryAgentId: agentId,
        status: 'delivered',
        quantity: 1,
        basePrice: 20000.0,
        upsellAmount: 0.0,
        totalAmount: 20000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        remittanceStatus: 'unremitted',
        createdAt: DateTime.now(),
      );

      mockOrdersRepo.ordersList = [order1, order2];
      await container.read(ordersProvider.notifier).loadOrders(agentId);

      // Check initially unremitted
      expect(container.read(ordersProvider).orders.first.isRemitted, isFalse);
      expect(container.read(ordersProvider).orders.first.isUnremitted, isTrue);

      final associatedOrderItems = [
        RemittanceOrderItem(
          orderId: order1.id,
          orderNumber: order1.orderNumber,
          customerName: order1.customerName,
          status: 'delivered',
          paymentType: 'pay_on_delivery',
          cashCollected: order1.totalAmount,
          riderCommission: 1000.0,
          transportAllowance: 1500.0,
          posFee: 0.0,
          date: DateTime.now(),
        ),
        RemittanceOrderItem(
          orderId: order2.id,
          orderNumber: order2.orderNumber,
          customerName: order2.customerName,
          status: 'delivered',
          paymentType: 'pay_on_delivery',
          cashCollected: order2.totalAmount,
          riderCommission: 1000.0,
          transportAllowance: 1500.0,
          posFee: 0.0,
          date: DateTime.now(),
        ),
      ];

      // Submit Remittance
      final success = await container.read(financeProvider.notifier).submitRemittance(
        amount: 45000.0,
        paymentMethod: 'paystack',
        agentId: agentId,
        grossCollections: 50000.0,
        commissionDeducted: 2000.0,
        transportAllowanceDeducted: 3000.0,
        associatedOrders: associatedOrderItems,
      );

      expect(success, isTrue);

      // Verify orders are now badged as remitted
      final updatedOrders = container.read(ordersProvider).orders;
      final updatedOrder1 = updatedOrders.firstWhere((o) => o.id == 'ord-101');
      final updatedOrder2 = updatedOrders.firstWhere((o) => o.id == 'ord-102');

      expect(updatedOrder1.isRemitted, isTrue);
      expect(updatedOrder1.remittanceStatus, equals('remitted'));
      expect(updatedOrder2.isRemitted, isTrue);
      expect(updatedOrder2.remittanceStatus, equals('remitted'));
    });

    test('4. Direct Transfer (Paystack) POD delivery adds ₦0 to cash custody but accumulates rider balance', () async {
      final activeUser = container.read(authProvider).user;
      final agentId = activeUser?.deliveryAgentId ?? activeUser?.id ?? 'agent-100';

      final user = activeUser ?? UserEntity(
        id: agentId,
        email: 'rider.pda@novaexpress.ng',
        firstName: 'Joel',
        lastName: 'Odufu',
        phone: '08012345678',
        role: 'delivery_agent',
        deliveryAgentId: agentId,
        deliveryAgentCode: 'PDA-7182',
        commissionRate: 1000.0,
        transportAllowance: 1500.0,
        personnelType: 'pda',
      );

      final prepaidOrder = OrderEntity(
        id: 'ord-prepaid-1',
        orderNumber: 'NX-PREPAID-1',
        customerName: 'Alhaji Musa',
        customerPhone: '08099999999',
        deliveryState: 'Lagos',
        deliveryCity: 'Victoria Island',
        deliveryAddress: '24 Ozumba Mbadiwe',
        deliveryAgentId: agentId,
        status: 'in_transit',
        quantity: 2,
        basePrice: 25000.0,
        upsellAmount: 0.0,
        totalAmount: 50000.0,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      mockOrdersRepo.ordersList = [prepaidOrder];
      await container.read(ordersProvider.notifier).loadOrders(agentId);

      // Confirm POD via Direct Transfer (Paystack)
      await container.read(ordersProvider.notifier).confirmDeliveryPod(
        orderId: 'ord-prepaid-1',
        agentId: agentId,
        paymentType: 'prepaid',
        paymentMethod: 'bank_transfer',
        amountCollected: 0.0, // ₦0 cash collected by rider
        notes: '[POD Paid via Paystack Direct Transfer] ₦0 cash held by PDA. Commission credited to My Balance.',
      );

      final deliveredOrder = container.read(ordersProvider).orders.first;
      expect(deliveredOrder.isDelivered, isTrue);
      expect(deliveredOrder.isDirectTransfer, isTrue);
      expect(deliveredOrder.isRemitted, isTrue);

      // Verify that rider transactions received earning credit
      final financeState = container.read(financeProvider);
      expect(financeState.transactions.length, equals(1));
      expect(financeState.transactions.first.category, equals('earning'));
      expect(financeState.transactions.first.amount, greaterThan(0.0));

      // Verify FinancialSummary calculates withdrawable balance without increasing cash custody
      final summary = FinancialSummary.calculate(
        orders: container.read(ordersProvider).orders,
        remittances: financeState.remittances,
        user: user,
        manualEarnedBalance: financeState.totalEarnedBalance,
        transactions: financeState.transactions,
      );

      // Cash in custody to remit should be 0
      expect(summary.pendingRemittanceToDC, equals(0.0));
      expect(summary.cashCollectedAllTime, equals(0.0));
      // Withdrawable balance should be accumulated
      expect(summary.myDirectTransfersBalance, greaterThan(0.0));
    });
  });
}
