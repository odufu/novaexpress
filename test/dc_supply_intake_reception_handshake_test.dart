import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_stock_invoice.dart';
import 'package:novexps/features/stock/domain/entities/stock_transfer_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Industrial DC Supply Intake Invoicing & Reception Handshake Suite', () {
    test('1. ClientStockInvoice correctly models en-route in_transit lifecycle', () {
      final invoice = ClientStockInvoice(
        id: 'inv-test-001',
        clientId: 'client-novacare-001',
        invoiceNumber: 'INV-2026-INTAKE-001',
        supplierName: 'GreenLeaf Herbals Ltd',
        destinationWarehouse: 'Central Abuja Hub (Grand DC)',
        entryDate: DateTime(2026, 9, 20),
        status: 'in_transit',
        paymentStatus: 'unpaid',
        totalUnits: 500,
        subtotalRawProductCost: 750000.0,
        totalPackagingCost: 125000.0,
        totalTransportationCost: 75000.0,
        totalHandlingClearingCost: 25000.0,
        grandTotalLandedCost: 975000.0,
        waybillNumber: 'WB-INTAKE-20260920-0042',
        createdAt: DateTime(2026, 9, 20),
      );

      // Verifications for en-route state
      expect(invoice.isAwaitingInspection, isTrue);
      expect(invoice.isVerified, isFalse);
      expect(invoice.hasDiscrepancy, isFalse);
      expect(invoice.isProcessed, isFalse);
      expect(invoice.waybillNumber, equals('WB-INTAKE-20260920-0042'));
    });

    test('2. ClientStockInvoice verified reception handshake transitions cleanly', () {
      final verifiedInvoice = ClientStockInvoice(
        id: 'inv-test-002',
        clientId: 'client-novacare-001',
        invoiceNumber: 'INV-2026-INTAKE-002',
        supplierName: 'GreenLeaf Herbals Ltd',
        destinationWarehouse: 'Central Abuja Hub (Grand DC)',
        entryDate: DateTime(2026, 9, 20),
        status: 'verified',
        paymentStatus: 'paid',
        totalUnits: 500,
        verifiedUnits: 500,
        damagedUnits: 0,
        missingUnits: 0,
        verifiedBy: 'Suleiman Garba (DC Lead)',
        verifiedAt: DateTime(2026, 9, 21, 10, 30),
        handshakeNotes: 'All 500 units inspected and in pristine condition.',
        createdAt: DateTime(2026, 9, 20),
      );

      expect(verifiedInvoice.isVerified, isTrue);
      expect(verifiedInvoice.isAwaitingInspection, isFalse);
      expect(verifiedInvoice.hasDiscrepancy, isFalse);
      expect(verifiedInvoice.isProcessed, isTrue);
      expect(verifiedInvoice.verifiedUnits, equals(500));
      expect(verifiedInvoice.verifiedBy, contains('Suleiman Garba'));
    });

    test('3. ClientStockInvoice flags damaged and missing unit discrepancies', () {
      final discrepancyInvoice = ClientStockInvoice(
        id: 'inv-test-003',
        clientId: 'client-novacare-001',
        invoiceNumber: 'INV-2026-INTAKE-003',
        supplierName: 'GreenLeaf Herbals Ltd',
        destinationWarehouse: 'Central Abuja Hub (Grand DC)',
        entryDate: DateTime(2026, 9, 20),
        status: 'discrepancy',
        totalUnits: 1000,
        verifiedUnits: 920,
        damagedUnits: 50,
        missingUnits: 30,
        verifiedBy: 'Fatima Bello (QA Supervisor)',
        verifiedAt: DateTime(2026, 9, 21, 14, 0),
        handshakeNotes: '50 cartons damaged by rain leak during transit; 30 units short on pallet B.',
        createdAt: DateTime(2026, 9, 20),
      );

      expect(discrepancyInvoice.hasDiscrepancy, isTrue);
      expect(discrepancyInvoice.isVerified, isFalse);
      expect(discrepancyInvoice.isProcessed, isTrue);
      expect(discrepancyInvoice.damagedUnits, equals(50));
      expect(discrepancyInvoice.missingUnits, equals(30));
      expect(discrepancyInvoice.verifiedUnits, equals(920));
      expect(discrepancyInvoice.handshakeNotes, contains('damaged by rain leak'));
    });

    test('4. StockTransferRecord encapsulates industrial carrier & dock verification metadata', () {
      final transfer = StockTransferRecord(
        id: 'trf-handshake-001',
        transferNumber: 'TRF-INTAKE-9872',
        transferType: 'client_supply',
        status: 'in_transit',
        carrierDriverName: 'Musa Ibrahim',
        carrierPhone: '+2348031234567',
        carrierLicensePlate: 'KJA-452-XY',
        destinationBin: 'Bay 3 - Bulk Pallet Rack C',
        waybillSlipUrl: 'https://cdn.novexps.com/slips/wb-9872.pdf',
        verifiedUnits: 450,
        damagedUnits: 10,
        missingUnits: 40,
        hasDiscrepancy: true,
        discrepancyNotes: 'Pallet shrink wrap torn, 10 bottles fractured',
        createdAt: DateTime(2026, 9, 21),
        items: const [
          StockTransferItemRecord(
            id: 'item-001',
            transferId: 'trf-handshake-001',
            productId: '00000000-0000-4000-8000-000000000001',
            productName: 'Ura CLear Detox Tea',
            sku: 'SKU-DETOX-01',
            quantity: 500,
            quantityReceived: 450,
            quantityDamaged: 10,
            quantityMissing: 40,
            itemNotes: '10 broken caps; 40 units shortage from manufacturer pack.',
          ),
        ],
      );

      // Verify domain logic
      expect(transfer.isClientSupply, isTrue);
      expect(transfer.isInterDc, isFalse);
      expect(transfer.isPendingReception, isTrue);
      expect(transfer.carrierDriverName, equals('Musa Ibrahim'));
      expect(transfer.carrierLicensePlate, equals('KJA-452-XY'));
      expect(transfer.destinationBin, equals('Bay 3 - Bulk Pallet Rack C'));
      expect(transfer.totalQuantityRequested, equals(500));
      expect(transfer.totalQuantityReceived, equals(450));
      expect(transfer.totalQuantityDamaged, equals(10));
      expect(transfer.totalQuantityMissing, equals(40));
      expect(transfer.hasDiscrepancy, isTrue);

      // JSON Serialization Round-trip
      final json = transfer.toJson();
      expect(json['carrier_driver_name'], equals('Musa Ibrahim'));
      expect(json['carrier_license_plate'], equals('KJA-452-XY'));
      expect(json['destination_bin'], equals('Bay 3 - Bulk Pallet Rack C'));
      expect(json['verified_units'], equals(450));
      expect(json['damaged_units'], equals(10));
      expect(json['missing_units'], equals(40));
      expect(json['has_discrepancy'], isTrue);

      final restored = StockTransferRecord.fromJson(json);
      expect(restored.carrierDriverName, equals(transfer.carrierDriverName));
      expect(restored.carrierLicensePlate, equals(transfer.carrierLicensePlate));
      expect(restored.destinationBin, equals(transfer.destinationBin));
      expect(restored.verifiedUnits, equals(transfer.verifiedUnits));
      expect(restored.damagedUnits, equals(transfer.damagedUnits));
      expect(restored.missingUnits, equals(transfer.missingUnits));
      expect(restored.hasDiscrepancy, equals(transfer.hasDiscrepancy));
    });

    test('5. Inter-DC transfers correctly participate in reception handshake queue', () {
      final interDcTransfer = StockTransferRecord(
        id: 'trf-inter-dc-001',
        transferNumber: 'TRF-IDC-2026-0081',
        transferType: 'inter_dc',
        status: 'pending_destination_acceptance',
        sourceWarehouseName: 'Lagos Main Gateway DC',
        destinationWarehouseName: 'Central Abuja Hub (Grand DC)',
        carrierDriverName: 'Emeka Okafor',
        carrierPhone: '+2348029988776',
        carrierLicensePlate: 'LAG-889-AB',
        createdAt: DateTime(2026, 9, 22),
        items: const [
          StockTransferItemRecord(
            id: 'item-002',
            transferId: 'trf-inter-dc-001',
            productId: '00000000-0000-4000-8000-000000000002',
            productName: 'Alpha Man Booster',
            sku: 'SKU-ALPHA-02',
            quantity: 300,
            quantityReceived: 0,
          ),
        ],
      );

      expect(interDcTransfer.isInterDc, isTrue);
      expect(interDcTransfer.isClientSupply, isFalse);
      expect(interDcTransfer.isPendingDestinationAcceptance, isTrue);
      expect(interDcTransfer.totalQuantityRequested, equals(300));
      expect(interDcTransfer.totalQuantityReceived, equals(0));
    });
  });
}
