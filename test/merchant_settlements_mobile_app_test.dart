import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_settlements_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_settlement_sheet.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/client_portal/presentation/pages/merchant_settlements_mobile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockClient = const ClientProfile(
    id: 'client-xyz-123',
    companyName: 'Luxe Cosmetics NG',
    contactPerson: 'Finance Department',
    email: 'finance@luxeng.com',
    phone: '08012345678',
    address: 'Commercial Avenue',
    bankName: 'Access Bank',
    accountNumber: '0123456789',
    accountName: 'Luxe Cosmetics Corporate',
    customDeliveryFee: 1200.0,
  );

  final dcLagos = const DistributionCenter(
    id: 'dc-lagos-01',
    name: 'NOVA XPRESS LAGOS',
    code: 'DC-0039',
    state: 'Lagos State',
    city: 'Alimosho',
    address: 'Plot 424 G close',
  );

  final dcAbuja = const DistributionCenter(
    id: 'dc-cmd-01',
    name: 'Central Command Distribution Center',
    code: 'DC-CMD-01',
    state: 'Abuja (FCT)',
    city: 'Wuse 2',
    address: 'Plot 402 Aminu Kano Crescent',
    isGrandDc: true,
  );

  final dcBenue = const DistributionCenter(
    id: 'dc-benue-01',
    name: 'Benue Distribution Center',
    code: 'DC-BMU001',
    state: 'Benue State',
    city: 'Makurdi',
    address: 'Dentata, back of UBA Bank',
  );

  OrderEntity makeOrder({
    required String id,
    required String orderNumber,
    required String customerName,
    required String dcId,
    required String status,
    required double amount,
    required DateTime createdAt,
    String productName = 'Product Item',
  }) {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: '08012345678',
      deliveryState: 'State',
      deliveryCity: 'City',
      deliveryAddress: 'Street 1',
      status: status,
      quantity: 1,
      basePrice: amount,
      upsellAmount: 0.0,
      totalAmount: amount,
      paymentType: 'cod',
      paymentStatus: status == 'delivered' ? 'paid' : 'pending',
      distributionCenterId: dcId,
      clientId: 'client-xyz-123',
      createdAt: createdAt,
      productName: productName,
    );
  }

  group('Merchant Multi-DC Settlements Unit Tests', () {
    test('Groups live accumulating orders into separate settlements per Distribution Center', () {
      final now = DateTime.now();

      final orders = [
        // Lagos orders (2 delivered)
        makeOrder(
          id: 'ord-lag-1',
          orderNumber: 'NX-LAG-01',
          customerName: 'Amina Lagos',
          dcId: 'dc-lagos-01',
          status: 'delivered',
          amount: 25000.0,
          createdAt: now,
          productName: 'Skin Serum',
        ),
        makeOrder(
          id: 'ord-lag-2',
          orderNumber: 'NX-LAG-02',
          customerName: 'Bola Lagos',
          dcId: 'dc-lagos-01',
          status: 'delivered',
          amount: 35000.0,
          createdAt: now,
          productName: 'Face Cream',
        ),

        // Abuja orders (1 delivered, 1 failed)
        makeOrder(
          id: 'ord-abj-1',
          orderNumber: 'NX-ABJ-01',
          customerName: 'Chidi Abuja',
          dcId: 'dc-cmd-01',
          status: 'delivered',
          amount: 50000.0,
          createdAt: now,
          productName: 'Luxury Perfume',
        ),
        makeOrder(
          id: 'ord-abj-2',
          orderNumber: 'NX-ABJ-02',
          customerName: 'Danladi Abuja',
          dcId: 'dc-cmd-01',
          status: 'failed',
          amount: 18000.0,
          createdAt: now,
          productName: 'Skin Toner',
        ),

        // Benue order (1 delivered)
        makeOrder(
          id: 'ord-bnu-1',
          orderNumber: 'NX-BNU-01',
          customerName: 'Ene Benue',
          dcId: 'dc-benue-01',
          status: 'delivered',
          amount: 20000.0,
          createdAt: now,
          productName: 'Herbal Soap',
        ),
      ];

      final state = MerchantSettlementsState(
        clientProfile: mockClient,
        distributionCenters: [dcLagos, dcAbuja, dcBenue],
        orders: orders,
        selectedDateRange: 'today',
      );

      final ongoing = state.ongoingDcSettlements;

      // 1. Must produce exactly 3 separate settlements building up in parallel
      expect(ongoing.length, equals(3));

      // 2. Lagos settlement check
      final lagosSettlement = ongoing.firstWhere((s) => s.distributionCenterId == 'dc-lagos-01');
      expect(lagosSettlement.deliveredCount, equals(2));
      expect(lagosSettlement.grossRemitted, equals(60000.0));
      expect(lagosSettlement.logisticsFees, equals(2400.0)); // 2 x 1200
      expect(lagosSettlement.expectedNetPayout, equals(57600.0)); // 60000 - 2400
      expect(lagosSettlement.productsSummary, containsAll(['Skin Serum', 'Face Cream']));

      // 3. Abuja settlement check
      final abujaSettlement = ongoing.firstWhere((s) => s.distributionCenterId == 'dc-cmd-01');
      expect(abujaSettlement.deliveredCount, equals(1));
      expect(abujaSettlement.failedAttemptCount, equals(1));
      expect(abujaSettlement.failedAttemptValue, equals(18000.0));
      expect(abujaSettlement.grossRemitted, equals(50000.0));
      expect(abujaSettlement.logisticsFees, equals(1200.0));
      expect(abujaSettlement.expectedNetPayout, equals(48800.0));

      // 4. Benue settlement check
      final benueSettlement = ongoing.firstWhere((s) => s.distributionCenterId == 'dc-benue-01');
      expect(benueSettlement.deliveredCount, equals(1));
      expect(benueSettlement.grossRemitted, equals(20000.0));
      expect(benueSettlement.logisticsFees, equals(1200.0));
      expect(benueSettlement.expectedNetPayout, equals(18800.0));

      // 5. Total telemetry checks
      expect(state.totalLiveGrowingToday, equals(130000.0)); // 60k + 50k + 20k
      expect(state.totalLiveExpectedPayout, equals(125200.0)); // 57.6k + 48.8k + 18.8k
    });

    test('Separates awaiting validation and cleared history settlements accurately', () {
      final now = DateTime.now();

      final settlements = [
        // Settlement 1: Submitted by DC Accountant, awaiting validation
        ClientSettlement(
          id: 'stl-await-1',
          settlementNumber: 'SET-2026-0042',
          clientId: 'client-xyz-123',
          distributionCenterId: 'dc-lagos-01',
          periodStart: now.subtract(const Duration(days: 1)),
          periodEnd: now,
          totalOrdersCount: 5,
          grossCollections: 100000.0,
          logisticsFeesDeducted: 6000.0,
          gatewayFeesDeducted: 1500.0,
          netPayoutAmount: 92500.0,
          destinationBankName: 'Access Bank',
          destinationAccountNumber: '0123456789',
          destinationAccountName: 'Luxe Cosmetics Corporate',
          payoutReference: 'TRF-LAG-9842',
          proofOfPaymentUrl: 'https://example.com/receipt.jpg',
          status: 'remitted', // pending validation
          settledAt: now,
          createdAt: now,
        ),

        // Settlement 2: Cleared & Validated historical settlement
        ClientSettlement(
          id: 'stl-cleared-1',
          settlementNumber: 'SET-2026-0038',
          clientId: 'client-xyz-123',
          distributionCenterId: 'dc-cmd-01',
          periodStart: now.subtract(const Duration(hours: 48)),
          periodEnd: now.subtract(const Duration(hours: 24)),
          totalOrdersCount: 12,
          grossCollections: 250000.0,
          logisticsFeesDeducted: 14400.0,
          gatewayFeesDeducted: 3750.0,
          netPayoutAmount: 231850.0,
          destinationBankName: 'Access Bank',
          destinationAccountNumber: '0123456789',
          destinationAccountName: 'Luxe Cosmetics Corporate',
          payoutReference: 'TRF-ABJ-1029',
          status: 'completed', // Cleared & Validated
          settledAt: now,
          createdAt: now,
        ),
      ];

      final state = MerchantSettlementsState(
        clientProfile: mockClient,
        distributionCenters: [dcLagos, dcAbuja, dcBenue],
        settlements: settlements,
      );

      expect(state.awaitingValidationSettlements.length, equals(1));
      expect(state.awaitingValidationSettlements.first.settlementNumber, equals('SET-2026-0042'));
      expect(state.totalAwaitingValidationAmount, equals(92500.0));

      expect(state.clearedSettlementsHistory.length, equals(1));
      expect(state.clearedSettlementsHistory.first.settlementNumber, equals('SET-2026-0038'));
      expect(state.totalClearedThisMonth, equals(231850.0));
    });

    test('User entity role mapping correctly routes merchant accountant', () {
      final user = const UserEntity(
        id: 'usr-acct-1',
        email: 'accountant@luxe.ng',
        firstName: 'Folashade',
        lastName: 'Bello',
        phone: '08012345678',
        role: 'merchant_accountant',
        companyId: 'client-xyz-123',
      );

      expect(user.isMerchantAccountant, isTrue);
      expect(user.isClient, isTrue);
      expect(user.roleDescription, equals('Merchant Finance Accountant'));
      expect(user.homeConsoleRoute, equals('/merchant-settlements'));
    });
  });

  group('MerchantSettlementSheet Widget Tests', () {
    testWidgets('Renders ongoing settlement details with live accumulation badge', (tester) async {
      final now = DateTime.now();
      final ongoing = LiveOngoingSettlement(
        distributionCenterId: 'dc-lagos-01',
        dcName: 'NOVA XPRESS LAGOS',
        dcCode: 'DC-0039',
        dcState: 'Lagos State',
        stationManagerName: 'Station Head',
        stationManagerPhone: '08000000000',
        date: now,
        deliveredCount: 3,
        grossRemitted: 75000.0,
        logisticsFees: 3600.0,
        posGatewayFees: 1125.0,
        failedAttemptCount: 1,
        failedAttemptValue: 15000.0,
        expectedNetPayout: 70275.0,
        orders: [
          makeOrder(
            id: 'ord-1',
            orderNumber: 'NX-9021',
            customerName: 'Kemi Adebayo',
            dcId: 'dc-lagos-01',
            status: 'delivered',
            amount: 25000.0,
            createdAt: now,
            productName: 'Anti-Aging Elixir',
          ),
        ],
        productsSummary: ['Anti-Aging Elixir'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MerchantSettlementSheet(ongoingSettlement: ongoing),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // DC Name & Code
      expect(find.text('NOVA XPRESS LAGOS'), findsOneWidget);
      expect(find.text('DC-0039'), findsOneWidget);

      // Expected Net Payout (hero card and breakdown row)
      expect(find.text('Expected Payout'), findsOneWidget);
      expect(find.textContaining('70,275'), findsNWidgets(2));

      // Status pill: Ongoing
      expect(find.text('Ongoing'), findsOneWidget);

      // Itemized rows
      expect(find.text('Rider Collections'), findsOneWidget);
      expect(find.text('Delivery Tariff'), findsOneWidget);
      expect(find.text('POS Gateway'), findsOneWidget);
    });

    testWidgets('Renders cleared settlement with certified clearance seal tag', (tester) async {
      final now = DateTime.now();
      final settlement = ClientSettlement(
        id: 'stl-cleared-1',
        settlementNumber: 'SET-2026-0038',
        clientId: 'client-xyz-123',
        distributionCenterId: 'dc-cmd-01',
        periodStart: now.subtract(const Duration(days: 7)),
        periodEnd: now.subtract(const Duration(days: 6)),
        totalOrdersCount: 8,
        grossCollections: 160000.0,
        logisticsFeesDeducted: 9600.0,
        gatewayFeesDeducted: 2400.0,
        netPayoutAmount: 148000.0,
        destinationBankName: 'Access Bank',
        destinationAccountNumber: '0123456789',
        destinationAccountName: 'Luxe Cosmetics Corporate',
        payoutReference: 'TRF-ABJ-1029',
        status: 'completed',
        settledAt: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 6)),
      );

      await tester.pumpWidget(
        ProviderScope(
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

      // Net settlement (hero card and breakdown row)
      expect(find.text('Net Settlement'), findsOneWidget);
      expect(find.textContaining('148,000'), findsNWidgets(2));

      // Clearance status & seal
      expect(find.text('Cleared'), findsOneWidget);
      expect(find.text('CLEARED SEAL'), findsOneWidget);
      expect(find.text('Settlement Cleared'), findsOneWidget);
    });

    testWidgets('MerchantSettlementsMobilePage renders 5 bottom tabs and switches to Profile without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MerchantSettlementsMobilePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 5 bottom navigation tabs exist
      expect(find.text('Settles'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('NovaBI'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify initial tab title
      expect(find.text('Settlements'), findsWidgets);

      // Switch to Profile tab (last on right)
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Verify Profile tab content rendered without errors
      expect(find.text('Accountant Profile'), findsOneWidget);
      expect(find.text('Finance Accountant'), findsOneWidget);
      expect(find.text('Payout Destination'), findsOneWidget);
      expect(find.text('Sign Out of Console'), findsOneWidget);
    });
  });
}
