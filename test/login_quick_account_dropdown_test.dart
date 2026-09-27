import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/presentation/pages/login_page.dart';
import 'package:novexps/features/auth/presentation/widgets/quick_account_dropdown.dart';

void main() {
  testWidgets('LoginPage renders QuickAccountDropdown and expands/collapses cleanly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify QuickAccountDropdown is rendered
    expect(find.byType(QuickAccountDropdown), findsOneWidget);
    expect(find.text('QUICK ACCOUNT SELECTOR'), findsOneWidget);
    expect(find.text('DC Supervisor'), findsWidgets);

    // 2. Tap to expand custom dropdown
    final dropdownTrigger = find.text('QUICK ACCOUNT SELECTOR');
    await tester.tap(dropdownTrigger);
    await tester.pumpAndSettle();

    // 3. Verify expanded sections are visible
    expect(find.text('PRIMARY OPERATIONAL ROLES'), findsOneWidget);
    expect(find.text('ALTERNATE DEMO ACCOUNTS'), findsOneWidget);
    expect(find.text('Novacare Client'), findsOneWidget);
    expect(find.text('Novacare Closer'), findsOneWidget);
    expect(find.text('Field Rider (PDA)'), findsOneWidget);

    // 4. Select "Novacare Client" from custom dropdown
    await tester.tap(find.text('Novacare Client'));
    await tester.pumpAndSettle();

    // 5. Verify email field and button updated
    expect(find.text('merchant@novacare.com'), findsOneWidget);
    expect(find.text('Sign In as Novacare Client'), findsOneWidget);

    // 6. Expand dropdown again and select "Field Rider (PDA)"
    await tester.tap(dropdownTrigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field Rider (PDA)'));
    await tester.pumpAndSettle();

    // 7. Verify email field and button updated to rider
    expect(find.text('rider.emeka@novaxpress.com'), findsOneWidget);
    expect(find.text('Sign In as Field Rider (PDA)'), findsOneWidget);
  });
}
