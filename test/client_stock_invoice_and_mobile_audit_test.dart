import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_invoice.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_inventory_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_stock_invoice_detail_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_edit_client_modal.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_onboard_client_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ClientStockInvoice Payment Receipt & Landed Cost Tests', () {
    test('ClientStockInvoice parses paymentReceiptUrl directly from JSON', () {
      final json = {
        'id': 'inv-101',
        'invoice_number': 'INV-2026-09-001',
        'client_id': 'cli-001',
        'supplier_id': 'sup-001',
        'supplier_name': 'Apex Botanical Labs Ltd',
        'warehouse': 'Wuse Central Hub',
        'invoice_date': '2026-09-18T10:00:00Z',
        'status': 'received',
        'total_landed_cost': 450000.0,
        'payment_receipt_url': 'https://storage.example.com/receipts/rec-101.png',
        'notes': 'Verified delivery against consignment manifest.',
        'items': [
          {
            'id': 'item-1',
            'invoice_id': 'inv-101',
            'product_name': 'Ura Clear Pro Detox',
            'product_sku': 'URA-CLR-01',
            'quantity': 100,
            'supplier_unit_price': 3500.0,
            'packaging_cost_per_unit': 400.0,
            'transportation_cost_per_unit': 450.0,
            'handling_cost_per_unit': 150.0,
            'target_retail_price': 12000.0,
          }
        ],
      };

      final invoice = ClientStockInvoice.fromJson(json);
      expect(invoice.invoiceNumber, 'INV-2026-09-001');
      expect(invoice.paymentReceiptUrl, 'https://storage.example.com/receipts/rec-101.png');
      expect(invoice.hasPaymentReceipt, true);
      expect(invoice.items.length, 1);
      expect(invoice.items.first.effectiveLandedCostPerUnit, 4500.0);
    });

    test('ClientStockInvoice parses paymentReceiptUrl from notes regex fallback', () {
      final json = {
        'id': 'inv-102',
        'invoice_number': 'INV-2026-09-002',
        'client_id': 'cli-001',
        'supplier_id': 'sup-001',
        'supplier_name': 'Apex Botanical Labs Ltd',
        'warehouse': 'Wuse Central Hub',
        'invoice_date': '2026-09-19T10:00:00Z',
        'status': 'received',
        'total_landed_cost': 225000.0,
        'notes': 'Bank transfer processed via Zenith Bank. [RECEIPT: https://cdn.storage.com/slips/slip-999.pdf]',
        'items': [],
      };

      final invoice = ClientStockInvoice.fromJson(json);
      expect(invoice.invoiceNumber, 'INV-2026-09-002');
      expect(invoice.paymentReceiptUrl, 'https://cdn.storage.com/slips/slip-999.pdf');
      expect(invoice.hasPaymentReceipt, true);
    });
  });

  group('ClientStockInvoiceDetailModal Widget Tests', () {
    testWidgets('Renders invoice detail modal with items and receipt controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final invoice = ClientStockInvoice(
        id: 'inv-test-1',
        invoiceNumber: 'INV-2026-09-042',
        clientId: 'cli-001',
        supplierId: 'sup-001',
        supplierName: 'Apex Botanical Labs Ltd',
        destinationWarehouse: 'Wuse Central Hub',
        entryDate: DateTime(2026, 9, 20),
        status: 'received',
        grandTotalLandedCost: 450000.0,
        paymentReceiptUrl: 'https://storage.example.com/rec-101.png',
        notes: 'Verified against consignment manifest',
        createdAt: DateTime(2026, 9, 20),
        items: [
          ClientStockInvoiceItem.calculate(
            id: 'item-1',
            invoiceId: 'inv-test-1',
            productName: 'Ura Clear Pro Detox',
            productSku: 'URA-CLR-01',
            quantity: 100,
            supplierUnitPrice: 3500.0,
            packagingCostPerUnit: 400.0,
            transportationCostPerUnit: 450.0,
            handlingCostPerUnit: 150.0,
            targetRetailPrice: 12000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ClientStockInvoiceDetailModal(invoice: invoice),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify invoice number in header
      expect(find.text('INV-2026-09-042'), findsOneWidget);
      expect(find.textContaining('Apex Botanical Labs Ltd'), findsWidgets);
      expect(find.textContaining('Wuse Central Hub'), findsWidgets);

      // Verify Landed Cost items
      expect(find.text('Ura Clear Pro Detox'), findsOneWidget);
      expect(find.text('URA-CLR-01'), findsOneWidget);

      // Verify payment receipt indicator
      expect(find.text('Bank Payment Proof & Supplier Receipt'), findsOneWidget);
      expect(find.text('View Document'), findsOneWidget);
    });
  });

  group('Responsive DC Modals Mobile Safety Tests', () {
    testWidgets('DCEditClientModal adapts cleanly on mobile screen width', (tester) async {
      // Set to mobile viewport: 400 x 800
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientProfile(
        id: 'cli-mobile-1',
        companyName: 'Apex Health Ltd',
        contactPerson: 'Dr. Chinedu',
        email: 'chinedu@apexhealth.ng',
        phone: '08011223344',
        address: 'Wuse 2, Abuja',
        city: 'Abuja',
        state: 'FCT - Abuja',
        tier: 'enterprise',
        hasInventoryManagement: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCEditClientModal(client: client),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify modal renders without crashing or throwing overflow exceptions
      expect(find.textContaining('Manage Merchant: Apex Health Ltd'), findsOneWidget);
      expect(find.text('Save Merchant Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DCOnboardClientModal renders step 1 cleanly on mobile screen width', (tester) async {
      // Set to mobile viewport: 380 x 800
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final oldHandler = FlutterError.onError;
      FlutterErrorDetails? caughtDetails;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DCOnboardClientModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(caughtDetails, isNull);
      expect(find.text('Onboard Client Account'), findsOneWidget);
    });
  });
}
