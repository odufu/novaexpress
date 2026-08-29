import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_order_payment_matching_page.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_remittance_detail_modal.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class MockTestOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  MockTestOrdersNotifier(List<OrderEntity> orders)
      : super(OrdersState(orders: orders, isLoading: false));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  Future<void> updateOrderPaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String remittanceStatus,
  }) async {
    final updatedList = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(paymentStatus: paymentStatus, remittanceStatus: remittanceStatus);
      }
      return o;
    }).toList();
    state = state.copyWith(orders: updatedList);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestFinanceNotifier extends StateNotifier<FinanceState> implements FinanceNotifier {
  MockTestFinanceNotifier(List<RemittanceEntity> remittances)
      : super(FinanceState(remittances: remittances, isLoading: false));

  @override
  Future<void> loadRemittances([String? agentId]) async {}

  @override
  Future<bool> submitRemittance({
    String? agentId,
    String? companyId,
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
    final newRem = RemittanceEntity(
      id: 'rem-new-01',
      referenceNumber: referenceNumber ?? 'REM-CASH-7000',
      companyId: companyId ?? '22222222-2222-4222-8222-222222222222',
      deliveryAgentId: agentId ?? 'rider-001',
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      posFee: posFee,
      paymentMethod: paymentMethod,
      status: 'verified',
      associatedOrders: associatedOrders,
      createdAt: DateTime.now(),
      verifiedAt: DateTime.now(),
    );
    state = state.copyWith(remittances: [newRem, ...state.remittances]);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockTestAuthNotifier(UserEntity user)
      : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier([List<StockItemEntity> items = const []])
      : super(StockState(stockItems: items, isLoading: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final order1Cash = OrderEntity(
    id: 'ord-cash-101',
    orderNumber: 'NX-ORD-101',
    customerName: 'Amina Bello',
    customerPhone: '08031234567',
    deliveryState: 'FCT - Abuja',
    deliveryCity: 'Maitama',
    deliveryAddress: '14 Gana Street, Maitama',
    status: 'delivered',
    quantity: 1,
    productName: 'Respira Detox Tea',
    basePrice: 35000.0,
    upsellAmount: 0.0,
    totalAmount: 35000.0,
    paymentType: 'pay_on_delivery',
    paymentStatus: 'collected',
    remittanceStatus: 'unremitted',
    deliveryAgentId: 'rider-001',
    deliveryAgentName: 'Emeka Rider',
    deliveryAgentCode: 'PDA-7000',
    createdAt: DateTime(2026, 8, 29, 9, 30),
  );

  final order2Cash = OrderEntity(
    id: 'ord-cash-102',
    orderNumber: 'NX-ORD-102',
    customerName: 'Bala Mohammed',
    customerPhone: '08091234567',
    deliveryState: 'FCT - Abuja',
    deliveryCity: 'Wuse 2',
    deliveryAddress: '24 Aminu Kano, Wuse 2',
    status: 'delivered',
    quantity: 2,
    productName: 'Grazer Herbal Detox Tea',
    basePrice: 55000.0,
    upsellAmount: 0.0,
    totalAmount: 55000.0,
    paymentType: 'pay_on_delivery',
    paymentStatus: 'collected',
    remittanceStatus: 'unremitted',
    deliveryAgentId: 'rider-001',
    deliveryAgentName: 'Emeka Rider',
    deliveryAgentCode: 'PDA-7000',
    createdAt: DateTime(2026, 8, 29, 11, 45),
  );

  final orderDirect = OrderEntity(
    id: 'ord-direct-201',
    orderNumber: 'NX-DT-201',
    customerName: 'Chidi Okafor',
    customerPhone: '08081234567',
    deliveryState: 'FCT - Abuja',
    deliveryCity: 'Garki',
    deliveryAddress: '10 Gimbiya Street, Garki',
    status: 'delivered',
    quantity: 1,
    productName: 'Apha Man Vitality Booster',
    basePrice: 50000.0,
    upsellAmount: 0.0,
    totalAmount: 50000.0,
    paymentType: 'direct_transfer',
    paymentStatus: 'paid',
    remittanceStatus: 'cleared',
    deliveryNotes: '[POD Paid via Direct Paystack / Monnify Transfer]',
    deliveryAgentId: 'rider-001',
    deliveryAgentName: 'Emeka Rider',
    deliveryAgentCode: 'PDA-7000',
    createdAt: DateTime(2026, 8, 29, 10, 15),
  );

  const testSupervisor = UserEntity(
    id: 'dc-sup-01',
    email: 'adekunle.dc@novaexpress.ng',
    phone: '08099887766',
    firstName: 'Adekunle',
    lastName: 'Supervisor',
    role: 'dc_manager',
    distributionCenterId: '22222222-2222-4222-8222-222222222222',
    distributionCenterName: 'Abuja Wuse DC Hub',
  );

  group('DC Console Remittance Batches, Lifecycles & Modal Suite', () {
    testWidgets('1. DCOrderPaymentMatchingPage correctly calculates opening timestamp, accumulated orders, and KPIs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([order1Cash, order2Cash, orderDirect])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
          ],
          child: const MaterialApp(
            home: DCOrderPaymentMatchingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Page & KPI Summary
      expect(find.text('Remittances & Reconciliation'), findsOneWidget);
      expect(find.text('TOTAL MONITORED VALUE'), findsOneWidget);
      expect(find.text('DIRECT PAYSTACK PAID'), findsOneWidget);
      expect(find.text('NOT REMITTED (HELD BY RIDERS)'), findsOneWidget);
      expect(find.text('REMITTED & RECONCILED'), findsOneWidget);

      // Total monitored: 35,000 + 55,000 + 50,000 = 140,000
      expect(find.text('₦140,000.00'), findsOneWidget);

      // Direct Paystack: 50,000
      expect(find.text('₦50,000.00'), findsWidgets);

      // 2. Verify Table View and row details
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      expect(find.text('RIDER / AGENT'), findsOneWidget);
      expect(find.text('ORDERS'), findsOneWidget);
      expect(find.text('AMOUNT TO REMIT'), findsOneWidget);
      expect(find.text('NET REMITTANCE'), findsOneWidget);
      expect(find.text('OPENING DATE'), findsOneWidget);
      expect(find.text('CLOSING DATE'), findsOneWidget);
      expect(find.text('REMITTANCE STATUS'), findsOneWidget);

      // 3. Verify Filters exist: Not Remitted & Remitted
      expect(find.textContaining('Not Remitted'), findsWidgets);
      expect(find.textContaining('Remitted & Cleared'), findsWidgets);

      // 4. Tapping row on Cash Awaiting Remittance opens DCRemittanceDetailModal
      await tester.tap(find.text('2 Orders'));
      await tester.pumpAndSettle();

      // 5. Verify DCRemittanceDetailModal contents
      expect(find.text('Cumulative Financial Settlement Breakdown'), findsOneWidget);
      expect(find.textContaining('Less: Rider Delivery Commission'), findsOneWidget);
      expect(find.textContaining('Less: Fuel & Route Transport Allowance'), findsOneWidget);
      expect(find.textContaining('Less: POS / Gateway Transfer Charge'), findsOneWidget);
      expect(find.text('Orders Contained in Batch (2)'), findsOneWidget);
      expect(find.text('Contact Rider'), findsOneWidget);
    });

    testWidgets('2. DCRemittanceDetailModal renders batch lifecycle, cumulative breakdown and allows verification', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = DCRemittanceLifecycleItem(
        id: 'batch-001',
        referenceNumber: 'REM-CASH-7000',
        riderId: 'rider-001',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        riderPhone: '08031234567',
        type: 'cash_pod',
        status: 'awaiting_remittance',
        openingDate: DateTime(2026, 8, 29, 9, 30),
        closingDate: null,
        grossAmount: 90000.0,
        commissionAmount: 2000.0,
        transportAllowance: 1500.0,
        posFee: 1800.0,
        netAmount: 84700.0,
        orders: [order1Cash, order2Cash],
        paymentMethod: 'cash_to_dc',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([order1Cash, order2Cash])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DCRemittanceDetailModal(remittance: batch),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Reference Number & Status
      expect(find.text('REM-CASH-7000'), findsOneWidget);
      expect(find.text('🟡 AWAITING REMITTANCE'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsOneWidget);
      expect(find.textContaining('Opened: 29 Aug 2026, 09:30 AM'), findsOneWidget);
      expect(find.textContaining('Closed: Active Route (Open)'), findsOneWidget);

      // Verify Cumulative Financial Breakdown
      expect(find.text('Cumulative Financial Settlement Breakdown'), findsOneWidget);
      expect(find.text('Orders Contained in Batch (2)'), findsOneWidget);
      expect(find.text('NX-ORD-101'), findsOneWidget);
      expect(find.text('NX-ORD-102'), findsOneWidget);

      // Verify Verify & Clear Button
      expect(find.textContaining('Verify & Clear'), findsOneWidget);
      await tester.tap(find.textContaining('Verify & Clear'));
      await tester.pumpAndSettle();

      // Confirm Dialog
      expect(find.text('Verify & Clear Remittance'), findsOneWidget);
      expect(find.text('Confirm & Clear'), findsOneWidget);

      await tester.tap(find.text('Confirm & Clear'));
      await tester.pumpAndSettle();
    });

    testWidgets('3. Direct Transfer remittance displays instant clearance and matching opening & closing timestamps', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final directBatch = DCRemittanceLifecycleItem(
        id: 'direct-001',
        referenceNumber: 'DT-NX-DT-201',
        riderId: 'rider-001',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        type: 'direct_transfer',
        status: 'direct_settled',
        openingDate: DateTime(2026, 8, 29, 10, 15),
        closingDate: DateTime(2026, 8, 29, 10, 15),
        grossAmount: 50000.0,
        commissionAmount: 0.0,
        transportAllowance: 0.0,
        posFee: 0.0,
        netAmount: 50000.0,
        orders: [orderDirect],
        paymentMethod: 'direct_transfer',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([orderDirect])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DCRemittanceDetailModal(remittance: directBatch),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DT-NX-DT-201'), findsOneWidget);
      expect(find.text('⚡ DIRECT SETTLED'), findsOneWidget);
      expect(find.textContaining('Instant Direct Bank Settlement'), findsOneWidget);
      expect(find.textContaining('Opened: 29 Aug 2026, 10:15 AM'), findsOneWidget);
      expect(find.textContaining('Closed: 29 Aug 2026, 10:15 AM'), findsOneWidget);
      expect(find.text('Cleared into DC Treasury'), findsOneWidget);
    });

    testWidgets('4. Tapping rider profile strip in DCRemittanceDetailModal opens DCRiderDetailModal', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final batch = DCRemittanceLifecycleItem(
        id: 'batch-001',
        referenceNumber: 'REM-CASH-7000',
        riderId: 'rider-001',
        riderName: 'Emeka Rider',
        riderCode: 'PDA-7000',
        riderPhone: '08031234567',
        riderAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        type: 'cash_pod',
        status: 'awaiting_remittance',
        openingDate: DateTime(2026, 8, 29, 9, 30),
        closingDate: null,
        grossAmount: 90000.0,
        commissionAmount: 2000.0,
        transportAllowance: 1500.0,
        posFee: 1800.0,
        netAmount: 84700.0,
        orders: [order1Cash, order2Cash],
        paymentMethod: 'cash_to_dc',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([order1Cash, order2Cash])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DCRemittanceDetailModal(remittance: batch),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify View Profile badge is present
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.text('Emeka Rider'), findsOneWidget);

      // Tap on the rider strip
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();

      // Verify DCRiderDetailModal opens with driver overview tabs and code
      expect(find.text('PDA-7000'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
    });
  });
}
