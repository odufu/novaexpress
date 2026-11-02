import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_settlements_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_settlement_sheet.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockClient = ClientProfile(
    id: 'client-novacare-001',
    companyName: 'Novacare Limited',
    contactPerson: 'Finance Department',
    email: 'finance@novacare.ng',
    phone: '08138449455',
    address: 'Commercial Avenue',
    bankName: 'Access Bank',
    accountNumber: '8085040146',
    accountName: 'Novacare Limited',
    customDeliveryFee: 5000.0,
  );

  const dcAbuja = DistributionCenter(
    id: 'dc-cmd-01',
    name: 'Central Command Distribution Center',
    code: 'DC-CMD-01',
    state: 'Abuja (FCT)',
    city: 'Wuse 2',
    address: 'Plot 402 Aminu Kano Crescent',
    isGrandDc: true,
  );

  OrderEntity makeOrder({
    required String id,
    required String orderNumber,
    required String customerName,
    required String productName,
    required double totalAmount,
    String status = 'delivered',
    String financialSettlementStatus = 'pending_remittance',
    String? remittanceReference,
  }) {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: '08000000000',
      deliveryAddress: 'Abuja, Nigeria',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Wuse 2',
      productName: productName,
      quantity: 1,
      basePrice: totalAmount,
      upsellAmount: 0.0,
      totalAmount: totalAmount,
      clientDeliveryFee: 5000.0,
      agentEntitlement: 1500.0,
      status: status,
      paymentStatus: 'paid',
      paymentType: 'CASH',
      financialSettlementStatus: financialSettlementStatus,
      remittanceReference: remittanceReference,
      clientId: mockClient.id,
      distributionCenterId: dcAbuja.id,
      createdAt: DateTime.now(),
    );
  }

  group('Merchant Settlement Reconciliation & Validation Workflow', () {
    test('1. Orders reconciled/submitted by DC are removed from Ongoing and placed into Validation', () {
      final orders = [
        makeOrder(
          id: 'ord-1',
          orderNumber: 'NOV-2026-5568',
          customerName: 'Kingsley Odoh',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 47000.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-2',
          orderNumber: 'NOV-2026-5569',
          customerName: 'Bena Brambaifa',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 23500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-3',
          orderNumber: 'NOV-2026-5570',
          customerName: 'Japet Habila',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 23500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-4',
          orderNumber: 'NOV-2026-5571',
          customerName: 'Jibrin Muhammed',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 23500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-5',
          orderNumber: 'NOV-2026-5572',
          customerName: 'Samuel Jorgbihi',
          productName: 'URA Clear',
          totalAmount: 24500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-6',
          orderNumber: 'NOV-2026-5573',
          customerName: 'Michael A',
          productName: 'URA Clear',
          totalAmount: 24500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-7',
          orderNumber: 'NOV-2026-5574',
          customerName: 'Amina Bello',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 23500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-8',
          orderNumber: 'NOV-2026-5575',
          customerName: 'Chinedu Eze',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 46500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
      ];

      final settlement = ClientSettlement(
        id: 'settle-3845-uuid',
        settlementNumber: 'SETTLE-NOV-2026-3845',
        clientId: mockClient.id,
        distributionCenterId: dcAbuja.id,
        periodStart: DateTime.now().subtract(const Duration(days: 7)),
        periodEnd: DateTime.now(),
        totalOrdersCount: 8,
        grossCollections: 236500.0,
        logisticsFeesDeducted: 40000.0,
        platformFeesDeducted: 4000.0,
        netPayoutAmount: 192500.0,
        chargesBreakdown: {
          'order_ids': orders.map((o) => o.id).toList(),
          'delivery_fees': 40000.0,
          'platform_fees': 4000.0,
        },
        destinationBankName: 'Access Bank',
        destinationAccountNumber: '8085040146',
        destinationAccountName: 'Novacare Limited',
        status: 'pending_merchant_confirmation',
        settledAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final state = MerchantSettlementsState(
        clientProfile: mockClient,
        distributionCenters: [dcAbuja],
        settlements: [settlement],
        orders: orders,
        selectedTab: 'ongoing',
        isLoading: false,
      );

      // Verify Ongoing has 0 items (since all orders have been submitted for settlement)
      expect(state.ongoingDcSettlements, isEmpty);
      expect(state.totalLiveGrowingToday, 0.0);
      expect(state.totalLiveExpectedPayout, 0.0);

      // Verify Validation has 1 item
      expect(state.awaitingValidationSettlements.length, 1);
      expect(state.awaitingValidationSettlements.first.settlementNumber, 'SETTLE-NOV-2026-3845');
      expect(state.totalAwaitingValidationAmount, 192500.0);
    });

    testWidgets('2. Manifest tab for a ClientSettlement displays all fulfilled orders and product highlights',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final orders = [
        makeOrder(
          id: 'ord-1',
          orderNumber: 'NOV-2026-5568',
          customerName: 'Kingsley Odoh',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 47000.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-2',
          orderNumber: 'NOV-2026-5569',
          customerName: 'Bena Brambaifa',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 23500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
        makeOrder(
          id: 'ord-5',
          orderNumber: 'NOV-2026-5572',
          customerName: 'Samuel Jorgbihi',
          productName: 'URA Clear',
          totalAmount: 24500.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
      ];

      final settlement = ClientSettlement(
        id: 'settle-3845-uuid',
        settlementNumber: 'SETTLE-NOV-2026-3845',
        clientId: mockClient.id,
        distributionCenterId: dcAbuja.id,
        periodStart: DateTime.now().subtract(const Duration(days: 7)),
        periodEnd: DateTime.now(),
        totalOrdersCount: 3,
        grossCollections: 95000.0,
        logisticsFeesDeducted: 15000.0,
        platformFeesDeducted: 1500.0,
        netPayoutAmount: 78500.0,
        chargesBreakdown: {
          'order_ids': orders.map((o) => o.id).toList(),
        },
        destinationBankName: 'Access Bank',
        destinationAccountNumber: '8085040146',
        destinationAccountName: 'Novacare Limited',
        status: 'pending_merchant_confirmation',
        settledAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          merchantSettlementsProvider.overrideWith(
            (ref) => _MockSettlementsNotifier(
              MerchantSettlementsState(
                clientProfile: mockClient,
                distributionCenters: [dcAbuja],
                settlements: [settlement],
                orders: orders,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MerchantSettlementSheet(
                settlement: settlement,
                dc: dcAbuja,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Net Settlement card
      expect(find.text('Net Settlement'), findsOneWidget);
      expect(find.text('₦78,500.00'), findsAtLeastNWidgets(1));

      // Tap on Manifest tab
      final manifestTabFinder = find.widgetWithText(InkWell, 'Manifest');
      expect(manifestTabFinder, findsOneWidget);
      await tester.tap(manifestTabFinder);
      await tester.pumpAndSettle();

      // Verify fulfilled orders count and items appear (NOT 0)
      expect(find.text('Fulfilled Orders (3)'), findsOneWidget);
      expect(find.text('NOV-2026-5568'), findsOneWidget);
      expect(find.text('• Kingsley Odoh'), findsOneWidget);
      expect(find.text('NOV-2026-5569'), findsOneWidget);
      expect(find.text('• Bena Brambaifa'), findsOneWidget);
      expect(find.text('NOV-2026-5572'), findsOneWidget);
      expect(find.text('• Samuel Jorgbihi'), findsOneWidget);

      // Verify products highlight
      expect(find.text('Products Highlight'), findsOneWidget);
      expect(find.text('Grazer Herbal Detox Tea'), findsOneWidget);
      expect(find.text('URA Clear'), findsOneWidget);
    });

    test('3. After validating settlement in Validation tab, it clears from Validation, moves to History, and Ongoing stays 0', () async {
      final orders = [
        makeOrder(
          id: 'ord-1',
          orderNumber: 'NOV-2026-5568',
          customerName: 'Kingsley Odoh',
          productName: 'Grazer Herbal Detox Tea',
          totalAmount: 47000.0,
          financialSettlementStatus: 'reconciled',
          remittanceReference: 'SETTLE-NOV-2026-3845',
        ),
      ];

      final settlement = ClientSettlement(
        id: 'settle-3845-uuid',
        settlementNumber: 'SETTLE-NOV-2026-3845',
        clientId: mockClient.id,
        distributionCenterId: dcAbuja.id,
        periodStart: DateTime.now().subtract(const Duration(days: 7)),
        periodEnd: DateTime.now(),
        totalOrdersCount: 1,
        grossCollections: 47000.0,
        logisticsFeesDeducted: 5000.0,
        platformFeesDeducted: 500.0,
        netPayoutAmount: 41500.0,
        chargesBreakdown: {
          'order_ids': ['ord-1'],
        },
        destinationBankName: 'Access Bank',
        destinationAccountNumber: '8085040146',
        destinationAccountName: 'Novacare Limited',
        status: 'pending_merchant_confirmation',
        settledAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => _MockAuthNotifier(
              UserModel(
                id: 'user-acc-001',
                email: 'preciouse.accountant@gmail.com',
                firstName: 'Preciouse',
                lastName: 'Accountant',
                phone: '08138449455',
                role: 'merchant_accountant',
                companyId: mockClient.id,
                clientId: mockClient.id,
              ),
            ),
          ),
        ],
      );

      final notifier = container.read(merchantSettlementsProvider.notifier);
      notifier.setMockState(
        MerchantSettlementsState(
          clientProfile: mockClient,
          distributionCenters: [dcAbuja],
          settlements: [settlement],
          orders: orders,
        ),
      );

      // Initial check: Ongoing is 0, Validation has 1, History has 0
      var state = container.read(merchantSettlementsProvider);
      expect(state.ongoingDcSettlements, isEmpty);
      expect(state.awaitingValidationSettlements.length, 1);
      expect(state.clearedSettlementsHistory, isEmpty);

      // Validate the settlement
      final success = await notifier.validateAndClearSettlement(settlement.id, remarks: 'Verified by Merchant Accounting');
      expect(success, isTrue);

      // After validation:
      // Validation is 0
      state = container.read(merchantSettlementsProvider);
      expect(state.awaitingValidationSettlements, isEmpty);

      // History has 1 (cleared)
      expect(state.clearedSettlementsHistory.length, 1);
      expect(state.clearedSettlementsHistory.first.status, 'completed');

      // Ongoing REMAINS 0 (no recurrence or lingering orders)
      expect(state.ongoingDcSettlements, isEmpty);
      expect(state.totalLiveGrowingToday, 0.0);
      expect(state.totalLiveExpectedPayout, 0.0);

      // Orders are marked as client_settled
      final updatedOrder = state.orders.firstWhere((o) => o.id == 'ord-1');
      expect(updatedOrder.isClientSettled, isTrue);
      expect(updatedOrder.financialSettlementStatus, 'client_settled');
    });
  });
}

class _MockSettlementsNotifier extends StateNotifier<MerchantSettlementsState>
    implements MerchantSettlementsNotifier {
  _MockSettlementsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(UserModel user) : super(AuthState(user: user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
