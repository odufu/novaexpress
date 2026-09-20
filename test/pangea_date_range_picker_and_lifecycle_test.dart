import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';

void main() {
  group('Pangea Inventory Lifecycle & Ledger Entities', () {
    test('ClientStockBalance correctly calculates available units and valuation', () {
      final balance = ClientStockBalance(
        id: 'bal-001',
        clientId: 'novacare-client',
        itemCode: 'GHT-01',
        itemName: 'Grazer Herbal Tea',
        itemGroup: 'Novacare',
        warehouse: 'Stores - NL',
        balanceQty: 100.0,
        balanceValue: 450000.0,
        openingQty: 80.0,
        openingValue: 360000.0,
        inQty: 50.0,
        inValue: 225000.0,
        outQty: 30.0,
        outValue: 135000.0,
        valuationRate: 4500.0,
        reservedStock: 15.0,
        lowStockThreshold: 20,
        updatedAt: DateTime(2026, 9, 19),
      );

      expect(balance.balanceQty, 100.0);
      expect(balance.reservedStock, 15.0);
      expect(balance.availableToSell, 85.0);
      expect(balance.status, 'Healthy');
      expect(balance.openingQty + balance.inQty - balance.outQty, 100.0);
    });

    test('ClientStockBalance flags Low Stock and Out of Stock accurately', () {
      final lowStock = ClientStockBalance(
        id: 'bal-002',
        clientId: 'novacare-client',
        itemCode: 'GHT-01',
        itemName: 'Grazer Herbal Tea',
        warehouse: 'Stores - NL',
        balanceQty: 12.0,
        balanceValue: 54000.0,
        valuationRate: 4500.0,
        lowStockThreshold: 20,
        updatedAt: DateTime(2026, 9, 19),
      );
      expect(lowStock.status, 'Low Stock');

      final outOfStock = lowStock.copyWith(balanceQty: 0.0);
      expect(outOfStock.status, 'Out of Stock');
      expect(outOfStock.availableToSell, 0.0);
    });

    test('ProductPackage preserves paid vs promotional free quantities', () {
      final promoPackage = ProductPackage(
        id: 'pkg-buy2get1',
        productId: 'prod-grazer',
        productName: 'Grazer Herbal Tea',
        packageName: 'Buy 2 Get 1 Free Promo Deal',
        quantity: 3, // Total physical units to deduct from inventory
        paidQuantity: 2,
        freeQuantity: 1,
        packagePrice: 44000.0,
        clientName: 'Novacare Ltd',
        createdAt: DateTime(2026, 9, 1),
      );

      expect(promoPackage.quantity, 3);
      expect(promoPackage.paidQuantity, 2);
      expect(promoPackage.freeQuantity, 1);
      expect(promoPackage.paidQuantity + promoPackage.freeQuantity, promoPackage.quantity);
      expect(promoPackage.unitPrice, closeTo(14666.66, 0.1));
    });
  });

  group('Pangea Date Range Picker Modal Widget', () {
    testWidgets('Renders dual calendars, presets sidebar, and Lagos Time indicator', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final startDate = DateTime(2026, 9, 7);
      final endDate = DateTime(2026, 9, 13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PangeaDateRangePickerModal.show(
                    context,
                    initialStartDate: startDate,
                    initialEndDate: endDate,
                    initialPreset: DateRangePreset.last7Days,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      // Tap button to launch modal
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify modal elements from the screenshots
      expect(find.text('Recently used'), findsOneWidget);
      expect(find.text('Today and yesterday'), findsOneWidget);
      expect(find.text('Last 7 days'), findsWidgets);
      expect(find.text('This month'), findsWidgets);
      expect(find.text('Compare'), findsOneWidget);
      expect(find.text('Dates are shown in Lagos Time'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      // Verify Start and End date formatted text boxes
      final startFormatted = DateFormat('d MMMM yyyy').format(startDate);
      final endFormatted = DateFormat('d MMMM yyyy').format(endDate);
      expect(find.text(startFormatted), findsOneWidget);
      expect(find.text(endFormatted), findsOneWidget);

      // Tap 'Cancel' to close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Dates are shown in Lagos Time'), findsNothing);
    });
  });
}
