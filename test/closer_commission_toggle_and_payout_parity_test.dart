import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer_payout.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_payout_claim.dart';
import 'package:novexps/features/finance/presentation/pages/payouts_page.dart';

void main() {
  group('Closer Commission Optionality & Payout Parity Tests', () {
    test('ClientCloser initializes with isCommissionEnabled and bank details properly', () {
      // 1. Commission Enabled Closer
      const closerWithComm = ClientCloser(
        id: 'cls-001',
        clientId: 'client-abc',
        closerCode: 'CLS-001',
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        phone: '08012345678',
        commissionRate: 750.0,
        isCommissionEnabled: true,
        bankName: 'OPay',
        accountNumber: '9012345678',
        accountName: 'Jane Doe',
        unpaidCommissionBalance: 15000.0,
        totalPaidCommission: 45000.0,
      );

      expect(closerWithComm.isCommissionEnabled, isTrue);
      expect(closerWithComm.commissionRate, equals(750.0));
      expect(closerWithComm.hasBankDetails, isTrue);
      expect(closerWithComm.unpaidCommissionBalance, equals(15000.0));

      final json = closerWithComm.toJson();
      expect(json['is_commission_enabled'], isTrue);
      expect(json['bank_name'], equals('OPay'));
      expect(json['account_number'], equals('9012345678'));
      expect(json['unpaid_commission_balance'], equals(15000.0));

      final parsed = ClientCloser.fromJson(json);
      expect(parsed.isCommissionEnabled, isTrue);
      expect(parsed.bankName, equals('OPay'));
      expect(parsed.accountNumber, equals('9012345678'));
      expect(parsed.unpaidCommissionBalance, equals(15000.0));

      // 2. Salary / Non-Commission Closer (Toggled OFF)
      const salaryCloser = ClientCloser(
        id: 'cls-002',
        clientId: 'client-abc',
        closerCode: 'CLS-002',
        fullName: 'John Salary',
        email: 'john@example.com',
        phone: '08099887766',
        commissionRate: 0.0,
        isCommissionEnabled: false,
        bankName: '',
        accountNumber: '',
        accountName: '',
        unpaidCommissionBalance: 0.0,
        totalPaidCommission: 0.0,
      );

      expect(salaryCloser.isCommissionEnabled, isFalse);
      expect(salaryCloser.commissionRate, equals(0.0));
      expect(salaryCloser.hasBankDetails, isFalse);
      expect(salaryCloser.unpaidCommissionBalance, equals(0.0));

      final salaryJson = salaryCloser.toJson();
      expect(salaryJson['is_commission_enabled'], isFalse);

      final parsedSalary = ClientCloser.fromJson(salaryJson);
      expect(parsedSalary.isCommissionEnabled, isFalse);
      expect(parsedSalary.commissionRate, equals(0.0));
    });

    test('ClientCloser gracefully defaults isCommissionEnabled to true if missing in legacy DB payload', () {
      final legacyJson = {
        'id': 'cls-legacy',
        'client_id': 'client-001',
        'closer_code': 'CLS-LEG',
        'full_name': 'Legacy Agent',
        'email': 'legacy@example.com',
        'phone': '08000000000',
        'commission_rate': 500.0,
      };

      final parsed = ClientCloser.fromJson(legacyJson);
      expect(parsed.isCommissionEnabled, isTrue);
      expect(parsed.bankName, isEmpty);
      expect(parsed.accountNumber, isEmpty);
      expect(parsed.unpaidCommissionBalance, equals(0.0));
    });

    test('ClientCloserPayout entity serialization and receipt detection', () {
      final payout = ClientCloserPayout(
        id: 'cp-101',
        closerId: 'cls-001',
        clientId: 'client-abc',
        payoutNumber: 'CPAY-20260921-001',
        amount: 25000.0,
        ordersCount: 33,
        orderIds: const ['ord-1', 'ord-2'],
        bankName: 'Moniepoint',
        accountNumber: '8123456789',
        accountName: 'Jane Doe Enterprise',
        disbursementRef: 'BNK-REF-998822',
        proofOfPaymentUrl: 'https://storage.novaxpress.com/receipts/cpay-101.png',
        status: 'remitted',
        createdAt: DateTime(2026, 9, 21, 10, 0),
        updatedAt: DateTime(2026, 9, 21, 10, 30),
      );

      expect(payout.isRemitted, isTrue);
      expect(payout.isCompleted, isFalse);
      expect(payout.hasReceipt, isTrue);
      expect(payout.proofOfPaymentUrl, contains('.png'));

      final json = payout.toJson();
      expect(json['payout_number'], equals('CPAY-20260921-001'));
      expect(json['proof_of_payment_url'], equals('https://storage.novaxpress.com/receipts/cpay-101.png'));

      final parsed = ClientCloserPayout.fromJson(json);
      expect(parsed.id, equals('cp-101'));
      expect(parsed.payoutNumber, equals('CPAY-20260921-001'));
      expect(parsed.amount, equals(25000.0));
      expect(parsed.hasReceipt, isTrue);

      final confirmed = parsed.copyWith(
        status: 'completed',
        confirmedAt: DateTime(2026, 9, 21, 11, 0),
      );
      expect(confirmed.isCompleted, isTrue);
      expect(confirmed.status, equals('completed'));
    });

    test('Rider PayoutRequestItem parses proof_of_payment_url and hasReceipt correctly', () {
      final item = PayoutRequestItem.fromJson({
        'id': 'pr-999',
        'rider_id': 'r-1',
        'amount': 45000.0,
        'status': 'remitted',
        'bank_name': 'Access Bank',
        'account_number': '0123456789',
        'account_name': 'Rider Sunday',
        'disbursement_ref': 'REF-DISB-7744',
        'proof_of_payment_url': 'https://supabase.co/storage/v1/object/public/signatures/payout-pr-999.jpg',
        'created_at': '2026-09-21T09:15:00Z',
      });

      expect(item.id, equals('pr-999'));
      expect(item.amount, equals(45000.0));
      expect(item.hasReceipt, isTrue);
      expect(item.proofOfPaymentUrl, contains('payout-pr-999.jpg'));
    });

    test('DCPayoutClaim entity holds proofOfPaymentUrl and receipt detection', () {
      final claim = DCPayoutClaim(
        id: 'claim-1',
        claimNumber: 'CLM-001',
        riderId: 'rider-01',
        riderName: 'Musa Ibrahim',
        riderCode: 'RD-01',
        requestedAmount: 30000.0,
        currentBalance: 45000.0,
        bankName: 'GTBank',
        accountNumber: '0987654321',
        accountName: 'Musa Ibrahim',
        status: 'disbursed',
        proofOfPaymentUrl: 'https://storage.novaxpress.com/proofs/dc-claim-1.pdf',
        requestedAt: DateTime(2026, 9, 21, 8, 0),
      );

      expect(claim.proofOfPaymentUrl, contains('.pdf'));
      expect(claim.status, equals('disbursed'));
      expect(claim.hasReceipt, isTrue);
    });
  });
}
