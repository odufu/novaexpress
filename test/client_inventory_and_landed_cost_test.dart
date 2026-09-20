import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/client_portal/domain/entities/client_supplier.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_invoice.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_balance.dart';
import 'package:novexps/features/client_portal/domain/entities/client_unit_economics.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Client Inventory & Landed Cost Domain Models', () {
    test('ClientSupplier initializes and converts to/from JSON correctly', () {
      final supplier = ClientSupplier(
        id: 'sup-1',
        clientId: 'client-1',
        supplierName: 'Apex Herbal Labs',
        category: 'Herbal Formulations',
        contactPerson: 'Dr. Mike',
        email: 'mike@apex.com',
        phone: '08012345678',
        paymentTerms: 'Net 30',
        leadTimeDays: 14,
        bankName: 'GTBank',
        accountNumber: '0123456789',
        createdAt: DateTime(2026, 9, 1),
      );

      expect(supplier.name, 'Apex Herbal Labs');
      expect(supplier.bankAccountNumber, '0123456789');

      final json = supplier.toJson();
      expect(json['supplier_name'], 'Apex Herbal Labs');
      expect(json['category'], 'Herbal Formulations');
      expect(json['lead_time_days'], 14);

      final fromJson = ClientSupplier.fromJson(json);
      expect(fromJson.id, 'sup-1');
      expect(fromJson.name, 'Apex Herbal Labs');
      expect(fromJson.leadTimeDays, 14);
    });

    test('ClientStockInvoiceItem accurately computes landed cost and margins', () {
      // Base: 1500, Packaging: 250, Freight: 150, Handling: 50 -> Landed: 1950
      final item = ClientStockInvoiceItem.calculate(
        id: 'item-1',
        invoiceId: 'inv-1',
        productName: 'Grazer Herbal Tea',
        productSku: 'GRAZER-TEA-20',
        quantity: 100,
        supplierUnitPrice: 1500.0,
        packagingCostPerUnit: 250.0,
        transportationCostPerUnit: 150.0,
        handlingCostPerUnit: 50.0,
        targetRetailPrice: 6500.0,
      );

      expect(item.effectiveLandedCostPerUnit, 1950.0);
      expect(item.effectiveLandedCost, 1950.0);
      expect(item.totalLandedCost, 195000.0);
      // Margin: (6500 - 1950) / 6500 = 4550 / 6500 = 70.0%
      expect(item.projectedMarginPercent, closeTo(70.0, 0.01));
    });

    test('ClientStockBalance computes availableToSell and status accurately', () {
      final balance = ClientStockBalance(
        id: 'bal-1',
        clientId: 'client-1',
        itemCode: 'GRAZER-TEA-20',
        itemName: 'Grazer Herbal Tea (20 Tea Bags)',
        warehouse: 'Central Abuja Hub',
        balanceQty: 100,
        reservedStock: 25,
        balanceValue: 190855.6,
        valuationRate: 1908.556,
        lowStockThreshold: 20,
        updatedAt: DateTime(2026, 9, 13),
      );

      expect(balance.availableToSell, 75.0);
      expect(balance.status, 'Healthy');
      expect(balance.stockStatus, 'Healthy');
      expect(balance.item, 'GRAZER-TEA-20');

      final lowBalance = balance.copyWith(balanceQty: 15);
      expect(lowBalance.status, 'Low Stock');

      final zeroBalance = balance.copyWith(balanceQty: 0);
      expect(zeroBalance.status, 'Out of Stock');
    });

    test('ClientUnitEconomics accurately calculates gross margin amount and percentage', () {
      final unitEco = ClientUnitEconomics.calculate(
        productName: 'Ura Clear',
        productSku: 'URA-CLEAR-01',
        baseSupplierPrice: 2000.0,
        packagingAddon: 400.0,
        transportationAddon: 300.0,
        handlingAddon: 250.0,
        catalogRetailPrice: 8500.0,
        totalUnitsOnHand: 500,
      );

      expect(unitEco.totalLandedCost, 2950.0);
      expect(unitEco.grossMarginAmount, 5550.0);
      // Margin %: 5550 / 8500 * 100 = 65.294%
      expect(unitEco.grossMarginPercent, closeTo(65.29, 0.1));
      expect(unitEco.totalInventoryValuation, 2950.0 * 500);
    });

    test('ClientProfile correctly exposes hasInventoryManagement flag', () {
      const enterpriseClient = ClientProfile(
        id: 'ent-1',
        companyName: 'Novacare Ltd',
        contactPerson: 'Director',
        email: 'director@novacare.com',
        phone: '0800000000',
        address: 'Abuja',
        city: 'Abuja',
        state: 'FCT',
        code: 'NOVACARE',
        tier: 'enterprise',
        hasInventoryManagement: true,
      );
      expect(enterpriseClient.hasInventoryManagement, isTrue);

      const standardClient = ClientProfile(
        id: 'std-1',
        companyName: 'Small Shop',
        contactPerson: 'Owner',
        email: 'owner@shop.com',
        phone: '0800000001',
        address: 'Lagos',
        city: 'Ikeja',
        state: 'Lagos',
        code: 'SHOP',
        tier: 'standard_merchant',
        hasInventoryManagement: false,
      );
      expect(standardClient.hasInventoryManagement, isFalse);
    });
  });

  group('ClientPortalNotifier Inventory Management Operations', () {
    test('ClientPortalState computes inventory totals and handles CSV', () async {
      final container = ProviderContainer();
      final notifier = container.read(clientPortalProvider.notifier);

      // Load initial data
      await notifier.loadClientData();
      final state = container.read(clientPortalProvider);

      // Verify default data or loaded data
      expect(state.suppliers, isNotEmpty);
      expect(state.stockBalances, isNotEmpty);
      expect(state.totalStockValuation, greaterThan(0));
      expect(state.totalStockQuantity, greaterThan(0));
      expect(state.uniqueWarehousesCount, greaterThan(0));

      // Test CSV Export
      final exportedCsv = notifier.generateStockBalanceCsv();
      expect(exportedCsv, contains('Item,Item Name,Item Group,Warehouse'));
      expect(exportedCsv, contains('Grazer Herbal Tea'));

      // Test CSV Import
      const newCsv = '''Item,Item Name,Item Group,Warehouse,Stock UOM,Balance Qty,Balance Value,Opening Qty,Opening Value,In Qty,In Value,Out Qty,Out Value,Valuation Rate,Reserved Stock,Company
TEST-ITEM,Test Herbal Supplement,Products,Test Central Hub,Nos,100,200000.00,100,200000.00,0,0,0,0,2000.000,10,Test Ltd''';

      await notifier.importStockBalanceCsv(newCsv);
      final updatedState = container.read(clientPortalProvider);
      expect(updatedState.stockBalances.any((b) => b.itemCode == 'TEST-ITEM'), isTrue);

      // Test Create Supplier
      final newSup = ClientSupplier(
        id: '',
        clientId: state.clientProfile.id,
        supplierName: 'New Test Supplier Ltd',
        category: 'Packaging Materials',
        contactPerson: 'John Test',
        email: 'john@test.com',
        phone: '08099887766',
        paymentTerms: 'Net 15',
        leadTimeDays: 5,
        bankName: 'Zenith Bank',
        accountNumber: '1122334455',
        createdAt: DateTime.now(),
      );
      final created = await notifier.createSupplier(newSup);
      expect(created.supplierName, 'New Test Supplier Ltd');
      expect(container.read(clientPortalProvider).suppliers.any((s) => s.supplierName == 'New Test Supplier Ltd'), isTrue);

      // Test Raise Stock Invoice
      final item = ClientStockInvoiceItem.calculate(
        productName: 'Test Herbal Supplement',
        productSku: 'TEST-ITEM',
        quantity: 50,
        supplierUnitPrice: 1000.0,
        packagingCostPerUnit: 200.0,
        transportationCostPerUnit: 100.0,
        handlingCostPerUnit: 50.0,
      );
      final newInvoice = ClientStockInvoice(
        id: '',
        clientId: state.clientProfile.id,
        invoiceNumber: 'INV-TEST-001',
        supplierId: created.id,
        supplierName: created.supplierName,
        destinationWarehouse: 'Test Central Hub',
        entryDate: DateTime.now(),
        status: 'verified',
        paymentStatus: 'unpaid',
        totalUnits: 50,
        subtotalRawProductCost: 50000.0,
        totalPackagingCost: 10000.0,
        totalTransportationCost: 5000.0,
        totalHandlingClearingCost: 2500.0,
        grandTotalLandedCost: 67500.0,
        notes: 'Test shipment',
        items: [item],
        createdAt: DateTime.now(),
      );

      final postedInvoice = await notifier.raiseStockInvoice(invoice: newInvoice, items: [item]);
      expect(postedInvoice.invoiceNumber, 'INV-TEST-001');
      expect(postedInvoice.grandTotalLandedCost, 67500.0);
      expect(container.read(clientPortalProvider).stockInvoices.any((i) => i.invoiceNumber == 'INV-TEST-001'), isTrue);

      container.dispose();
    });
  });
}
