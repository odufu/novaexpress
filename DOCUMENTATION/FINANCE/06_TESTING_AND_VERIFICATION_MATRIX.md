# 06. Testing, Verification Matrix & Regression Suite

## 1. Quality Assurance Philosophy & Verification Gates

Financial correctness requires zero tolerance for runtime exceptions, race conditions, or unhandled data states. Every change across the 4 tiers (Database, Edge Functions, Flutter Data Layer, and Presentation UI) must pass through strict automated verification gates prior to deployment:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       FINANCIAL VERIFICATION GATES                          │
└─────────────────────────────────────────────────────────────────────────────┘
  Gate 1: PostgreSQL Schema & PL/pgSQL Atomic Function Test (DB Push & SQL RPC)
     ▼
  Gate 2: Edge Function TypeScript Typecheck & Webhook Ingestion Tests
     ▼
  Gate 3: Flutter Unit & Integration Test Suite (test/finance_..._test.dart)
     ▼
  Gate 4: Static Code Analysis Sweep (flutter analyze lib/)
     ▼
  Gate 5: End-to-End Manual Scenario Validation (Interactive Flows)
```

---

## 2. Automated Test Suite: `test/finance_remediation_and_daily_settlement_test.dart`

### 2.1 File Location
`test/finance_remediation_and_daily_settlement_test.dart`

### 2.2 Complete Test Suite Source Code

```dart
// test/finance_remediation_and_daily_settlement_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:nove_xps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:nove_xps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:nove_xps/features/orders/domain/entities/order.dart';

void main() {
  group('Finance Architecture Remediation & Settlement Tests', () {
    test('ClientSettlement model deserializes all itemized charges without null-pointer errors', () {
      final sampleJson = {
        'id': 'settle-uuid-001',
        'settlement_number': 'SETTLE-2026-09-13-1001',
        'client_id': 'client-uuid-001',
        'company_id': '11111111-1111-4111-8111-111111111111',
        'distribution_center_id': 'dc-uuid-001',
        'period_start': '2026-09-12T22:00:00.000Z',
        'period_end': '2026-09-13T22:00:00.000Z',
        'total_orders_count': 10,
        'gross_collections': 250000.00,
        'logistics_fees_deducted': 35000.00,
        'platform_fees_deducted': 5000.00,
        'gateway_fees_deducted': 1875.00,
        'failed_attempt_fees_deducted': 1000.00,
        'other_charges_deducted': 0.00,
        'net_payout_amount': 207125.00,
        'charges_breakdown': {
          'base_delivery_fee': 3500.0,
          'platform_rate': 'flat_500',
          'gateway_rate': '1.5%_capped',
        },
        'destination_bank_name': 'Access Bank',
        'destination_account_number': '0123456789',
        'destination_account_name': 'Acme Stores Enterprise',
        'payout_reference': 'TRX-PAYOUT-998822',
        'status': 'completed',
        'settled_at': '2026-09-13T22:05:00.000Z',
        'created_at': '2026-09-13T22:05:00.000Z',
      };

      final settlement = ClientSettlement.fromJson(sampleJson);

      expect(settlement.settlementNumber, 'SETTLE-2026-09-13-1001');
      expect(settlement.grossCollections, 250000.00);
      expect(settlement.logisticsFeesDeducted, 35000.00);
      expect(settlement.platformFeesDeducted, 5000.00);
      expect(settlement.gatewayFeesDeducted, 1875.00);
      expect(settlement.failedAttemptFeesDeducted, 1000.00);
      expect(settlement.netPayoutAmount, 207125.00);
      expect(settlement.chargesBreakdown['platform_rate'], 'flat_500');
    });

    test('ClientProductFinanceSummary.calculate correctly deducts delivery fees for prepaid direct orders', () {
      final order1 = OrderEntity(
        id: 'ord-1',
        orderNumber: 'NVX-001',
        customerName: 'Customer A',
        customerPhone: '08011111111',
        deliveryAddress: 'Lekki Phase 1',
        deliveryCity: 'Lekki',
        deliveryState: 'Lagos',
        totalAmount: 30000.00,
        status: 'delivered',
        paymentType: 'prepaid',
        paymentMethod: 'paystack',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final order2 = OrderEntity(
        id: 'ord-2',
        orderNumber: 'NVX-002',
        customerName: 'Customer B',
        customerPhone: '08022222222',
        deliveryAddress: 'Ikeja GRA',
        deliveryCity: 'Ikeja',
        deliveryState: 'Lagos',
        totalAmount: 20000.00,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentMethod: 'cash',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final summary = ClientProductFinanceSummary.calculate(orders: [order1, order2]);

      expect(summary.totalOrders, 2);
      expect(summary.deliveredOrders, 2);
      expect(summary.grossDeliveredValue, 50000.00);
      expect(summary.logisticsDeliveryFees, 7000.00);

      // Total net realized revenue = 50,000 - 7,000 = 43,000
      expect(summary.netRealizedRevenue, 43000.00);

      // Both orders are un-remitted awaiting 10 PM closeout:
      // ord-1 net = 30,000 - 3,500 = 26,500
      // ord-2 net = 20,000 - 3,500 = 16,500
      // Total awaiting remittance = 43,000
      expect(summary.awaitingRemittance, 43000.00);
      expect(summary.remittedToBank, 0.00);
    });

    test('ClientProductFinanceSummary.calculate accurately moves settled orders to remittedToBank', () {
      final order = OrderEntity(
        id: 'ord-settled-1',
        orderNumber: 'NVX-003',
        customerName: 'Customer C',
        customerPhone: '08033333333',
        deliveryAddress: 'Victoria Island',
        deliveryCity: 'Lagos',
        deliveryState: 'Lagos',
        totalAmount: 40000.00,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentMethod: 'cash',
        clientDeliveryFee: 3500.00,
        remittanceStatus: 'remitted',
        financialSettlementStatus: 'client_settled',
        createdAt: DateTime.now(),
      );

      final summary = ClientProductFinanceSummary.calculate(orders: [order]);

      expect(summary.deliveredOrders, 1);
      expect(summary.awaitingRemittance, 0.00);
      expect(summary.remittedToBank, 36500.00); // 40,000 - 3,500
      expect(summary.logisticsDeliveryFees, 3500.00);
    });
  });
}
```

---

## 3. Comprehensive Verification Matrix

| Area | Component | Verification Command / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **Database** | Migration Push | `npx supabase db push` | Migration `20260913190000_...sql` applied without conflict. | Zero DDL errors, all columns & indexes present. |
| **Database** | Stored Procedures | Execute test SQL in Supabase Studio / CLI: `SELECT decrement_driver_entitlement(...)` | Decrements rider `direct_transfer_balance` safely with `GREATEST(0, balance - amount)`. | Balance updated without negative numbers. |
| **Database** | Remittance Clearance | `SELECT fn_approve_cash_remittance(...)` | Decrements rider `current_cod_balance`, updates remittance to `verified`, orders to `remitted`. | Atomic update verified in `delivery_agents` & `orders`. |
| **Database** | Daily 10 PM Settlement | `SELECT fn_generate_merchant_daily_settlement(...)` | Creates `client_settlements` row, itemizes fees, locks orders with `financial_settlement_status = 'client_settled'`. | Settlement record generated with unique sequence number. |
| **Database** | Asset Custody RPC | `SELECT fn_calculate_merchant_asset_custody(...)` | Returns liquid cash (vault + Paystack) and dual inventory values (base liquidation vs estimated retail). | JSON output contains both valuation fields. |
| **Edge Functions** | Cash Remittance | `npx supabase functions deploy submit-cash-remittance` | Edge function builds and passes TypeScript compile without type errors. | Deployed to production project. |
| **Edge Functions** | Balance Payout | `npx supabase functions deploy request-balance-payout` | Targets `payout_requests` with `payout_number`, validates balance sufficiency. | Returns HTTP 201 with generated payout number. |
| **Edge Functions** | Paystack Webhook | `npx supabase functions deploy paystack-webhook` | Resolves rider DC dynamically, updates order to `collected`, decrements COD debt if remittance. | Webhook returns HTTP 200 within 500ms. |
| **Flutter Data** | Payout Target Table | Code inspection of `FinanceRemoteDataSourceImpl` | Points to `payout_requests`, passes `payout_number`, handles exceptions without dummy fallback masks. | Code clean, no references to `payout_claims`. |
| **Flutter Models** | `ClientSettlement` | Run unit test suite: `flutter test test/finance_remediation_and_daily_settlement_test.dart` | All unit tests pass. | 100% tests green. |
| **Flutter Analysis** | Static Analysis Sweep | `flutter analyze lib/` | Zero static analyzer errors or broken dependencies. | 0 errors. |
| **DC Console UI** | Merchant Billing Tab | Navigate to `DCSettingsPage` -> Tab 4 | Displays editable fields for delivery fees, platform fees, gateway splits, and 10 PM cutoff. | Saves cleanly to `dc_finance_settings`. |
| **DC Console UI** | 10 PM Closeout Modal | Launch `DCDailyMerchantSettlementModal` | Shows eligible orders checklist, dynamic charge deductions, and 1-click batch finalization. | Creates settlement and locks orders in database. |
| **Client Portal UI**| Settlement & Custody | Navigate to `ClientFinancePage` | Displays 10:00 PM closeout countdown banner, Asset Custody dual card, and itemized deduction batches. | Live figures match database state. |

---

## 4. Execution Sequence

```bash
# Step 1: Push database migrations & stored procedures
npx supabase db push

# Step 2: Deploy updated Edge Functions
npx supabase functions deploy submit-cash-remittance
npx supabase functions deploy request-balance-payout
npx supabase functions deploy log-delivery-failure
npx supabase functions deploy paystack-webhook
npx supabase functions deploy generate-daily-settlements

# Step 3: Run Flutter Automated Test Suite
flutter test test/finance_remediation_and_daily_settlement_test.dart

# Step 4: Run Static Analysis Sweep
flutter analyze lib/
```
