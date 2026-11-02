import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('LoginPage renders quick dev account selector cleanly', (WidgetTester tester) async {
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

    // Verify Quick Account Selector header is rendered
    expect(find.text('DEV / TEST ACCOUNT AUTO-FILL'), findsOneWidget);
  });
}
