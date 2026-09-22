import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';

void main() {
  group('Manual Client Settlement & Receipt Attachment Flow', () {
    test('ClientSettlement getters correctly identify remitted status and receipt attachment', () {
      final settlement = ClientSettlement(
        id: 'settle-001',
        settlementNumber: 'SETTLE-20260920-001',
        clientId: 'client-123',
        companyId: 'company-abc',
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 9, 20),
        totalOrdersCount: 5,
        grossCollections: 150000.0,
        logisticsFeesDeducted: 25000.0,
        platformFeesDeducted: 3750.0,
        gatewayFeesDeducted: 2250.0,
        failedAttemptFeesDeducted: 1000.0,
        otherChargesDeducted: 500.0,
        netPayoutAmount: 117500.0,
        destinationBankName: 'Access Bank',
        destinationAccountNumber: '0123456789',
        destinationAccountName: 'Novacare Health Ltd',
        payoutReference: 'TRF/ACCESS/20260920/9981',
        proofOfPaymentUrl: 'https://example.com/storage/proof_of_payment_001.pdf',
        status: 'remitted',
        notes: 'Manual Bank Transfer Settlement Fulfilled by Central DC',
        chargesBreakdown: {
          'gross_collections': 150000.0,
          'total_deductions': 32500.0,
          'net_payout': 117500.0,
        },
        settledAt: DateTime(2026, 9, 20, 14, 30),
        createdAt: DateTime(2026, 9, 20, 14, 0),
      );

      // Verify status predicates
      expect(settlement.isRemitted, isTrue);
      expect(settlement.isCompleted, isFalse);
      expect(settlement.hasReceipt, isTrue);
      expect(settlement.proofOfPaymentUrl, contains('.pdf'));
      expect(settlement.payoutReference, equals('TRF/ACCESS/20260920/9981'));
      expect(settlement.netPayoutAmount, equals(117500.0));
    });

    test('ClientSettlement copyWith seamlessly approves and marks settlement completed', () {
      final remitted = ClientSettlement(
        id: 'settle-002',
        settlementNumber: 'SETTLE-20260920-002',
        clientId: 'client-456',
        companyId: 'company-abc',
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 9, 20),
        totalOrdersCount: 2,
        grossCollections: 60000.0,
        logisticsFeesDeducted: 10000.0,
        netPayoutAmount: 50000.0,
        destinationBankName: 'Zenith Bank',
        destinationAccountNumber: '2001122334',
        destinationAccountName: 'Apex Logistics',
        payoutReference: 'ZENITH-NIP-5544',
        proofOfPaymentUrl: 'https://example.com/receipt.png',
        status: 'remitted',
        settledAt: DateTime(2026, 9, 20, 10, 0),
        createdAt: DateTime(2026, 9, 20, 9, 30),
      );

      expect(remitted.isRemitted, isTrue);
      expect(remitted.isCompleted, isFalse);

      // Merchant approves settlement payout
      final approved = remitted.copyWith(
        status: 'completed',
        notes: 'Merchant Approved & Confirmed by Dr. Chuka',
      );

      expect(approved.isCompleted, isTrue);
      expect(approved.isRemitted, isFalse);
      expect(approved.hasReceipt, isTrue);
      expect(approved.notes, contains('Merchant Approved & Confirmed'));
      expect(approved.settlementNumber, equals('SETTLE-20260920-002'));
    });

    test('ClientSettlement JSON serialization and deserialization preserves all proof fields', () {
      final jsonMap = {
        'id': 'settle-003',
        'settlement_number': 'SETTLE-20260920-003',
        'client_id': 'client-789',
        'company_id': 'company-xyz',
        'period_start': '2026-09-01T00:00:00.000Z',
        'period_end': '2026-09-20T23:59:59.000Z',
        'total_orders_count': 10,
        'gross_collections': 300000.0,
        'logistics_fees_deducted': 50000.0,
        'platform_fees_deducted': 7500.0,
        'gateway_fees_deducted': 4500.0,
        'failed_attempt_fees_deducted': 2000.0,
        'other_charges_deducted': 1000.0,
        'net_payout_amount': 235000.0,
        'destination_bank_name': 'GTBank',
        'destination_account_number': '0144556677',
        'destination_account_name': 'Novacare Pharmacy',
        'payout_reference': 'GTB/NIP/2026/0920/1234',
        'proof_of_payment_url': 'https://qpcafevjsrbauweuiiyq.supabase.co/storage/v1/object/public/proof_of_delivery/receipt.pdf',
        'status': 'remitted',
        'notes': 'Manual Bank Transfer Fulfilled by Central DC',
        'charges_breakdown': {'delivery_fees': 50000.0},
        'settled_at': '2026-09-20T16:00:00.000Z',
      };

      final deserialized = ClientSettlement.fromJson(jsonMap);

      expect(deserialized.id, equals('settle-003'));
      expect(deserialized.proofOfPaymentUrl, equals(jsonMap['proof_of_payment_url']));
      expect(deserialized.payoutReference, equals('GTB/NIP/2026/0920/1234'));
      expect(deserialized.isRemitted, isTrue);
      expect(deserialized.hasReceipt, isTrue);
      expect(deserialized.destinationAccountNumber, equals('0144556677'));

      final serialized = deserialized.toJson();
      expect(serialized['proof_of_payment_url'], equals(jsonMap['proof_of_payment_url']));
      expect(serialized['payout_reference'], equals('GTB/NIP/2026/0920/1234'));
      expect(serialized['status'], equals('remitted'));
    });
  });
}
