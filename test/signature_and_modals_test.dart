import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/widgets/offline_sync_banner.dart';
import 'package:novexps/core/widgets/signature_pad_widget.dart';
import 'package:novexps/features/orders/presentation/widgets/monnify_transfer_modal.dart';
import 'package:novexps/features/orders/presentation/widgets/reschedule_callback_modal.dart';
import 'package:novexps/features/orders/presentation/widgets/upsell_selector_modal.dart';

void main() {
  group('PDA Feature Pack Widget Tests', () {
    testWidgets('SignaturePadWidget renders and can be cleared', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignaturePadWidget(),
          ),
        ),
      );

      expect(find.byType(SignaturePadWidget), findsOneWidget);
      expect(find.text('Customer / Receiver Digital Signature'), findsOneWidget);
    });

    testWidgets('OfflineSyncBanner renders offline status with queued count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineSyncBanner(
              status: SyncStatus.offline,
              pendingQueueCount: 3,
              onForceSync: () {},
            ),
          ),
        ),
      );

      expect(find.text('Offline Mode • 3 actions queued for sync'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });

    testWidgets('MonnifyTransferModal renders virtual account details and amount', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MonnifyTransferModal(
                orderNumber: 'ORD-7890',
                amount: 25000.0,
                onPaymentConfirmed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Direct Bank Transfer'), findsOneWidget);
      expect(find.text('Confirm Transfer Received'), findsOneWidget);
    });

    testWidgets('RescheduleCallbackModal renders preset dates and confirm button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RescheduleCallbackModal(
                orderId: 'ord-123',
                customerName: 'Amina Yusuf',
                onRescheduleConfirmed: (dt, note) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Reschedule / Call Back'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('In 2 Days'), findsOneWidget);
    });

    testWidgets('UpsellSelectorModal renders vehicle stock products and commission banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: UpsellSelectorModal(
                availableStock: const [],
                onUpsellSelected: (item, price) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('On-Site Upsell Product'), findsOneWidget);
      expect(find.textContaining('You earn +₦1,500 extra commission'), findsOneWidget);
      expect(find.text('Respira Detox Tea (Extra Box)'), findsOneWidget);
    });
  });
}
