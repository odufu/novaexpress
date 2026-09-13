# 02. Supabase Edge Functions & Webhooks Specification

## 1. Overview

Edge Functions in NoveXPS run in isolated Deno runtimes to execute sensitive financial transactions, cryptographic webhook validation, and backend background tasks.

Directory: `supabase/functions/`

---

## 2. Function Specifications & Required Edits

### 2.1 `submit-cash-remittance` (`supabase/functions/submit-cash-remittance/index.ts`)
- **Current Defect**: Fails to generate `reference_number`, violating PostgreSQL `UNIQUE NOT NULL` constraint on `cash_remittances`. Uses hardcoded fallback company UUID.
- **Required Implementation**:
  - Automatically generate a unique `reference_number` formatted as `RMT-YYYYMMDD-XXXX` if not supplied.
  - Dynamically resolve `distribution_center_id` from the delivery agent's profile.
  - Accept and store `failed_stipends_deducted` and `pos_fee`.
  - Handle associated orders in `remittance_orders` table.

```typescript
// Core Insertion Snippet
const refNumber = payload.referenceNumber || `RMT-${Date.now().toString().slice(-8)}`;

// Resolve Agent DC
const { data: agent } = await supabaseClient
  .from("delivery_agents")
  .select("distribution_center_id, company_id")
  .eq("id", payload.agentId)
  .single();

const { data: newRemittance, error: insertError } = await supabaseClient
  .from("cash_remittances")
  .insert({
    company_id: agent?.company_id || payload.companyId || "11111111-1111-4111-8111-111111111111",
    delivery_agent_id: payload.agentId,
    distribution_center_id: agent?.distribution_center_id || null,
    reference_number: refNumber,
    amount: payload.amount,
    payment_method: payload.paymentMethod,
    deposit_receipt_url: payload.depositReceiptUrl || null,
    status: "pending",
    notes: `[${payload.paymentMethod.toUpperCase()}] Ref: ${refNumber} - ${payload.notes || ""}`,
    created_at: new Date().toISOString(),
  })
  .select()
  .single();
```

---

### 2.2 `request-balance-payout` (`supabase/functions/request-balance-payout/index.ts`)
- **Current Defect**: Relies on random 4-digit numbers for `payout_number` which can trigger collision errors on `UNIQUE NOT NULL` constraint.
- **Required Implementation**:
  - Generate high-entropy, timestamped `payout_number`: `PAY-${Date.now()}`.
  - Check `delivery_agents.direct_transfer_balance` strictly against requested amount.
  - Insert into authoritative `payout_requests` table with status `'pending'`.
  - Insert debit audit transaction into `rider_transactions` with status `'pending'`.

```typescript
const payoutNumber = `PAY-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;

const { data: payout, error: payoutError } = await supabaseClient
  .from("payout_requests")
  .insert({
    payout_number: payoutNumber,
    delivery_agent_id: payload.agentId,
    amount: payload.amount,
    bank_name: payload.bankName,
    account_number: payload.accountNumber,
    account_name: payload.accountName,
    status: "pending",
    dc_notes: payload.notes || "Requested via PDA App",
    created_at: new Date().toISOString(),
  })
  .select()
  .single();
```

---

### 2.3 `log-delivery-failure` (`supabase/functions/log-delivery-failure/index.ts`)
- **Current Defect**: Updates order status to `cancelled` or `call_back` but never credits the rider's `failed_delivery_allowance` (₦500).
- **Required Implementation**:
  - Retrieve the agent's configured `failed_delivery_allowance` or fallback to `dc_finance_settings.default_failed_delivery_allowance` (₦500.00).
  - Increment `delivery_agents.direct_transfer_balance` by the allowance amount.
  - Insert credit record into `rider_transactions`.

```typescript
// Retrieve allowance configuration
const { data: agent } = await supabaseClient
  .from("delivery_agents")
  .select("id, direct_transfer_balance, failed_delivery_allowance")
  .eq("id", payload.agentId)
  .single();

const allowance = agent?.failed_delivery_allowance || 500.0;
const newBalance = (agent?.direct_transfer_balance || 0.0) + allowance;

// Credit rider's balance
await supabaseClient
  .from("delivery_agents")
  .update({ direct_transfer_balance: newBalance })
  .eq("id", payload.agentId);

// Record audit credit
await supabaseClient.from("rider_transactions").insert({
  delivery_agent_id: payload.agentId,
  transaction_code: `TXN-FAIL-${Date.now().toString().slice(-6)}`,
  title: `Failed Delivery Attempt Stipend`,
  category: "earnings",
  amount: allowance,
  is_credit: true,
  reference: payload.orderId,
  status: "settled",
  description: `₦${allowance} transport compensation for failed delivery attempt [${payload.reasonCode}].`,
  created_at: new Date().toISOString(),
});
```

---

### 2.4 `paystack-webhook` (`supabase/functions/paystack-webhook/index.ts`)
- **Current Defect**: Hardcodes fallback DC UUID `22222222-2222-4222-8222-222222222222`. When a rider makes an instant remittance via Paystack, it marks the remittance verified but does not call the stored procedure to decrement `delivery_agents.current_cod_balance`.
- **Required Implementation**:
  - Remove all hardcoded fallback UUIDs. Resolve DC dynamically from `delivery_agents` or `orders`.
  - When transaction type is `remittance`, invoke `fn_approve_cash_remittance` to clear the rider's COD liability atomically.

```typescript
// Case B: RIDER CASH REMITTANCE AUTO-VERIFICATION
if (transactionType === "remittance" || remittanceId) {
  // Resolve DC dynamically
  let dcId: string | null = null;
  if (agentId) {
    const { data: agent } = await supabaseClient
      .from("delivery_agents")
      .select("distribution_center_id")
      .eq("id", agentId)
      .single();
    dcId = agent?.distribution_center_id || null;
  }

  // Update Remittance Record
  const { data: updatedRemittance } = await supabaseClient
    .from("cash_remittances")
    .update({
      status: "verified",
      is_verified: true,
      amount: amount,
      payment_method: "paystack",
      distribution_center_id: dcId,
      verified_by_name: "Paystack Settlement Gateway",
      verified_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("reference_number", reference)
    .select()
    .single();

  // Atomically clear rider COD liability
  if (updatedRemittance?.id) {
    await supabaseClient.rpc("fn_approve_cash_remittance", {
      p_remittance_id: updatedRemittance.id,
    });
  }
}
```

---

### 2.5 `generate-daily-settlements` (`supabase/functions/generate-daily-settlements/index.ts`) [NEW]
- **Purpose**: Autonomous daily cron trigger executing every day at **22:00 (10:00 PM)** or triggered on-demand via the Main DC Console.
- **Workflow**:
  1. Finds all active clients with unsettled delivered orders for the current date.
  2. For each client, calls `fn_generate_merchant_daily_settlement` passing start of day (`00:00:00`) and cut-off (`22:00:00`).
  3. Returns settlement summary array and logs execution status.

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

serve(async (req: Request) => {
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const { clientId, dcId, periodStart, periodEnd, customDeductions } = await req.json().catch(() => ({}));

  // Resolve time window: Defaults to today 00:00 to 22:00
  const now = new Date();
  const start = periodStart ? new Date(periodStart) : new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const end = periodEnd ? new Date(periodEnd) : new Date(now.getFullYear(), now.getMonth(), now.getDate(), 22, 0, 0);

  // If specific client passed, execute single settlement
  if (clientId) {
    const { data: result, error } = await supabaseClient.rpc("fn_generate_merchant_daily_settlement", {
      p_client_id: clientId,
      p_dc_id: dcId || "22222222-2222-4222-8222-222222222222",
      p_period_start: start.toISOString(),
      p_period_end: end.toISOString(),
      p_custom_deductions: customDeductions || {},
    });

    return new Response(JSON.stringify({ success: !error, result, error }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  // Otherwise, sweep all active clients with unsettled delivered orders
  const { data: clients } = await supabaseClient
    .from("clients")
    .select("id, name")
    .eq("is_active", true);

  const results = [];
  for (const client of clients || []) {
    const { data: res } = await supabaseClient.rpc("fn_generate_merchant_daily_settlement", {
      p_client_id: client.id,
      p_dc_id: dcId || "22222222-2222-4222-8222-222222222222",
      p_period_start: start.toISOString(),
      p_period_end: end.toISOString(),
      p_custom_deductions: {},
    });
    if (res?.orders_settled > 0) {
      results.push({ client: client.name, ...res });
    }
  }

  return new Response(JSON.stringify({ success: true, processedCount: results.length, batches: results }), {
    headers: { "Content-Type": "application/json" },
  });
});
```
