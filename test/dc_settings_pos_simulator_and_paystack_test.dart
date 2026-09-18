import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';
import 'package:novexps/features/dc_console/presentation/pages/dc_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Settings POS Simulator, Paystack & Client Products Verification Suite', () {
    test('1. ClientPortalNotifier.isProductForClient correctly filters and associates products', () {
      final novacareProduct = CatalogProduct(
        id: 'prod-1',
        name: 'Novacare Gluta White Serum',
        sku: 'NOVA-GW-01',
        defaultUnitPrice: 12000.0,
        clientId: '00000000-0000-4000-8000-789382731303',
        clientName: 'Novacare Health & Wellness Ltd',
      );

      final unlinkedNovacareProduct = CatalogProduct(
        id: 'prod-2',
        name: 'Novacare Vitamin C Glow',
        sku: 'NOVA-VC-02',
        defaultUnitPrice: 8500.0,
        clientId: '',
        clientName: 'Novacare',
      );

      final otherClientProduct = CatalogProduct(
        id: 'prod-3',
        name: 'Generic Herbal Soap',
        sku: 'GEN-SOAP-01',
        defaultUnitPrice: 3000.0,
        clientId: 'other-client-id',
        clientName: 'Other Vendor Ltd',
      );

      // Match by exact clientId
      expect(
        ClientPortalNotifier.isProductForClient(
          product: novacareProduct,
          clientId: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health & Wellness Ltd',
        ),
        isTrue,
      );

      // Match unlinked product by fuzzy company name
      expect(
        ClientPortalNotifier.isProductForClient(
          product: unlinkedNovacareProduct,
          clientId: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health & Wellness Ltd',
        ),
        isTrue,
      );

      // Should NOT match foreign product
      expect(
        ClientPortalNotifier.isProductForClient(
          product: otherClientProduct,
          clientId: '00000000-0000-4000-8000-789382731303',
          companyName: 'Novacare Health & Wellness Ltd',
        ),
        isFalse,
      );
    });

    testWidgets('2. DCSettingsPage renders Live Simulator, Dynamic Formula & Paystack Cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Distribution Center Policy & Finance Settings'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('CONFIGURATION'), findsOneWidget);

      // Verify POS Strategy Card
      expect(find.text('POS Transfer Fee Strategy'), findsOneWidget);
      expect(find.text('DYNAMIC ACTIVE'), findsOneWidget);
      expect(find.text('Dynamic Tiered Scaling'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('Flat Rate Fee'), findsOneWidget);

      // Verify Live Reconciliation Simulator
      expect(find.text('LIVE FINANCIAL RECONCILIATION SIMULATOR'), findsOneWidget);
      expect(find.text('Mode: Dynamic Tiered'), findsOneWidget);
      expect(find.text('Sample Collected Cash (₦)'), findsOneWidget);
      expect(find.text('GROSS CASH'), findsOneWidget);
      expect(find.text('POS FEE'), findsOneWidget);
      expect(find.text('Reimbursed'), findsOneWidget);
      expect(find.text('RIDER ALLOWANCE'), findsOneWidget);
      expect(find.text('NET TO VAULT'), findsOneWidget);
      expect(find.text('Balanced Ledger'), findsOneWidget);

      // Verify Paystack & Direct Gateway Charges Card
      expect(find.text('Paystack & Direct Gateway Charges'), findsOneWidget);
      expect(find.text('Automated Webhook'), findsOneWidget);
      expect(find.text('Direct Paystack Fee (%)'), findsOneWidget);
      expect(find.text('Paystack Max Fee Cap (₦)'), findsOneWidget);
      expect(find.text('Automated Paystack Split Settlements'), findsOneWidget);
    });
  });
}
