import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/presentation/pages/merchant_bi_chat_page.dart';
import 'package:novexps/features/client_portal/presentation/pages/merchant_settlements_mobile_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/merchant_settlements_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/merchant_settlement_sheet.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OrderEntity makeLongOrder({
    required String id,
    required String orderNumber,
    required String customerName,
    required double amount,
  }) {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: '08012345678',
      deliveryState: 'Abuja (FCT)',
      deliveryCity: 'Wuse II',
      deliveryAddress: 'Plot 402 Aminu Kano',
      status: 'delivered',
      quantity: 1,
      basePrice: amount,
      upsellAmount: 0.0,
      totalAmount: amount,
      paymentType: 'cod',
      paymentStatus: 'paid',
      distributionCenterId: 'dc-cmd-01',
      clientId: 'client_nova_01',
      createdAt: DateTime.now(),
      productName: 'Grazer Herbal Detox Tea',
    );
  }

  final mockOngoing = LiveOngoingSettlement(
    distributionCenterId: 'dc-cmd-01',
    dcName: 'Central Command Distribution Center',
    dcCode: 'DC-CMD-01',
    dcState: 'Abuja (FCT)',
    stationManagerName: 'Ahmed Bello',
    stationManagerPhone: '08011112222',
    date: DateTime.now(),
    deliveredCount: 6,
    grossRemitted: 136500.0,
    logisticsFees: 9000.0,
    posGatewayFees: 1200.0,
    failedAttemptCount: 0,
    failedAttemptValue: 0.0,
    otherFees: 0.0,
    otherFeesComment: '',
    expectedNetPayout: 126300.0,
    productsSummary: ['Grazer Herbal Detox Tea', 'URA Clear'],
    orders: [
      makeLongOrder(
        id: 'ord_1',
        orderNumber: 'Novacare Ltd-CRM-ORD-10-042893817382-EX-LONG-NUMBER-1',
        customerName: 'Bena Brambaifa with a very long customer name that spans across',
        amount: 23500.0,
      ),
      makeLongOrder(
        id: 'ord_2',
        orderNumber: 'Novacare Ltd-CRM-ORD-10-042893817382-EX-LONG-NUMBER-2',
        customerName: 'Japet Habila from Abuja Central District',
        amount: 23500.0,
      ),
    ],
  );

  group('Merchant UI Overflows & Profile Edit Verification', () {
    testWidgets('1. MerchantSettlementSheet renders long CRM order rows without RenderFlex overflow on 360px mobile screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MerchantSettlementSheet(
                ongoingSettlement: mockOngoing,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Manifest tab where the orders are rendered
      final manifestTabFinder = find.text('Manifest');
      expect(manifestTabFinder, findsOneWidget);
      await tester.tap(manifestTabFinder);
      await tester.pumpAndSettle();

      // Verify orders are visible and no overflow occurred
      expect(find.textContaining('Fulfilled Orders (2)'), findsOneWidget);
      expect(find.textContaining('Grazer Herbal Detox Tea • CASH'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. MerchantBiChatPage renders compact header without overflow on 360px screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MerchantBiChatPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify NovaBI Copilot and AI INTEL badge exist without overflow
      expect(find.text('NovaBI Copilot'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. MerchantSettlementsMobilePage Profile tab renders DP avatar and Edit Profile button',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MerchantSettlementsMobilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Profile Tab (index 4)
      final profileTab = find.text('Profile');
      expect(profileTab, findsOneWidget);
      await tester.tap(profileTab);
      await tester.pumpAndSettle();

      // Verify Accountant profile header is displayed
      expect(find.text('Finance Accountant'), findsOneWidget);

      // Verify Edit button exists in identity card
      final editBtn = find.text('Edit');
      expect(editBtn, findsOneWidget);

      // Verify Edit Profile & DP tile exists in settings list
      expect(find.text('Edit Profile & DP'), findsOneWidget);

      // Verify no overflow occurred
      expect(tester.takeException(), isNull);
    });
  });
}
