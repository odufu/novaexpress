import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_invoice.dart';
import 'package:novexps/features/client_portal/domain/entities/client_supplier.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_inventory_page.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserModel user)
      : super(AuthState(
          user: user,
          isInitialized: true,
        ));

  @override
  Future<void> checkCurrentUser() async {}

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClientPortalNotifier extends StateNotifier<ClientPortalState>
    implements ClientPortalNotifier {
  FakeClientPortalNotifier(ClientPortalState initialState) : super(initialState);

  @override
  Future<void> loadClientData() async {}

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {}

  @override
  String generateStockBalanceCsv() {
    return 'Item,Item Name,Item Group,Warehouse,Stock UOM,Balance Qty,Balance Value,Valuation Rate\nTEST-01,"Test Item","Novacare","Stores - NL",Nos,100,200000.00,2000.000';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testSupplier = ClientSupplier(
    id: 'sup-01',
    clientId: 'cli-novacare',
    supplierName: 'Apex Herbal Laboratories Ltd',
    category: 'Botanical Extracts',
    contactPerson: 'Musa Danjuma',
    email: 'musa@apex.ng',
    phone: '08023456781',
    address: 'Kano, Nigeria',
    city: 'Kano',
    paymentTerms: 'Net 15',
    suppliedProducts: const ['Grazer Herbal Tea'],
    createdAt: DateTime.now(),
  );

  final testInvoice = ClientStockInvoice(
    id: 'inv-01',
    clientId: 'cli-novacare',
    invoiceNumber: 'INV-STK-NOV-2026-001',
    supplierId: 'sup-01',
    supplierName: 'Apex Herbal Laboratories Ltd',
    destinationWarehouse: 'Stores - NL',
    entryDate: DateTime.now(),
    status: 'verified',
    paymentStatus: 'paid',
    totalUnits: 5000,
    subtotalRawProductCost: 6000000.0,
    totalPackagingCost: 1750000.0,
    totalTransportationCost: 1792780.0,
    grandTotalLandedCost: 9542780.0,
    items: const [
      ClientStockInvoiceItem(
        id: 'item-01',
        invoiceId: 'inv-01',
        productName: 'Grazer Herbal Tea',
        productSku: 'SKU-GRAZ-TEA',
        quantity: 5000,
        supplierUnitPrice: 1200.0,
        packagingCostPerUnit: 350.0,
        transportationCostPerUnit: 358.556,
        effectiveLandedCostPerUnit: 1908.556,
        totalLandedCost: 9542780.0,
        targetRetailPrice: 8500.0,
        projectedMarginPercent: 77.55,
      ),
    ],
    createdAt: DateTime.now(),
  );

  final testBalance = ClientStockBalance(
    id: 'bal-01',
    clientId: 'cli-novacare',
    itemCode: 'SKU-GRAZ-TEA',
    itemName: 'Grazer Herbal Tea',
    itemGroup: 'Novacare',
    warehouse: 'Stores - NL',
    stockUom: 'Nos',
    openingQty: 24177,
    openingValue: 46131425.51,
    inQty: 34,
    inValue: 66752.39,
    outQty: 3040,
    outValue: 5792142.40,
    balanceQty: 21171,
    balanceValue: 40406035.50,
    valuationRate: 1908.556,
    reservedStock: 250,
    company: 'Novacare Ltd',
    updatedAt: DateTime.now(),
  );

  final testPortalState = ClientPortalState(
    isLoading: false,
    clientProfile: const ClientProfile(
      id: 'cli-novacare',
      companyName: 'Novacare Ltd',
      contactPerson: 'Director',
      email: 'orders@novacare.ng',
      phone: '08012345678',
      address: 'Abuja, Nigeria',
      hasInventoryManagement: true,
      servicesEnabled: ['fulfillment', 'delivery', 'inventory_management'],
    ),
    suppliers: [testSupplier],
    stockInvoices: [testInvoice],
    stockBalances: [testBalance],
    orders: const [],
    products: const [],
    leads: const [],
  );

  const testUser = UserModel(
    id: 'user-01',
    email: 'orders@novacare.ng',
    firstName: 'Novacare',
    lastName: 'Admin',
    phone: '08099887766',
    role: 'client',
    clientId: 'cli-novacare',
    clientCompanyName: 'Novacare Ltd',
  );

  testWidgets('ClientInventoryPage renders hero, KPIs, and all four tabs', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(testPortalState)),
        ],
        child: const MaterialApp(
          home: ClientInventoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('PANGEA SUITE COMPATIBLE'), findsOneWidget);
    expect(find.text('Inventory & Landed Cost Supply Chain'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('+ Raise Stock Invoice'), findsOneWidget);
    expect(find.text('Import CSV'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);

    // Verify Tabs
    expect(find.textContaining('Stock Ledger'), findsOneWidget);
    expect(find.textContaining('Intake Invoices'), findsOneWidget);
    expect(find.textContaining('Suppliers Directory'), findsOneWidget);
    expect(find.textContaining('Unit Economics & Landed Cost'), findsOneWidget);

    // Verify Stock Ledger Table Data
    expect(find.text('Grazer Herbal Tea'), findsWidgets);
    expect(find.text('SKU-GRAZ-TEA'), findsWidgets);

    // Switch to Intake Invoices tab
    await tester.tap(find.textContaining('Intake Invoices'));
    await tester.pumpAndSettle();

    expect(find.text('INV-STK-NOV-2026-001'), findsOneWidget);
    expect(find.textContaining('Apex Herbal Laboratories Ltd'), findsWidgets);

    // Switch to Suppliers Directory tab
    await tester.tap(find.textContaining('Suppliers Directory'));
    await tester.pumpAndSettle();

    expect(find.text('+ Register Supplier'), findsWidgets);
    expect(find.text('Musa Danjuma'), findsOneWidget);

    // Switch to Unit Economics tab
    await tester.tap(find.textContaining('Unit Economics & Landed Cost'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Product Landed Cost vs Wholesale Pricing Matrix'), findsOneWidget);
  });
}
