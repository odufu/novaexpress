import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/paystack_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paystack Verification Safety & False-Positive Prevention', () {
    test('Unverified transaction reference returns isSuccessful: false', () async {
      final service = PaystackService(
        baseUrl: 'https://non-existent-or-invalid-paystack-endpoint.example.com',
      );

      final result = await service.verifyTransaction('INVALID-OR-UNPAID-REF-9999');

      // Crucial requirement: Must never return isSuccessful: true for unverified references!
      expect(result.isSuccessful, isFalse);
      expect(result.status, equals('unverified'));
      expect(result.gatewayResponse, contains('not yet detected'));
    });

    test('PaystackVerificationResult model accurately holds failure attributes', () {
      final failedResult = PaystackVerificationResult(
        isSuccessful: false,
        reference: 'REF-CANCELLED-123',
        amount: 0.0,
        status: 'unverified',
        gatewayResponse: 'Transaction cancelled by user',
      );

      expect(failedResult.isSuccessful, isFalse);
      expect(failedResult.reference, equals('REF-CANCELLED-123'));
      expect(failedResult.status, equals('unverified'));
      expect(failedResult.gatewayResponse, equals('Transaction cancelled by user'));
    });

    test('Deterministic account generator produces consistent 10-digit NUBANs', () {
      final acc1 = PaystackService.generateDeterministicAccountNumber('ORD-9012');
      final acc2 = PaystackService.generateDeterministicAccountNumber('ORD-9012');
      final accDiff = PaystackService.generateDeterministicAccountNumber('ORD-9013');

      expect(acc1, equals(acc2));
      expect(acc1.length, equals(10));
      expect(acc1.startsWith('99'), isTrue);
      expect(acc1, isNot(equals(accDiff)));
    });
  });
}
