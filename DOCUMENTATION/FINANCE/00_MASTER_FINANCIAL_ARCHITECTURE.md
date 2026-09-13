# 00. Master Financial Architecture: NoveXPS Logistics Platform

## 1. Vision & Architectural Scope

The **NoveXPS Financial Subsystem** manages the multi-party flow of funds and inventory value across four principal stakeholders:
1. **The Customer / Recipient**: Pays for goods and delivery either via physical cash (Pay-on-Delivery / COD) or digital direct transfer (Paystack Dedicated Virtual Account / Card / Transfer).
2. **The Delivery Agent / Rider (PDA)**: Collects COD cash, maintains physical cash custody, earns delivery commission and transport allowances, and holds withdrawable earnings ("My Balance") for non-cash orders.
3. **The Distribution Center (DC) & Grand DC Clearinghouse**: Manages local cash vaults, approves rider remittances and payout claims, sets global and merchant-specific billing policies, and executes the **Daily 10:00 PM Merchant Settlement Closeout**.
4. **The Client / Merchant**: Entitled to gross delivered sales revenue minus logistics delivery fees, platform commission charges, payment gateway processing fees, and auxiliary order charges. Tracks both liquid funds held in escrow/vault and in-kind inventory custody valuation.

---

## 2. Core Stakeholder Ledgers & Balances

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           NOVEXPS FINANCIAL QUADRANT                            │
└─────────────────────────────────────────────────────────────────────────────────┘
           ▲                                                   ▲
           │ (1) COD Cash / Paystack                           │ (4) 10 PM Settlement
           ▼                                                   ▼
┌──────────────────────┐                             ┌──────────────────────┐
│  CUSTOMER / RECIPIENT│                             │   CLIENT / MERCHANT  │
└──────────────────────┘                             └──────────────────────┘
           ▲                                                   ▲
           │ POD Completed                                     │ Net Remitted Payout
           ▼                                                   ▼
┌──────────────────────┐   (2) Remit Cash / Direct   ┌──────────────────────┐
│  RIDER / PDA AGENT   │ ──────────────────────────► │  DC TREASURY & VAULT │
│ • current_cod_balance│   (3) Payout Claim          │  (Main Grand DC)     │
│ • direct_transfer_bal│ ◄────────────────────────── │ • Settlement Engine  │
└──────────────────────┘                             └──────────────────────┘
```

### 2.1 Rider Balance Types
- **`current_cod_balance` (Physical Cash Liability)**:
  - **Meaning**: Total cash collected by the rider from customers on Pay-on-Delivery orders, net of rider earnings retained in hand.
  - **Ownership**: The rider **owes** this money to the Distribution Center.
  - **Increment Trigger**: Order marked as `delivered` with `payment_type = 'pay_on_delivery'` and `payment_method = 'cash'`.
  - **Decrement Trigger**: DC supervisor confirms and clears a `cash_remittances` submission, or rider pays DC via instant Paystack remittance transfer.
- **`direct_transfer_balance` ("My Balance" / Withdrawable Asset)**:
  - **Meaning**: Withdrawable earnings (commission + transport allowance) owed by the company to the rider for orders where the customer paid directly to the company (Prepaid, Paystack, Bank Transfer).
  - **Ownership**: The company **owes** this money to the rider.
  - **Increment Trigger**: Order marked as `delivered` with non-cash payment, or order failure allowance credited.
  - **Decrement Trigger**: Rider submits a payout request (`payout_requests`), and the DC supervisor approves the disbursement.

### 2.2 DC Treasury & Vault Balances
- **Physical Cash Vault**: Accumulated cash remitted by riders in person at DC counters, held securely until deposited into the corporate bank account.
- **Digital Paystack Balance**: Cumulative payments received via dynamic virtual accounts for direct transfer orders and instant rider digital remittances.
- **Withdrawable Merchant Escrow**: Sum of collections from delivered orders that have not yet been disbursed to merchants during the 10:00 PM closeout.

### 2.3 Client / Merchant Balances
- **`money_outside` (Field Risk)**: Value of goods currently in transit or out for delivery where payment is pending customer collection.
- **`awaiting_remittance` (Liquid Escrow in Custody)**: Net sales revenue from delivered orders collected by riders or received in Paystack, awaiting the daily 10:00 PM closeout.
- **`remitted_to_bank` (Realized Revenue)**: Cumulative net payouts already disbursed to the merchant's verified settlement bank account.
- **In-Kind Inventory Value**: Estimated monetary worth of physical product stock held in DC warehouses and rider vehicle mini-hubs.

---

## 3. Official System Terminology

To establish unambiguous user experiences across platforms, the following standardized terminology is strictly enforced:

| Subsystem | Feature / Screen | Standardized Label | Description |
| :--- | :--- | :--- | :--- |
| **Main DC Console** | Clearinghouse Module | **"Daily Merchant Settlement (10:00 PM Closeout)"** | The exclusive administrative desk for executing daily batch settlements. |
| **Main DC Console** | Settings Tab | **"Merchant Billing & Order Charges"** | Admin configuration for delivery fees, platform commission, gateway fees, and cut-off rules. |
| **Main DC Console** | Modal Action | **"Execute & Finalize 10:00 PM Settlement Batch"** | 1-click batch generation and order locking button. |
| **Client Portal** | Navigation Tab | **"Daily Settlements & Payouts"** | Primary financial overview and transaction history page for merchants. |
| **Client Portal** | Status Headline | **"10:00 PM Daily Remittance Closeout"** | Prominent status badge indicating the next scheduled settlement window. |
| **Client Portal** | Asset Card | **"Asset Custody & Valuation"** | Dual card displaying Liquid Cash in Escrow vs. In-Kind Inventory Holdings. |
| **Rider / PDA** | Earnings Page | **"My Balance" (Direct Transfer Earnings)** | Rider's withdrawable earnings from company direct transfer orders. |
| **Rider / PDA** | Cash Page | **"Cash in Custody" (COD to Remit)** | Physical cash held by rider that must be remitted to the DC. |

---

## 4. Master Implementation Sequence

```
Phase 1: Database Schema, Indexes & Stored Procedures (01_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md)
   ├── Fix payout_requests table alignment and unique payout_number constraints
   ├── Add failed_stipends_deducted and configurable fee columns
   ├── Implement decrement_driver_entitlement and fn_approve_cash_remittance
   └── Implement fn_generate_merchant_daily_settlement and fn_calculate_merchant_asset_custody

Phase 2: Supabase Edge Functions & Webhooks (02_SUPABASE_EDGE_FUNCTIONS_AND_WEBHOOKS.md)
   ├── Fix submit-cash-remittance auto-reference generation
   ├── Fix request-balance-payout schema alignment
   ├── Fix log-delivery-failure rider allowance credit
   └── Fix paystack-webhook dynamic DC resolution and COD balance clearance

Phase 3: Flutter Data Layer & Providers (03_FLUTTER_DATA_SOURCES_AND_PROVIDERS.md)
   ├── Fix FinanceRemoteDataSourceImpl table targets and parameter mapping
   ├── Fix DCConsoleRemoteDataSourceImpl payout approval and settlement invocation
   ├── Update ClientPortalRemoteDataSourceImpl with itemized settlements and asset breakdown
   └── Fix ClientProductFinanceSummary.calculate delivery fee deductions

Phase 4: Main DC Console Implementation (04_MAIN_DC_CONSOLE_DAILY_10PM_SETTLEMENT_AND_SETTINGS.md)
   ├── Add Merchant Billing & Order Charges tab to DCSettingsPage
   ├── Build DCDailyMerchantSettlementModal with live order selection and charges matrix
   └── Update DCRemittanceDetailModal with atomic COD deduction and zero hardcoding

Phase 5: Client Portal Implementation (05_CLIENT_PORTAL_SETTLEMENTS_AND_ASSET_VALUATION.md)
   ├── Build Asset Custody & Valuation widget (Liquid Cash vs. In-Kind Inventory)
   ├── Add 10:00 PM Daily Closeout countdown banner and itemized deduction breakdown
   └── Enable statement receipt downloads and order audit trail inspection

Phase 6: Comprehensive Testing & Verification (06_TESTING_AND_VERIFICATION_MATRIX.md)
   ├── Automated integration test suite (test/finance_remediation_and_daily_settlement_test.dart)
   ├── Static analysis sweep (flutter analyze lib/)
   └── End-to-end regression validation
```
