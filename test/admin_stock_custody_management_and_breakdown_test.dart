import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/admin_console/domain/entities/admin_models.dart';
import 'package:novexps/features/admin_console/presentation/widgets/admin_stock_holder_detail_modal.dart';
import 'package:novexps/features/admin_console/presentation/widgets/admin_manage_agent_custody_modal.dart';
import 'package:novexps/features/admin_console/presentation/providers/admin_console_provider.dart';

void main() {
  final testProducts = [
    const AdminGlobalStockItem(
      id: 'prod-grazer-uuid',
      productId: 'prod-grazer-uuid',
      productName: 'Grazer Herbal Detox Tea',
      sku: 'SKU-PRD-8309',
      merchantId: 'client-novacare',
      merchantName: 'NOVACARE LIMITED',
      unitPrice: 22800.0,
      totalWarehouseStock: 46085,
      totalRiderCustodyStock: 0,
      totalStock: 46085,
    ),
    const AdminGlobalStockItem(
      id: 'prod-triple-h-uuid',
      productId: 'prod-triple-h-uuid',
      productName: 'TRIPLE H BALANCE TEA',
      sku: 'SKU-08806',
      merchantId: 'client-novacare',
      merchantName: 'NOVACARE LIMITED',
      unitPrice: 22800.0,
      totalWarehouseStock: 12990,
      totalRiderCustodyStock: 0,
      totalStock: 12990,
    ),
    const AdminGlobalStockItem(
      id: 'prod-ura-clear-uuid',
      productId: 'prod-ura-clear-uuid',
      productName: 'URA Clear',
      sku: 'SKU-PRD-6731',
      merchantId: 'client-novacare',
      merchantName: 'NOVACARE LIMITED',
      unitPrice: 22800.0,
      totalWarehouseStock: 46650,
      totalRiderCustodyStock: 0,
      totalStock: 46650,
    ),
  ];

  testWidgets('AdminStockHolderDetailModal renders product breakdown accurately by SKU and product name', (tester) async {
    final holder = AdminStockHolderRow(
      id: 'shelf-dc-abuja',
      name: 'Abuja Central DC (Warehouse Shelf)',
      code: 'DC-ABJ-01',
      type: AdminStockHolderType.dcShelf,
      hubName: 'Abuja Central DC',
      hubId: 'DC-ABJ-01',
      productQuantities: const {
        'SKU-PRD-8309': 46085,
        'SKU-08806': 12990,
        'SKU-PRD-6731': 46650,
      },
      totalUnits: 105725,
      totalValueNaira: 2413037500.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminStockHolderDetailModal(
            holder: holder,
            allProducts: testProducts,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header details
    expect(find.text('Abuja Central DC (Warehouse Shelf)'), findsOneWidget);
    expect(find.text('105725 units'), findsWidgets);
    expect(find.text('3 SKUs'), findsOneWidget);

    // Verify itemized products are shown in the breakdown!
    expect(find.text('Grazer Herbal Detox Tea'), findsOneWidget);
    expect(find.text('46085 units'), findsOneWidget);
    expect(find.text('TRIPLE H BALANCE TEA'), findsOneWidget);
    expect(find.text('12990 units'), findsOneWidget);
    expect(find.text('URA Clear'), findsOneWidget);
    expect(find.text('46650 units'), findsOneWidget);

    // Ensure it does NOT show "No active stock currently allocated"
    expect(find.text('No active stock currently allocated to this custodian.'), findsNothing);
  });

  testWidgets('AdminStockHolderDetailModal for Agent shows Adjust Custody Stock button and triggers callback', (tester) async {
    bool custodyTriggered = false;

    final agentHolder = AdminStockHolderRow(
      id: 'ag-adicha',
      name: 'ADICHA LOGISTICS',
      code: 'AG-001',
      type: AdminStockHolderType.external3pl,
      hubName: 'Lagos Central DC',
      hubId: 'DC-LAG-01',
      productQuantities: const {
        'SKU-PRD-8309': 150,
      },
      totalUnits: 150,
      totalValueNaira: 3420000.0,
      agentRef: AdminLogisticsAgent(
        id: 'ag-adicha',
        name: 'ADICHA LOGISTICS',
        agentCode: 'AG-001',
        type: '3pl_partner',
        contactPerson: 'Adicha Bello',
        phone: '+234 8003000031',
        email: 'adicha@novaxpress.cx',
        assignedWarehouseId: 'DC-LAG-01',
        assignedWarehouseName: 'Lagos Central DC',
        heldStock: const {'SKU-PRD-8309': 150},
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminStockHolderDetailModal(
            holder: agentHolder,
            allProducts: testProducts,
            onManageCustody: () {
              custodyTriggered = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Adjust Custody Stock'), findsOneWidget);
    await tester.tap(find.text('Adjust Custody Stock'));
    await tester.pumpAndSettle();

    expect(custodyTriggered, isTrue);
  });

  testWidgets('AdminManageAgentCustodyModal displays current held stock and allows edits', (tester) async {
    final agent = AdminLogisticsAgent(
      id: 'ag-adicha',
      name: 'ADICHA LOGISTICS',
      agentCode: 'AG-001',
      type: '3pl_partner',
      contactPerson: 'Adicha Bello',
      phone: '+234 8003000031',
      email: 'adicha@novaxpress.cx',
      assignedWarehouseId: 'DC-LAG-01',
      assignedWarehouseName: 'Lagos Central DC',
      heldStock: const {'SKU-PRD-8309': 150},
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdminManageAgentCustodyModal(
              agent: agent,
              catalogProducts: testProducts,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify agent title & existing custody
    expect(find.text('Manage Agent Stock Custody'), findsOneWidget);
    expect(find.text('AG-001'), findsOneWidget);
    expect(find.text('150 units'), findsWidgets);
    expect(find.text('Grazer Herbal Detox Tea'), findsOneWidget);

    // Increase quantity using increment button
    await tester.tap(find.byTooltip('Increase 10 units'));
    await tester.pumpAndSettle();

    expect(find.text('160 units'), findsWidgets);
    expect(find.text('+10 units (Inbound)'), findsOneWidget);
  });
}
