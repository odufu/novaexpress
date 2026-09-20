import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:novexps/features/auth/data/models/user_model.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
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
  FakeClientPortalNotifier(super.initialState);

  @override
  Future<void> loadClientData() async {}

  @override
  Future<void> reloadInventoryData({DateTime? startDate, DateTime? endDate}) async {}

  @override
  String generateStockBalanceCsv() => 'Item,Item Name\nSKU-01,Product';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testBalance1 = ClientStockBalance(
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
    company: 'Novacare Ltd',
    updatedAt: DateTime.now(),
  );

  final testBalance2 = ClientStockBalance(
    id: 'bal-02',
    clientId: 'cli-novacare',
    itemCode: 'SKU-HAIR-DYE',
    itemName: 'Hair Dye Shampoo',
    itemGroup: 'Novacare',
    warehouse: 'PELICAN DELIVERY - NL',
    stockUom: 'Nos',
    openingQty: 63,
    openingValue: 315000.0,
    inQty: 0,
    inValue: 0.0,
    outQty: 0,
    outValue: 0.0,
    balanceQty: 63,
    balanceValue: 315000.0,
    valuationRate: 5000.0,
    company: 'Novacare Ltd',
    updatedAt: DateTime.now(),
  );

  final portalState = ClientPortalState(
    isLoading: false,
    clientProfile: const ClientProfile(
      id: 'cli-novacare',
      companyName: 'Novacare Ltd',
      contactPerson: 'Director',
      email: 'orders@novacare.ng',
      phone: '08012345678',
      address: 'Abuja, Nigeria',
      hasInventoryManagement: true,
      servicesEnabled: ['inventory_management'],
    ),
    stockBalances: [testBalance1, testBalance2],
    stockInvoices: const [],
    suppliers: const [],
    orders: const [],
    products: const [],
    leads: const [],
  );

  const testUser = UserModel(
    id: 'user-novacare',
    email: 'orders@novacare.ng',
    firstName: 'Novacare',
    lastName: 'Admin',
    phone: '08012345678',
    role: 'client',
    clientId: 'cli-novacare',
    clientCompanyName: 'Novacare Ltd',
  );

  testWidgets('Excel-style Stock Balance table displays Pangea filters, columns, and resizable layout', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          clientPortalProvider.overrideWith((ref) => FakeClientPortalNotifier(portalState)),
        ],
        child: const MaterialApp(
          home: ClientInventoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Top Filter Row 1 (from Pangea Suite screenshot)
    final lagosNow = DateTime.now().toUtc().add(const Duration(hours: 1));
    final today = DateTime(lagosNow.year, lagosNow.month, lagosNow.day);
    final start = today.subtract(const Duration(days: 6));
    final expectedRange = '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(today)}';

    expect(find.text('Stock Balance'), findsOneWidget);
    expect(find.text('Novacare Ltd'), findsWidgets);
    expect(find.text(expectedRange), findsOneWidget);
    expect(find.text('Lagos Time'), findsOneWidget);

    // Verify Filter Row 2 & Checkboxes
    expect(find.text('Include UOM'), findsOneWidget);
    expect(find.text('Show Variant Attributes'), findsOneWidget);
    expect(find.text('Show Stock Ageing Data'), findsOneWidget);
    expect(find.text('Ignore Closing Balance'), findsOneWidget);

    // Verify Filter Row 3
    expect(find.text('Include Zero Stock Items'), findsOneWidget);
    expect(find.text('Show Dimension Wise Stock'), findsOneWidget);

    // Verify Excel Column Headers
    expect(find.text('#'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Item Name'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);
    expect(find.text('Balance Qty'), findsOneWidget);
    expect(find.text('Balance Value'), findsOneWidget);
    expect(find.text('In Qty'), findsOneWidget);
    expect(find.text('Out Qty'), findsOneWidget);

    // Verify Data Rows
    expect(find.text('Grazer Herbal Tea'), findsWidgets);
    expect(find.text('SKU-GRAZ-TEA'), findsWidgets);
    expect(find.text('Hair Dye Shampoo'), findsWidgets);
    expect(find.text('Stores - NL'), findsWidgets);

    // Verify Table Footer & Column Reset Button
    expect(find.text('Reset Column Widths'), findsOneWidget);
    expect(find.textContaining('Drag column borders to resize'), findsOneWidget);

    // Tap Reset Column Widths
    await tester.tap(find.text('Reset Column Widths'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });
}
