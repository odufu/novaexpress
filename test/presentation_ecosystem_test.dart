import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/presentation/config/features.dart';
import 'package:novexps/presentation/presentation_root.dart';
import 'package:novexps/presentation/screens/ecosystem_screen.dart';
import 'package:novexps/presentation/screens/feature_presentation_screen.dart';
import 'package:novexps/presentation/widgets/central_core.dart';
import 'package:novexps/presentation/widgets/feature_platform.dart';
import 'package:novexps/presentation/widgets/feature_tooltip.dart';
import 'package:novexps/presentation/widgets/interactive_flowchart.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('NovaXpress 3D Presentation Ecosystem Tests', () {
    testWidgets('1. Renders CentralCore, top menu pills, and all 6 feature platforms in spatial balance', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PresentationRoot(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Central Core is present
      expect(find.byType(CentralCore), findsOneWidget);

      // 2. Verify all 6 Feature Platforms are rendered
      expect(find.byType(FeaturePlatform), findsNWidgets(6));
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Scaling'), findsWidgets);
      expect(find.text('Structure'), findsWidgets);
      expect(find.text('Payments'), findsWidgets);
      expect(find.text('Remitance'), findsWidgets);
      expect(find.text('Stock & Custodies'), findsWidgets);

      // 3. Verify Top HUD and status
      expect(find.text('Interactive System Presentation'), findsOneWidget);
      expect(find.text('COMMAND ECOSYSTEM ACTIVE'), findsOneWidget);
    });

    testWidgets('2. Hover triggers glassmorphic HUD tooltip card with category and benefits', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PresentationRoot(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate mouse hover over Orders platform
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final ordersPlatform = find.byKey(const ValueKey('orders'));
      expect(ordersPlatform, findsOneWidget);

      await gesture.moveTo(tester.getCenter(ordersPlatform));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tooltip HUD should appear
      expect(find.byType(FeatureTooltip), findsOneWidget);
      expect(find.text(PresentationFeatures.orders.category), findsOneWidget);
      expect(find.text('99.4%'), findsOneWidget);
    });

    testWidgets('3. Clicking a feature transitions into FeaturePresentationScreen and handles keyboard navigation', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PresentationRoot(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Orders platform
      final ordersPlatform = find.byKey(const ValueKey('orders'));
      await tester.tap(ordersPlatform, warnIfMissed: false);
      await tester.pump();

      // Pump through the 950ms cinematic selection transition + 400ms switcher
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 450));

      // Feature presentation screen should now be active
      expect(find.byType(FeaturePresentationScreen), findsOneWidget);
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Ecosystem (Esc)'), findsOneWidget);

      // Test Keyboard Navigation: ArrowRight cycles to Scaling
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Scaling'), findsWidgets);

      // Test Keyboard Navigation: Escape returns to Ecosystem
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Should be back on the ecosystem screen
      expect(find.byType(EcosystemScreen), findsOneWidget);
      expect(find.byType(FeaturePresentationScreen), findsNothing);
    });

    testWidgets('4. Verifies 7 operational subtabs, flowchart rendering, two branches in Orders, and Mermaid toggle', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PresentationRoot(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Orders platform
      final ordersPlatform = find.byKey(const ValueKey('orders'));
      await tester.tap(ordersPlatform, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 450));

      // 1. Verify vertical carousel flow cards are displayed
      expect(find.text('INTRO'), findsOneWidget);
      expect(find.text('FLOW 1'), findsOneWidget);
      expect(find.text('FLOW 2'), findsOneWidget);
      expect(find.text('FLOW 3'), findsOneWidget);
      expect(find.text('FLOW 4'), findsOneWidget);
      expect(find.text('FLOW 5'), findsOneWidget);
      expect(find.text('FLOW 6'), findsOneWidget);
      expect(find.text('FLOW 7'), findsOneWidget);
      expect(find.text('Creating Riders'), findsWidgets);
      expect(find.text('Creating Products'), findsWidgets);
      expect(find.text('Stock & Custodies'), findsWidgets);

      // 2. Verify Interactive Flowchart widget is mounted
      expect(find.byType(InteractiveFlowchart), findsOneWidget);
      expect(find.text('OPERATIONAL FLOWCHART'), findsOneWidget);

      // 3. For Orders domain: tap Step 5 in quick stepper to jump directly to Decision Step
      await tester.tap(find.text('Step 5').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TWO SUCCESSFUL OUTCOME BRANCHES:'), findsWidgets);
      expect(find.text('Branch A: Cash on Delivery (COD)'), findsWidgets);
      expect(find.text('Branch B: Direct Payment (Monnify / Paystack)'), findsWidgets);

      // 4. Verify Branch A details in inspector
      expect(find.text('Accumulates to Remittance Vault'), findsWidgets);

      // 5. Switch to Stock & Custodies via the carousel FLOW 4 card
      final stockTab = find.text('FLOW 4');
      await tester.tap(stockTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Stock Movements & Custodies'), findsWidgets);
      expect(find.text('Bulk Warehouse Inward & Bin Slotting'), findsWidgets);
      expect(find.text('Saddlebag Handover with Security PIN'), findsWidgets);

      // 6. Test Mermaid Code Toggle
      final mermaidButton = find.text('Mermaid Code');
      expect(mermaidButton, findsOneWidget);
      await tester.tap(mermaidButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show Copy Mermaid button and Mermaid code text
      expect(find.text('Copy Mermaid'), findsOneWidget);
      expect(find.textContaining('graph TD'), findsWidgets);
    });

    testWidgets('5. Toggles Light Mode and Dark Mode via UI button and keyboard shortcut T', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PresentationRoot(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Initial mode is Light Mode (as preferred for projector legibility)
      expect(find.byTooltip('Switch to Dark Mode (T)'), findsOneWidget);

      // 2. Press 'T' key to switch to Dark Mode
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Tooltip should now invite switching to Light Mode
      expect(find.byTooltip('Switch to Light Mode (T)'), findsOneWidget);

      // 3. Press 'T' key again to return to Light Mode
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byTooltip('Switch to Dark Mode (T)'), findsOneWidget);

      // 4. Navigate into Feature Presentation Screen in Light Mode
      final ordersPlatform = find.byKey(const ValueKey('orders'));
      await tester.tap(ordersPlatform, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.byType(FeaturePresentationScreen), findsOneWidget);
      // In FeaturePresentationScreen, theme toggle button also shows Dark Mode tooltip
      final featureNavToggle = find.descendant(
        of: find.byType(FeaturePresentationScreen),
        matching: find.byTooltip('Switch to Dark Mode (T)'),
      );
      expect(featureNavToggle, findsOneWidget);

      // 5. Click the theme button in FeaturePresentationScreen to toggle to Dark Mode
      await tester.tap(featureNavToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        find.descendant(
          of: find.byType(FeaturePresentationScreen),
          matching: find.byTooltip('Switch to Light Mode (T)'),
        ),
        findsOneWidget,
      );

      // 6. Press 'T' again to return to Light Mode and press Escape to return to Ecosystem
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byTooltip('Switch to Dark Mode (T)'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Still in Light Mode when returning to EcosystemScreen!
      expect(find.byType(EcosystemScreen), findsOneWidget);
      expect(find.byTooltip('Switch to Dark Mode (T)'), findsOneWidget);
    });
  });
}
