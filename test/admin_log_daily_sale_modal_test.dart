import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/admin_console/presentation/widgets/admin_log_daily_sale_modal.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdminLogDailySaleModal displays merchant, agent, SKU dropdowns and balances custody', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Login Damilare
    await container.read(authProvider.notifier).login('damieajani@gmail.com', 'Password123!');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AdminLogDailySaleModal(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Verify modal title and subtitle
    expect(find.text('Log Daily Sales & Balance Stock'), findsOneWidget);
    expect(find.textContaining('Super Admin & Master Stock Keeper Portal'), findsOneWidget);

    // 2. Verify all dropdown sections are present
    expect(find.text('Select Merchant / Client Brand *'), findsOneWidget);
    expect(find.text('Select Delivery Agent / 3PL Partner *'), findsOneWidget);
    expect(find.text('Select Product SKU *'), findsOneWidget);

    // 3. Verify Live Custody calculation rows
    expect(find.text('Starting Agent Custody'), findsOneWidget);
    expect(find.text('+ New Replenishment from DC'), findsOneWidget);
    expect(find.text('- Delivered Daily Sales'), findsOneWidget);
    expect(find.text('- Returns / Damaged from Field'), findsOneWidget);
    expect(find.text('= Balanced Closing Custody'), findsOneWidget);

    // 4. Verify Ambush Audit Mode option
    expect(find.text('Random Ambush Stock-Taking (Audit Mode)'), findsOneWidget);

    // 5. Verify Operator attribution banner shows Damilare Ajani
    expect(find.textContaining('Operator: Damilare Ajani'), findsOneWidget);

    // 6. Verify Post Daily Sales button
    expect(find.text('Post Daily Sales & Balance Custody'), findsOneWidget);
  });
}
