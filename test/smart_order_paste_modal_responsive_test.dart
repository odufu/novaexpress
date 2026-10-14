import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/orders/presentation/widgets/smart_order_paste_modal.dart';

void main() {
  const sampleText = '''
Order number: Novacare Ltd-CRM-ORD-10-009197
Customer name: Michael A
Customer address: 12, road A Ifedayo Avenue Iju Akure north
Country: Nigeria
State: Ondo
City: N/A
Phone number: +23480357980
Whatsapp number: 08035798687
Details of products:
 - RESPIRA LUNG TEA x1 · NGN 24,500
Total order value: NGN 24,500
Amount to collect: NGN 24,500
Additional information:
 - Whatsapp: 08035798687
Closer details:
Closer name: Maribel Nwalorzie
Closer phone: 08107418058
''';

  testWidgets('SmartOrderPasteModal does not overflow on narrow mobile screens (360x750)', (tester) async {
    // Set narrow mobile viewport
    tester.view.physicalSize = const Size(360, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool hasOverflow = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
        hasOverflow = true;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SmartOrderPasteModal(initialText: sampleText),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(hasOverflow, isFalse, reason: 'SmartOrderPasteModal should not have any RenderFlex overflow errors');
    expect(find.text('Paste from Clipboard'), findsOneWidget);
    expect(find.text('Parsed Order Summary'), findsOneWidget);
    expect(find.text('Confirm & Create Order'), findsOneWidget);
  });

  testWidgets('SmartOrderPasteModal does not overflow on standard mobile screens (390x844)', (tester) async {
    // Set standard iPhone/Android mobile viewport
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool hasOverflow = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
        hasOverflow = true;
      }
      originalOnError?.call(details);
    };

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SmartOrderPasteModal(initialText: sampleText),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(hasOverflow, isFalse, reason: 'SmartOrderPasteModal should not have any RenderFlex overflow errors on 390x844');
  });
}
