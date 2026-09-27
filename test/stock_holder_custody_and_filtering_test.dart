import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/stock_holder_custody.dart';

void main() {
  group('StockHolderCustodyEntity and Reconciliation Tests', () {
    final mockAlphaManHolders = [
      StockHolderCustodyEntity(
        id: 'custody-1',
        holderId: 'dc-wuse-01',
        holderName: 'Wuse Grand Central Distribution Center',
        holderType: 'Grand DC',
        state: 'Abuja (FCT)',
        lga: 'Abuja Municipal (AMAC)',
        city: 'Wuse Central Apex Hub',
        phone: '+234 803 100 2001',
        productId: 'prod-alpha-001',
        productSku: 'SKU-ALPHA-01',
        productName: 'Alpha Man Herbal Formula',
        openingQty: 100,
        inQty: 20,
        outQty: 20,
        closingQty: 100,
        valuationRate: 15000,
        openingValue: 1500000,
        inValue: 300000,
        outValue: 300000,
        closingValue: 1500000,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'Active Custody',
      ),
      StockHolderCustodyEntity(
        id: 'custody-2',
        holderId: 'dc-kd-001',
        holderName: 'Kaduna Hub Distribution Center',
        holderType: 'Hub Distribution Center',
        state: 'Kaduna',
        lga: 'Kaduna North',
        city: 'Ahmadu Bello Way',
        phone: '+234 802 222 2222',
        productId: 'prod-alpha-001',
        productSku: 'SKU-ALPHA-01',
        productName: 'Alpha Man Herbal Formula',
        openingQty: 30,
        inQty: 15,
        outQty: 5,
        closingQty: 40,
        valuationRate: 15000,
        openingValue: 450000,
        inValue: 225000,
        outValue: 75000,
        closingValue: 600000,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
        status: 'Active Custody',
      ),
      StockHolderCustodyEntity(
        id: 'custody-3',
        holderId: 'dc-otk-01',
        holderName: 'Otukpo General Distribution Center',
        holderType: 'General Distribution Center',
        state: 'Benue',
        lga: 'Otukpo',
        city: 'Otukpo Town',
        phone: '+234 807 333 4444',
        productId: 'prod-alpha-001',
        productSku: 'SKU-ALPHA-01',
        productName: 'Alpha Man Herbal Formula',
        openingQty: 15,
        inQty: 10,
        outQty: 5,
        closingQty: 20,
        valuationRate: 15000,
        openingValue: 225000,
        inValue: 150000,
        outValue: 75000,
        closingValue: 300000,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
        status: 'Active Custody',
      ),
      StockHolderCustodyEntity(
        id: 'custody-4',
        holderId: 'pda-rider-7001',
        holderName: 'Emeka Okafor (PDA-7001)',
        holderType: 'PDA / Dispatch Personnel',
        state: 'Abuja (FCT)',
        lga: 'Abuja Municipal (AMAC)',
        city: 'AMAC / Maitama Run',
        phone: '+234 812 345 6789',
        productId: 'prod-alpha-001',
        productSku: 'SKU-ALPHA-01',
        productName: 'Alpha Man Herbal Formula',
        openingQty: 40,
        inQty: 20,
        outQty: 10,
        closingQty: 50,
        valuationRate: 15000,
        openingValue: 600000,
        inValue: 300000,
        outValue: 150000,
        closingValue: 750000,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 45)),
        status: 'Active Custody',
      ),
      StockHolderCustodyEntity(
        id: 'custody-5',
        holderId: 'pda-rider-7002',
        holderName: 'Tunde Balogun (PDA-7002)',
        holderType: 'PDA / Dispatch Personnel',
        state: 'Abuja (FCT)',
        lga: 'Abuja Municipal (AMAC)',
        city: 'Wuse II & Garki Zone',
        phone: '+234 809 988 7766',
        productId: 'prod-alpha-001',
        productSku: 'SKU-ALPHA-01',
        productName: 'Alpha Man Herbal Formula',
        openingQty: 30,
        inQty: 20,
        outQty: 10,
        closingQty: 40,
        valuationRate: 15000,
        openingValue: 450000,
        inValue: 300000,
        outValue: 150000,
        closingValue: 600000,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
        status: 'Active Custody',
      ),
    ];

    test('Total closing quantity matches exactly 250 units for Alpha Man across 3-tier DCs & PDAs', () {
      final totalClosingUnits = mockAlphaManHolders.fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(totalClosingUnits, 250);

      // Verify Grand DC (100) + Hub DC (40) + General DC (20) + PDA Riders (90) = 250
      final grandDcUnits = mockAlphaManHolders
          .where((h) => h.isGrandDc)
          .fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(grandDcUnits, 100);

      final hubDcUnits = mockAlphaManHolders
          .where((h) => h.isHubDc)
          .fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(hubDcUnits, 40);

      final generalDcUnits = mockAlphaManHolders
          .where((h) => h.isGeneralDc)
          .fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(generalDcUnits, 20);

      final pdaUnits = mockAlphaManHolders
          .where((h) => h.isPdaRider)
          .fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(pdaUnits, 90); // 50 + 40

      final allDcUnits = mockAlphaManHolders
          .where((h) => h.isDistributionCenter)
          .fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(allDcUnits, 160); // 100 + 40 + 20

      expect(allDcUnits + pdaUnits, 250);
    });

    test('Valuation calculations: opening and closing values match valuation rate', () {
      for (final holder in mockAlphaManHolders) {
        expect(holder.openingValue, holder.openingQty * holder.valuationRate);
        expect(holder.closingValue, holder.closingQty * holder.valuationRate);
      }

      final totalNetworkValuation = mockAlphaManHolders.fold<double>(0, (double sum, h) => sum + h.closingValue);
      expect(totalNetworkValuation, 250 * 15000.0); // 3,750,000 NGN
    });

    test('Inventory movement reconciliation: opening + in - out == closing', () {
      for (final holder in mockAlphaManHolders) {
        final expectedClosing = holder.openingQty + holder.inQty - holder.outQty;
        expect(holder.closingQty, expectedClosing);
      }
    });

    test('Filter by State: Abuja vs Kaduna vs Benue returns accurate subsets', () {
      final abujaHolders = mockAlphaManHolders.where((h) => h.state == 'Abuja (FCT)').toList();
      expect(abujaHolders.length, 3);
      final abujaUnits = abujaHolders.fold<int>(0, (int sum, h) => sum + h.closingQty);
      expect(abujaUnits, 190); // 100 (Grand DC) + 50 (PDA) + 40 (PDA)

      final kadunaHolders = mockAlphaManHolders.where((h) => h.state == 'Kaduna').toList();
      expect(kadunaHolders.length, 1);
      expect(kadunaHolders.first.closingQty, 40);

      final benueHolders = mockAlphaManHolders.where((h) => h.state == 'Benue').toList();
      expect(benueHolders.length, 1);
      expect(benueHolders.first.closingQty, 20);
    });

    test('Filter by LGA: Abuja Municipal vs Kaduna North vs Otukpo', () {
      final amacHolders = mockAlphaManHolders.where((h) => h.lga == 'Abuja Municipal (AMAC)').toList();
      expect(amacHolders.length, 3);

      final kadunaHolders = mockAlphaManHolders.where((h) => h.lga == 'Kaduna North').toList();
      expect(kadunaHolders.length, 1);
      expect(kadunaHolders.first.holderName, 'Kaduna Hub Distribution Center');

      final otukpoHolders = mockAlphaManHolders.where((h) => h.lga == 'Otukpo').toList();
      expect(otukpoHolders.length, 1);
      expect(otukpoHolders.first.holderName, 'Otukpo General Distribution Center');
    });

    test('Entity JSON serialization and deserialization preserves all fields', () {
      final original = mockAlphaManHolders.first;
      final json = original.toJson();
      final restored = StockHolderCustodyEntity.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.holderId, original.holderId);
      expect(restored.holderName, original.holderName);
      expect(restored.holderType, original.holderType);
      expect(restored.isGrandDc, true);
      expect(restored.isDistributionCenter, true);
      expect(restored.productName, original.productName);
      expect(restored.productSku, original.productSku);
      expect(restored.state, original.state);
      expect(restored.lga, original.lga);
      expect(restored.city, original.city);
      expect(restored.phone, original.phone);
      expect(restored.openingQty, original.openingQty);
      expect(restored.inQty, original.inQty);
      expect(restored.outQty, original.outQty);
      expect(restored.closingQty, original.closingQty);
      expect(restored.valuationRate, original.valuationRate);
      expect(restored.openingValue, original.openingValue);
      expect(restored.closingValue, original.closingValue);
    });
  });
}
