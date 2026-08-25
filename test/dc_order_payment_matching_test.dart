import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_order_payment_matching_page.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final orderDirectPaystack = OrderEntity(
    id: 'ord-paystack-01',
    orderNumber: 'TRK-PSTK-9001',
    customerName: 'Amina Bello',
    customerPhone: '08031234567',
    deliveryState: 'FCT - Abuja',
    deliveryCity: 'Maitama',
    deliveryAddress: '12 Gana Street, Maitama',
    status: 'delivered',
    quantity: 1,
    basePrice: 25000.0,
    upsellAmount: 0.0,
    totalAmount: 25000.0,
    paymentType: 'prepaid',
    paymentStatus: 'paid',
    deliveryNotes: '[POD Paid via Paystack Direct Transfer • Ref: PSTK-POD-9001]',
    deliveryAgentId: 'rider-001',
    deliveryAgentName: 'Joel Odufu',
    deliveryAgentCode: 'PDA-7182',
    createdAt: DateTime.now(),
  );

  final orderCashAwaiting = OrderEntity(
    id: 'ord-cash-02',
    orderNumber: 'TRK-CASH-9002',
    customerName: 'Chidi Okafor',
    customerPhone: '08091112233',
    deliveryState: 'FCT - Abuja',
    deliveryCity: 'Wuse 2',
    deliveryAddress: '402 Aminu Kano Crescent, Wuse 2',
    status: 'delivered',
    quantity: 1,
    basePrice: 18500.0,
    upsellAmount: 0.0,
    totalAmount: 18500.0,
    paymentType: 'pay_on_delivery',
    paymentStatus: 'collected',
    deliveryNotes: '[POD Collected via Cash] Cash in custody.',
    deliveryAgentId: 'rider-001',
    deliveryAgentName: 'Joel Odufu',
    deliveryAgentCode: 'PDA-7182',
    createdAt: DateTime.now(),
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

  group('DC Console Order-Payment Matching Suite', () {
    testWidgets('DCOrderPaymentMatchingPage renders KPIs, matches orders to payments and allows rider contact', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([orderDirectPaystack, orderCashAwaiting])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            notificationsProvider.overrideWith((ref) => MockTestNotificationsNotifier()),
          ],
          child: const MaterialApp(
            home: DCOrderPaymentMatchingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Page Title & Core KPIs
      expect(find.text('Order-Payment Matching & Reconciliation'), findsOneWidget);
      expect(find.text('TOTAL MONITORED VALUE'), findsOneWidget);
      expect(find.text('DIRECT PAYSTACK PAID'), findsOneWidget);
      expect(find.text('CASH AWAITING REMITTANCE'), findsOneWidget);
      expect(find.text('REMITTED & RECONCILED'), findsOneWidget);

      // Total monitored: 25,000 + 18,500 = 43,500
      expect(find.text('₦43,500.00'), findsOneWidget);
      // Direct Paystack: 25,000 in KPI card and Order Card
      expect(find.text('₦25,000.00'), findsWidgets);
      // Cash Awaiting Net Due: 18,500 - 1,000 commission - 1,500 transport - 400 transfer fee = 15,600
      expect(find.text('₦15,600.00'), findsWidgets);

      // 2. Verify Order Rows & Payment Classifications
      expect(find.text('#TRK-PSTK-9001'), findsOneWidget);
      expect(find.text('⚡ DIRECT TRANSFER (PAYSTACK PAID)'), findsOneWidget);
      expect(find.textContaining('Funds settled directly into company Paystack treasury'), findsOneWidget);

      expect(find.text('#TRK-CASH-9002'), findsOneWidget);
      expect(find.text('⚠️ CASH POD - AWAITING REMITTANCE'), findsOneWidget);
      expect(find.textContaining('Net remittance due to DC: ₦15,600.00'), findsOneWidget);

      // 3. Verify Filter by Direct Paystack
      await tester.tap(find.textContaining('⚡ Direct Paystack'));
      await tester.pumpAndSettle();

      expect(find.text('#TRK-PSTK-9001'), findsOneWidget);
      expect(find.text('#TRK-CASH-9002'), findsNothing);

      // 4. Verify Filter by Cash Awaiting Remittance
      await tester.tap(find.textContaining('⚠️ Cash Awaiting Remittance'));
      await tester.pumpAndSettle();

      expect(find.text('#TRK-CASH-9002'), findsOneWidget);
      expect(find.text('#TRK-PSTK-9001'), findsNothing);

      // 5. Test "Contact & Remind Rider" Action Button
      expect(find.text('Contact & Remind Rider'), findsOneWidget);
      await tester.tap(find.text('Contact & Remind Rider'));
      await tester.pumpAndSettle();

      // Verify DCContactRiderModal appears
      expect(find.text('Contact Delivery Agent'), findsOneWidget);
      expect(find.text('Direct Call'), findsOneWidget);
      expect(find.text('WhatsApp Reminder'), findsOneWidget);
      expect(find.text('Send Instant In-App Remittance Alert'), findsOneWidget);
      expect(find.text('IN-APP COMMUNICATIONS CHANNEL'), findsOneWidget);

      // Test Dispatching In-App Push Alert
      await tester.tap(find.text('Send Instant In-App Remittance Alert'));
      await tester.pumpAndSettle();

      expect(find.text('In-App Notice Dispatched ✓'), findsOneWidget);
    });

    testWidgets('DCOrderPaymentMatchingPage switches between Card View and Table View smoothly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => MockTestOrdersNotifier([orderDirectPaystack, orderCashAwaiting])),
            financeProvider.overrideWith((ref) => MockTestFinanceNotifier([])),
            authProvider.overrideWith((ref) => MockTestAuthNotifier(testSupervisor)),
            notificationsProvider.overrideWith((ref) => MockTestNotificationsNotifier()),
          ],
          child: const MaterialApp(
            home: DCOrderPaymentMatchingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Table and Cards switch buttons exist
      expect(find.text('Table'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);

      // Switch to Table View
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Verify DataTable column headers
      expect(find.text('SHIPMENT / ITEM'), findsOneWidget);
      expect(find.text('CUSTOMER & LOCATION'), findsOneWidget);
      expect(find.text('PAYABLE AMOUNT'), findsOneWidget);
      expect(find.text('PAYMENT METHOD'), findsOneWidget);
      expect(find.text('RECONCILIATION / NET REMITTANCE'), findsOneWidget);
      expect(find.text('ASSIGNED RIDER'), findsOneWidget);
      expect(find.text('ACTION'), findsOneWidget);

      // Verify Table Rows
      expect(find.text('Direct (Paystack)'), findsOneWidget);
      expect(find.text('Cash POD'), findsOneWidget);
      expect(find.text('Settled (₦0 Cash Held)'), findsOneWidget);
      expect(find.textContaining('Net Due: ₦15,600.00'), findsOneWidget);

      // Switch back to Cards View
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();

      expect(find.text('SHIPMENT / ITEM'), findsNothing);
      expect(find.text('⚡ DIRECT TRANSFER (PAYSTACK PAID)'), findsOneWidget);
    });
  });
}

class MockTestOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  MockTestOrdersNotifier(List<OrderEntity> orders) : super(OrdersState(orders: orders));

  @override
  Future<void> loadDcOrders([String? dcId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestFinanceNotifier extends StateNotifier<FinanceState> implements FinanceNotifier {
  MockTestFinanceNotifier(List<RemittanceEntity> remittances)
      : super(FinanceState(remittances: remittances));

  @override
  Future<void> loadRemittances([String? agentId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestNotificationsNotifier extends StateNotifier<NotificationsState> implements NotificationsNotifier {
  MockTestNotificationsNotifier() : super(NotificationsState());

  @override
  Future<void> emitNotification({
    required String title,
    required String message,
    String category = 'general',
    String? actionRoute,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockTestAuthNotifier(UserEntity user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
