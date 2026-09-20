import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/domain/entities/client_unit_economics.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_operational_cost_breakdown_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Unit Economics & Dynamic Operational Cost Calculation Tests', () {
    test('ClientUnitEconomics.calculate computes correct package value sold and dynamic operational charges', () {
      final eco = ClientUnitEconomics.calculate(
        productName: 'Novacare Cleanse Pro',
        productSku: 'NCP-01',
        baseSupplierPrice: 3200.0,
        packagingAddon: 250.0,
        transportationAddon: 400.0,
        handlingAddon: 150.0,
        catalogRetailPrice: 15000.0,
        totalUnitsOnHand: 100.0,
        quantitySold: 12,
        valueSold: 98000.0,
        deliveredOrdersCount: 4,
        failedOrdersCount: 2,
        totalOrdersCount: 6,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
        platformFeeType: 'flat',
      );

      expect(eco.totalLandedCost, 4000.0);
      expect(eco.cogsDispatched, 48000.0);
      expect(eco.totalDeliveryFees, 20000.0);
      expect(eco.totalFailedFees, 1000.0);
      expect(eco.totalPlatformCharges, 2000.0);
      expect(eco.totalOperationsCost, 23000.0);
      expect(eco.valueSold, 98000.0);
      expect(eco.netRealizedProfit, 27000.0);
      expect(eco.netMarginPercent, closeTo(27.55, 0.05));
    });

    test('Operational costs accumulate as failed deliveries and transactions increase', () {
      final baseEco = ClientUnitEconomics.calculate(
        productName: 'Organic Detox Tea',
        productSku: 'ODT-02',
        baseSupplierPrice: 1500.0,
        catalogRetailPrice: 8500.0,
        quantitySold: 5,
        valueSold: 42500.0,
        deliveredOrdersCount: 5,
        failedOrdersCount: 1,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
      );
      expect(baseEco.totalFailedFees, 500.0);
      expect(baseEco.totalOperationsCost, 28000.0);

      final accumulatedEco = ClientUnitEconomics.calculate(
        productName: 'Organic Detox Tea',
        productSku: 'ODT-02',
        baseSupplierPrice: 1500.0,
        catalogRetailPrice: 8500.0,
        quantitySold: 5,
        valueSold: 42500.0,
        deliveredOrdersCount: 5,
        failedOrdersCount: 6,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
      );
      expect(accumulatedEco.totalFailedFees, 3000.0);
      expect(accumulatedEco.totalOperationsCost, 30500.0);
      expect(accumulatedEco.netRealizedProfit < baseEco.netRealizedProfit, isTrue);
    });

    test('ClientPortalState unitEconomicsList correctly links stock balances, orders, and onboarding profile', () {
      const profile = ClientProfile(
        id: 'client-test-99',
        companyName: 'Apex Health Ltd',
        contactPerson: 'Apex Manager',
        phone: '08012345678',
        email: 'billing@apex.ng',
        address: '12 Marina Road, Lagos',
        bankName: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'Apex Health Ltd',
        customDeliveryFee: 4800.0,
        customFailedAttemptFee: 650.0,
        customPlatformFeeValue: 400.0,
        customPlatformFeeType: 'flat',
      );

      final now = DateTime.now();

      final stockBal = ClientStockBalance(
        id: 'bal-1',
        clientId: 'client-test-99',
        itemCode: 'SKU-APEX-01',
        itemName: 'Apex Omega 3',
        warehouse: 'Stores - Lagos Central',
        stockUom: 'Bottle',
        balanceQty: 50.0,
        balanceValue: 125000.0,
        valuationRate: 2500.0,
        updatedAt: now,
      );

      final List<OrderEntity> testOrders = [
        OrderEntity(
          id: 'ord-101',
          orderNumber: 'NVX-101',
          productName: 'Apex Omega 3',
          productSku: 'SKU-APEX-01',
          quantity: 2,
          basePrice: 18500.0,
          upsellAmount: 0.0,
          totalAmount: 18500.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          status: 'delivered',
          deliveredAt: now,
          customerName: 'Customer A',
          customerPhone: '08011111111',
          deliveryAddress: 'Lekki Phase 1',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-102',
          orderNumber: 'NVX-102',
          productName: 'Apex Omega 3',
          productSku: 'SKU-APEX-01',
          quantity: 1,
          basePrice: 11000.0,
          upsellAmount: 0.0,
          totalAmount: 11000.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'collected',
          status: 'delivered',
          deliveredAt: now,
          customerName: 'Customer B',
          customerPhone: '08022222222',
          deliveryAddress: 'Ikeja',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos',
          createdAt: now,
        ),
        OrderEntity(
          id: 'ord-103',
          orderNumber: 'NVX-103',
          productName: 'Apex Omega 3',
          productSku: 'SKU-APEX-01',
          quantity: 2,
          basePrice: 18500.0,
          upsellAmount: 0.0,
          totalAmount: 18500.0,
          paymentType: 'pay_on_delivery',
          paymentStatus: 'pending',
          status: 'failed',
          customerName: 'Customer C',
          customerPhone: '08033333333',
          deliveryAddress: 'Victoria Island',
          deliveryCity: 'Lagos',
          deliveryState: 'Lagos',
          createdAt: now,
        ),
      ];

      final state = ClientPortalState(
        clientProfile: profile,
        stockBalances: [stockBal],
        orders: testOrders,
      );

      final ecoList = state.unitEconomicsList;
      expect(ecoList.length, 1);

      final eco = ecoList.first;
      expect(eco.productName, 'Apex Omega 3');
      expect(eco.productSku, 'SKU-APEX-01');
      expect(eco.baseSupplierPrice, 1625.0);
      expect(eco.quantitySold, 3);
      expect(eco.valueSold, 29500.0);
      expect(eco.deliveredOrdersCount, 2);
      expect(eco.failedOrdersCount, 1);
      expect(eco.deliveryFeeRate, 4800.0);
      expect(eco.failedFeeRate, 650.0);
      expect(eco.totalDeliveryFees, 9600.0);
      expect(eco.totalFailedFees, 650.0);
      expect(eco.totalPlatformCharges, 800.0);
      expect(eco.totalOperationsCost, 9600.0 + 650.0 + 800.0);
    });
  });

  group('Pangea Excel Data Table & Operational Modal UI Tests', () {
    testWidgets('ClientOperationalCostBreakdownModal renders all cost drivers and notes', (tester) async {
      final eco = ClientUnitEconomics.calculate(
        productName: 'Probiotic Slim',
        productSku: 'PBS-007',
        baseSupplierPrice: 3500.0,
        catalogRetailPrice: 16500.0,
        quantitySold: 8,
        valueSold: 66000.0,
        deliveredOrdersCount: 4,
        failedOrdersCount: 3,
        totalOrdersCount: 7,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClientOperationalCostBreakdownModal.show(
                  context,
                  economics: eco,
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Operations Cost Breakdown'), findsOneWidget);
      expect(find.text('Probiotic Slim • PBS-007'), findsOneWidget);

      expect(find.text('₦23,500.00'), findsWidgets);
      expect(find.text('7 Total Orders'), findsOneWidget);

      expect(find.text('Successful Order Delivery Fees'), findsOneWidget);
      expect(find.text('Failed Delivery Attempt Charges'), findsOneWidget);
      expect(find.text('System Platform & Infrastructure Charges'), findsOneWidget);

      expect(find.textContaining('As failed deliveries accumulate across dispatches'), findsOneWidget);
      expect(find.textContaining('As transaction volume grows, platform charges scale'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Operations Cost Breakdown'), findsNothing);
    });

    testWidgets('PangeaExcelDataTable renders group headers, resizable columns, and handles click on Operations Cost', (tester) async {
      final eco = ClientUnitEconomics.calculate(
        productName: 'Glutathione Glow',
        productSku: 'GLO-01',
        baseSupplierPrice: 4000.0,
        catalogRetailPrice: 20000.0,
        quantitySold: 10,
        valueSold: 95000.0,
        deliveredOrdersCount: 5,
        failedOrdersCount: 2,
        totalOrdersCount: 7,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
      );

      final columns = [
        ExcelColumnDef<ClientUnitEconomics>(
          key: 'productName',
          group: 'Product',
          label: 'PRODUCT NAME',
          defaultWidth: 180,
          searchString: (e) => e.productName,
          cellBuilder: (context, e, row, isDark, brand) => Text(e.productName),
        ),
        ExcelColumnDef<ClientUnitEconomics>(
          key: 'valueSold',
          group: 'Packages & Sales',
          label: 'VALUE SOLD',
          defaultWidth: 140,
          align: TextAlign.right,
          cellBuilder: (context, e, row, isDark, brand) => Text('₦${e.valueSold.toStringAsFixed(2)}'),
        ),
        ExcelColumnDef<ClientUnitEconomics>(
          key: 'totalOperationsCost',
          group: 'Operations Cost',
          label: 'OPERATIONS COST',
          defaultWidth: 180,
          align: TextAlign.right,
          cellBuilder: (context, e, row, isDark, brand) => InkWell(
            key: const ValueKey('ops_cost_cell'),
            onTap: () => ClientOperationalCostBreakdownModal.show(context, economics: e),
            child: Text('₦${e.totalOperationsCost.toStringAsFixed(2)}'),
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: PangeaExcelDataTable<ClientUnitEconomics>(
                items: [eco],
                columns: columns,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('PACKAGES & SALES'), findsOneWidget);
      expect(find.text('OPERATIONS COST'), findsWidgets);

      expect(find.text('PRODUCT NAME'), findsOneWidget);
      expect(find.text('VALUE SOLD'), findsOneWidget);

      expect(find.text('Glutathione Glow'), findsOneWidget);
      expect(find.text('₦95000.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ops_cost_cell')));
      await tester.pumpAndSettle();

      expect(find.text('Operations Cost Breakdown'), findsOneWidget);
      expect(find.text('Glutathione Glow • GLO-01'), findsOneWidget);
    });

    testWidgets('ClientOperationalCostCell displays breakdown on hover and opens modal on click', (tester) async {
      final eco = ClientUnitEconomics.calculate(
        productName: 'Herbal Detox Tea',
        productSku: 'HDT-01',
        baseSupplierPrice: 1500.0,
        catalogRetailPrice: 8500.0,
        quantitySold: 4,
        valueSold: 34000.0,
        deliveredOrdersCount: 2,
        failedOrdersCount: 1,
        totalOrdersCount: 3,
        deliveryFeeRate: 5000.0,
        failedFeeRate: 500.0,
        platformChargeRate: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ClientOperationalCostCell(
                economics: eco,
                brandPrimary: const Color(0xFF0D9488),
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total operations cost should be visible (10,000 + 500 + 1,000 = 11,500)
      expect(find.text('₦11,500.00'), findsOneWidget);

      // Simulate mouse hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(ClientOperationalCostCell)));
      await tester.pumpAndSettle();

      // Hover popover breakdown should now be displayed
      expect(find.text('Click cell to view full audit modal'), findsOneWidget);
      expect(find.text('Delivery Fees (2 orders)'), findsOneWidget);
      expect(find.text('Failed Attempt Fees (1 orders)'), findsOneWidget);

      // Click cell to open the full modal
      await tester.tap(find.byType(ClientOperationalCostCell));
      await tester.pumpAndSettle();

      // Full modal is opened
      expect(find.text('Herbal Detox Tea • HDT-01'), findsOneWidget);
      expect(find.text('Rates configured in Client Onboarding Profile'), findsOneWidget);
    });

    test('ClientPortalState unitEconomicsList respects inventoryStartDate and inventoryEndDate', () {
      const profile = ClientProfile(
        id: 'cli-novacare',
        companyName: 'Novacare Ltd',
        contactPerson: 'Joel',
        email: 'info@novacare.com',
        phone: '0800000000',
        address: 'Abuja',
        city: 'Abuja',
        state: 'FCT',
        code: 'NOV',
        tier: 'platinum',
        closerLimit: 5,
        isEnterprise: true,
        customDeliveryFee: 5000.0,
        customFailedAttemptFee: 500.0,
        customPlatformFeeValue: 500.0,
        customPlatformFeeType: 'flat',
      );

      final stockBal = ClientStockBalance(
        id: 'sb-1',
        clientId: 'cli-novacare',
        itemCode: 'SKU-TEA-01',
        itemName: 'Novacare Slim Tea',
        warehouse: 'Abuja Central Hub',
        balanceQty: 100.0,
        balanceValue: 150000.0,
        valuationRate: 1500.0,
        updatedAt: DateTime.now(),
      );

      final t0 = DateTime(2026, 9, 1);
      final t1 = DateTime(2026, 9, 10);
      final t2 = DateTime(2026, 9, 20);

      final orderInWindow = OrderEntity(
        id: 'o-1',
        orderNumber: 'ORD-IN-WINDOW',
        customerName: 'Customer A',
        customerPhone: '0801',
        deliveryAddress: 'Lagos',
        deliveryCity: 'Lagos',
        deliveryState: 'Lagos',
        totalAmount: 15000.0,
        quantity: 2,
        status: 'delivered',
        productName: 'Novacare Slim Tea',
        productSku: 'SKU-TEA-01',
        createdAt: t1,
        deliveredAt: t1,
        basePrice: 7500.0,
        upsellAmount: 0.0,
        paymentType: 'cod',
        paymentStatus: 'paid',
      );

      final orderOutsideWindow = OrderEntity(
        id: 'o-2',
        orderNumber: 'ORD-OUTSIDE',
        customerName: 'Customer B',
        customerPhone: '0802',
        deliveryAddress: 'Lagos',
        deliveryCity: 'Lagos',
        deliveryState: 'Lagos',
        totalAmount: 30000.0,
        quantity: 4,
        status: 'delivered',
        productName: 'Novacare Slim Tea',
        productSku: 'SKU-TEA-01',
        createdAt: t2,
        deliveredAt: t2,
        basePrice: 7500.0,
        upsellAmount: 0.0,
        paymentType: 'cod',
        paymentStatus: 'paid',
      );

      // State without date filter
      final stateAll = ClientPortalState(
        clientProfile: profile,
        stockBalances: [stockBal],
        orders: [orderInWindow, orderOutsideWindow],
      );
      expect(stateAll.unitEconomicsList.first.quantitySold, 6);
      expect(stateAll.unitEconomicsList.first.valueSold, 45000.0);

      // State with date filter limiting to Sept 1 - Sept 15
      final stateFiltered = ClientPortalState(
        clientProfile: profile,
        stockBalances: [stockBal],
        orders: [orderInWindow, orderOutsideWindow],
        inventoryStartDate: t0,
        inventoryEndDate: DateTime(2026, 9, 15),
      );
      expect(stateFiltered.unitEconomicsList.first.quantitySold, 2);
      expect(stateFiltered.unitEconomicsList.first.valueSold, 15000.0);
    });
  });
}
