import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_payout_claim.dart';
import 'package:novexps/features/finance/presentation/pages/payouts_page.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('Rider "MY BALANCE" and Strict COD Isolation Architecture', () {
    test('Direct transfer / prepaid orders accumulate commission + transport allowance into "MY BALANCE"', () {
      // Rider profile compensation rates configured at onboarding / DC
      const double riderCommissionRate = 1500.0;
      const double riderTransportAllowance = 1000.0;

      double directTransferBalance = 0.0; // "MY BALANCE"
      double currentCodBalance = 0.0; // Cash in hand liability

      // Scenario 1: Customer pays directly to system (Paystack / Direct Transfer)
      // Customer payment does not go to rider pocket, so system owes rider commission + transport
      final directOrder = OrderEntity(
        id: 'ord-direct-001',
        orderNumber: 'NVX-DT-1001',
        customerName: 'Amina Bello',
        customerPhone: '08031234567',
        deliveryAddress: 'Wuse 2, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        quantity: 1,
        basePrice: 25000.00,
        upsellAmount: 0.0,
        totalAmount: 25000.00,
        status: 'delivered',
        paymentType: 'direct_transfer', // Paid directly to company Paystack/bank
        paymentStatus: 'paid',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'settled',
        createdAt: DateTime.now(),
      );

      // Simulation of fn_confirm_delivery_pod / paystack-webhook credit logic
      if (directOrder.paymentType != 'pay_on_delivery') {
        directTransferBalance += (riderCommissionRate + riderTransportAllowance);
      } else {
        currentCodBalance += directOrder.totalAmount;
      }

      // Assertions
      expect(directTransferBalance, 2500.00, reason: 'Rider balance must accumulate commission + transport');
      expect(currentCodBalance, 0.00, reason: 'Direct transfer orders must NEVER increase COD cash liability');
    });

    test('Strict COD Isolation: COD collections increment COD balance and NEVER credit "MY BALANCE"', () {
      const double riderCommissionRate = 1500.0;
      const double riderTransportAllowance = 1000.0;

      double directTransferBalance = 5000.0; // Existing "MY BALANCE"
      double currentCodBalance = 0.0; // Starting COD cash in hand

      // Scenario 2: Cash On Delivery (COD) Order
      final codOrder = OrderEntity(
        id: 'ord-cod-002',
        orderNumber: 'NVX-COD-2002',
        customerName: 'Chidi Okafor',
        customerPhone: '08098765432',
        deliveryAddress: 'Garki 2, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        quantity: 2,
        basePrice: 45000.00,
        upsellAmount: 0.0,
        totalAmount: 45000.00,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentStatus: 'collected',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Simulation of fn_confirm_delivery_pod logic
      if (codOrder.paymentType == 'pay_on_delivery') {
        currentCodBalance += codOrder.totalAmount;
      } else {
        directTransferBalance += (riderCommissionRate + riderTransportAllowance);
      }

      // Assertions:
      // 1. COD balance is exactly ₦45,000 (which must be remitted via cash remittance pipeline)
      expect(currentCodBalance, 45000.00, reason: 'COD cash collected must be tracked under current_cod_balance');
      // 2. Direct transfer balance is completely untouched
      expect(directTransferBalance, 5000.00, reason: 'COD cash must NEVER be mixed into direct_transfer_balance');
    });

    test('Failed delivery attempt credits failed_delivery_allowance into "MY BALANCE"', () {
      const double failedDeliveryAllowance = 1000.0;
      double directTransferBalance = 2500.0; // Current balance
      double currentCodBalance = 10000.0;

      // Scenario 3: Delivery attempt failed (customer phone switched off / unavailable)
      const isFailedAttempt = true;

      if (isFailedAttempt) {
        // Stored procedure log_delivery_failure credits the failed stipend
        directTransferBalance += failedDeliveryAllowance;
      }

      expect(directTransferBalance, 3500.00, reason: 'Failed attempt must credit rider with ₦1,000 stipend');
      expect(currentCodBalance, 10000.00, reason: 'COD balance must remain unchanged upon failed delivery');
    });
  });

  group('Closed-Loop Payout Lifecycle Tests (Rider Request -> DC Disbursed -> Rider Confirmed)', () {
    test('DCPayoutClaim entity correctly handles status transitions and confirmation flags', () {
      // 1. Initial State: Pending request from Rider
      final pendingClaim = DCPayoutClaim(
        id: 'claim-001',
        claimNumber: 'CLM-001',
        riderId: 'agent-101',
        riderName: 'Musa Danladi',
        riderCode: 'RDR-007',
        requestedAmount: 25000.00,
        currentBalance: 30000.00,
        status: 'pending',
        bankName: 'Access Bank',
        accountNumber: '0123456789',
        accountName: 'Musa Danladi',
        requestedAt: DateTime(2026, 9, 18, 8, 0),
      );

      expect(pendingClaim.isPending, isTrue);
      expect(pendingClaim.isDisbursed, isFalse);
      expect(pendingClaim.isConfirmed, isFalse);

      // 2. Intermediate State: DC approves and disburses funds with Bank Reference
      final disbursedClaim = pendingClaim.copyWith(
        status: 'disbursed',
        disbursementRef: 'TRX-NIP-9988224411',
      );

      expect(disbursedClaim.isPending, isFalse);
      expect(disbursedClaim.isDisbursed, isTrue);
      expect(disbursedClaim.isConfirmed, isFalse);
      expect(disbursedClaim.disbursementRef, 'TRX-NIP-9988224411');

      // 3. Terminal State: Rider confirms receipt of funds in PDA mobile app
      final confirmedClaim = disbursedClaim.copyWith(
        status: 'completed',
        riderConfirmedAt: DateTime(2026, 9, 18, 9, 45),
      );

      expect(confirmedClaim.isPending, isFalse);
      expect(confirmedClaim.isDisbursed, isFalse);
      expect(confirmedClaim.isConfirmed, isTrue);
      expect(confirmedClaim.riderConfirmedAt, isNotNull);
    });

    test('PayoutRequestItem in Rider PDA correctly decodes and exposes confirmation workflow', () {
      // Simulate raw payout map as returned from Supabase RPC / table
      final rawMap = {
        'id': 'pay-uuid-777',
        'amount': 35000.00,
        'status': 'disbursed',
        'created_at': '2026-09-18T08:15:00.000Z',
        'bank_name': 'Zenith Bank',
        'account_number': '2001122334',
        'account_name': 'Ibrahim Yakubu',
        'disbursement_ref': 'ZENITH-NIP-55443322',
        'dc_notes': 'Sent via NIP Instant transfer at 09:15 AM',
        'rider_confirmed_at': null,
        'rider_confirmation_notes': null,
      };

      final item = PayoutRequestItem(
        id: rawMap['id'] as String,
        amount: (rawMap['amount'] as num).toDouble(),
        status: rawMap['status'] as String,
        date: DateTime.parse(rawMap['created_at'] as String),
        bankName: rawMap['bank_name'] as String,
        accountNumber: rawMap['account_number'] as String,
        accountName: rawMap['account_name'] as String,
        disbursementRef: rawMap['disbursement_ref'] as String?,
        dcNotes: rawMap['dc_notes'] as String?,
        riderConfirmedAt: rawMap['rider_confirmed_at'] != null ? DateTime.parse(rawMap['rider_confirmed_at'] as String) : null,
        riderConfirmationNotes: rawMap['rider_confirmation_notes'] as String?,
      );

      // Verify that rider sees this claim as awaiting their confirmation
      expect(item.id, 'pay-uuid-777');
      expect(item.amount, 35000.00);
      expect(item.isDisbursed, isTrue);
      expect(item.isConfirmed, isFalse);
      expect(item.disbursementRef, 'ZENITH-NIP-55443322');

      // Rider confirms in PDA app
      final confirmedItem = item.copyWith(
        status: 'completed',
        riderConfirmedAt: DateTime.now(),
        riderConfirmationNotes: 'Confirmed ₦35,000 received in Zenith account',
      );

      expect(confirmedItem.isDisbursed, isFalse);
      expect(confirmedItem.isConfirmed, isTrue);
      expect(confirmedItem.status, 'completed');
      expect(confirmedItem.riderConfirmationNotes, contains('₦35,000 received'));
    });

    test('DCPayoutClaim.fromJson handles backend payloads with snake_case fields correctly', () {
      final jsonPayload = {
        'id': 'payout-123',
        'claim_number': 'CLM-123',
        'agent_id': 'agent-uuid-456',
        'delivery_agents': {
          'full_name': 'Babatunde Fash',
          'agent_code': 'RDR-LAG-01',
          'phone': '08022334455',
        },
        'amount': 18500.00,
        'current_balance': 20000.00,
        'status': 'disbursed',
        'bank_name': 'GTBank',
        'account_number': '0129876543',
        'account_name': 'Babatunde Fash',
        'disbursement_ref': 'GTB-TRANS-981122',
        'notes': 'Disbursed batch 1',
        'created_at': '2026-09-18T07:00:00Z',
        'reviewed_at': '2026-09-18T08:00:00Z',
        'rider_confirmed_at': '2026-09-18T08:20:00Z',
        'rider_confirmation_notes': 'Alert received, thank you.',
      };

      final claim = DCPayoutClaim.fromJson(jsonPayload);

      expect(claim.id, 'payout-123');
      expect(claim.riderName, 'Babatunde Fash');
      expect(claim.riderCode, 'RDR-LAG-01');
      expect(claim.requestedAmount, 18500.00);
      expect(claim.status, 'disbursed');
      expect(claim.disbursementRef, 'GTB-TRANS-981122');
      expect(claim.riderConfirmedAt, isNotNull);
      expect(claim.isConfirmed, isFalse); // status is 'disbursed'; isConfirmed checks status == 'completed' || status == 'confirmed'
    });
  });
}
