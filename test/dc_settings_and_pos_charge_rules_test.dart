import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_finance_settings.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_settings_page.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Settings & POS Charge Rules Suite', () {
    test('1. DCFinanceSettings correctly calculates Dynamic Tiered vs Flat POS fees', () {
      // 1. Dynamic Tiered: ₦100 per ₦5,000 (cap 1500)
      const dynamicSettings = DCFinanceSettings(
        posChargeMode: 'dynamic',
        posTierAmount: 5000.0,
        posTierFee: 100.0,
        posMaxCapFee: 1500.0,
      );

      expect(dynamicSettings.computePosFee(5000.0), 100.0);
      expect(dynamicSettings.computePosFee(35000.0), 700.0); // 7 * 100
      expect(dynamicSettings.computePosFee(120000.0), 1500.0); // Capped at 1500

      // 2. Flat Rate: ₦350 Flat
      const flatSettings = DCFinanceSettings(
        posChargeMode: 'flat',
        posFlatRate: 350.0,
      );

      expect(flatSettings.computePosFee(5000.0), 350.0);
      expect(flatSettings.computePosFee(35000.0), 350.0);
      expect(flatSettings.computePosFee(120000.0), 350.0);
    });

    testWidgets('2. DCSettingsPage renders with tabs, inputs, and updates charge strategy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: Scaffold(
              body: DCSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header and Tabs
      expect(find.text('Distribution Center Policy & Finance Settings'), findsOneWidget);
      expect(find.text('Finance & POS Rules'), findsOneWidget);
      expect(find.text('Rider Entitlements'), findsOneWidget);
      expect(find.text('Settlement Accounts'), findsOneWidget);
      expect(find.text('Automation & Webhooks'), findsOneWidget);

      // Verify Dynamic Tiered vs Flat Cards
      expect(find.text('Dynamic Tiered Scaling'), findsOneWidget);
      expect(find.text('Flat Rate Fee'), findsOneWidget);
      expect(find.text('Live Financial Reconciliation Simulator'), findsOneWidget);

      // Switch to Flat Rate Fee
      await tester.tap(find.text('Flat Rate Fee'));
      await tester.pumpAndSettle();

      expect(find.text('FLAT RATE ACTIVE'), findsOneWidget);
      expect(find.text('Fixed Flat POS Transfer Fee (₦)'), findsOneWidget);

      // Tap Apply & Save Rules
      await tester.tap(find.text('Apply & Save Rules'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Finance & POS Remittance Rules successfully saved'), findsOneWidget);
    });

    testWidgets('3. DCConsoleProvider propagates settings changes to state and reconciliations', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial defaults
      final initialSettings = container.read(dcConsoleProvider).financeSettings;
      expect(initialSettings.posChargeMode, 'dynamic');
      expect(initialSettings.computePosFee(50000.0), 1000.0); // 10 * 100

      // Update to Flat Rate ₦350
      container.read(dcConsoleProvider.notifier).updateFinanceSettings(
        initialSettings.copyWith(
          posChargeMode: 'flat',
          posFlatRate: 350.0,
        ),
      );

      final updatedSettings = container.read(dcConsoleProvider).financeSettings;
      expect(updatedSettings.posChargeMode, 'flat');
      expect(updatedSettings.posFlatRate, 350.0);
      expect(updatedSettings.computePosFee(50000.0), 350.0);
      expect(updatedSettings.computePosFee(500000.0), 350.0);
    });
  });
}
