import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/core/widgets/paystack_webview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Paystack WebView Speed & Gateway Optimization Tests', () {
    testWidgets('PaystackWebViewPage renders securely with amount, title, and close button', (tester) async {
      String? successRef;

      await tester.pumpWidget(
        MaterialApp(
          home: PaystackWebViewPage(
            initialUrl: 'https://checkout.paystack.com/test-access-code',
            reference: 'PSTK-TEST-REF-9988',
            amount: 25000.0,
            title: 'Paystack Secure Checkout',
            onPaymentSuccess: (ref) {
              successRef = ref;
            },
          ),
        ),
      );

      // Verify that the title and formatted amount are immediately rendered in the AppBar
      expect(find.text('Paystack Secure Checkout'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatNaira(25000.0)), findsOneWidget);

      // Verify SSL lock icon is present
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      // Verify Close button is present
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify manual check/refresh button is present
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(successRef, isNull);
    });

    testWidgets('Tapping Close button prompts user with cancellation confirmation dialog', (tester) async {
      bool wasCancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaystackWebViewPage(
            initialUrl: 'https://checkout.paystack.com/test-access-code',
            reference: 'PSTK-TEST-REF-9988',
            amount: 15000.0,
            onCancel: () {
              wasCancelled = true;
            },
          ),
        ),
      );

      // Tap close button in AppBar
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be visible
      expect(find.text('Cancel Payment?'), findsOneWidget);
      expect(find.text('Continue Payment'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap exit
      await tester.tap(find.text('Exit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(wasCancelled, isTrue);
    });

    testWidgets('PaystackWebViewPage shows smooth loading indicator when initializing session', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaystackWebViewPage(
            reference: 'PSTK-DYNAMIC-INIT',
            amount: 8500.0,
            email: 'rider.test@novaxpress.ng',
            payerName: 'Joel Odufu',
            transactionType: 'remittance',
          ),
        ),
      );

      // Verify connecting state displays
      expect(find.text('Connecting to Paystack Secure Gateway...'), findsOneWidget);
      expect(find.text('Encrypting payment session for ${CurrencyFormatter.formatNaira(8500.0)}'), findsOneWidget);
    });
  });
}
