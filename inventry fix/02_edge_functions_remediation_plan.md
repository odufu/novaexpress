# Phase 2: Supabase Edge Functions Remediation Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\02_edge_functions_remediation_plan.md`  
**Target Functions:**
1. `supabase/functions/confirm-delivery-pod/index.ts`
2. `supabase/functions/log-delivery-failure/index.ts`
3. `supabase/functions/auto-stock-alert/index.ts` (New)

---

## 1. Remediation for `confirm-delivery-pod`

### 1.1 Root Cause & Vulnerability
In `supabase/functions/confirm-delivery-pod/index.ts:79-100`:
1. The function directly executes:
   ```typescript
   const qty = order.quantity || 1;
   const currentStock = prod.stock_quantity ?? prod.available_count ?? 0;
   const newStock = Math.max(0, currentStock - qty);
   await supabaseClient.from("products").update({
       stock_quantity: newStock,
       available_count: Math.max(0, (prod.available_count ?? currentStock) - qty),
       delivered_count: (prod.delivered_count || 0) + qty,
   }).eq("id", order.product_id);
   ```
2. **Double Deduction**: The stock was already decremented from `products.stock_quantity` when the DC supervisor issued the waybill to the rider. Decrementing `products.stock_quantity` again causes an illegal duplicate deduction.
3. **Bundle Undercount**: If a customer bought a 5-unit promo bundle, `order.quantity` is `1` (1 bundle), but `order.paid_quantity + order.free_quantity` is `5`. Only 1 unit was deducted.
4. **No Custody Decrement**: The rider's `agent_inventory` record in Supabase is completely untouched.

### 1.2 Required Code Changes
Replace lines 79-100 of `supabase/functions/confirm-delivery-pod/index.ts` with:

```typescript
    // 2b. Atomically adjust rider custody and record product delivery metrics
    if (order.product_id && payload.agentId) {
      // Calculate true physical unit quantity (handling package bundles)
      const paidQty = typeof order.paid_quantity === "number" ? order.paid_quantity : 0;
      const freeQty = typeof order.free_quantity === "number" ? order.free_quantity : 0;
      const totalPhysicalQuantity = (paidQty + freeQty > 0)
        ? (paidQty + freeQty)
        : (order.quantity || 1);

      const { data: stockRpcRes, error: stockRpcErr } = await supabaseClient.rpc(
        "fn_confirm_order_delivery_stock",
        {
          p_order_id: payload.orderId,
          p_agent_id: payload.agentId,
          p_product_id: order.product_id,
          p_physical_quantity: totalPhysicalQuantity,
        }
      );

      if (stockRpcErr) {
        console.error("Warning: Failed to execute fn_confirm_order_delivery_stock:", stockRpcErr);
      } else {
        console.log(`Successfully updated rider custody for order ${payload.orderId}:`, stockRpcRes);
      }
    }
```

---

## 2. Remediation for `log-delivery-failure`

### 2.1 Issue
When an order fails or is returned by the customer at doorstep:
- The order status updates to `'failed'` or `'returned_to_dc'`.
- The rider's vehicle custody must be audited: if the item was refused, it remains in the rider's `agent_inventory` until the rider submits a return to the DC.
- If the item was damaged during delivery, the edge function should allow logging `damage_reported`.

### 2.2 Required Code Addition in `log-delivery-failure/index.ts`
When processing a failed or cancelled order:
```typescript
    // Ensure rider custody reflects that the item is back in available custody or marked for return
    if (payload.failureReason === "customer_rejected_damaged" && order.product_id) {
      // Create draft stock return for damaged item
      await supabaseClient.from("stock_returns").insert({
        delivery_agent_id: payload.agentId,
        product_id: order.product_id,
        quantity: order.total_physical_quantity || order.quantity || 1,
        return_reason: "Customer rejected: Damaged goods",
        status: "submitted",
        condition: "damaged",
      });
    }
```

---

## 3. New Edge Function: `auto-stock-alert`

Create `supabase/functions/auto-stock-alert/index.ts` to check daily for products where:
$$\text{stock\_quantity} \le \text{low\_stock\_threshold}$$

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Fetch low stock items
  const { data: lowStockProducts, error } = await supabase
    .from("products")
    .select("id, name, stock_quantity, low_stock_threshold, company_id")
    .filter("stock_quantity", "lte", "low_stock_threshold");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  // Create notifications for merchants and supervisors
  for (const prod of lowStockProducts || []) {
    await supabase.from("notifications").insert({
      company_id: prod.company_id,
      title: `⚠️ Low Stock Alert: ${prod.name}`,
      message: `Stock level has dropped to ${prod.stock_quantity} units (Threshold: ${prod.low_stock_threshold}). Please reorder or request replenishment.`,
      category: "inventory",
      action_route: `/dc/stock?product_id=${prod.id}`,
      is_read: false,
    });
  }

  return new Response(JSON.stringify({ success: true, alertedCount: lowStockProducts?.length || 0 }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

---

## 4. Verification Plan

1. **Deploy Edge Functions**:
   ```bash
   npx supabase functions deploy confirm-delivery-pod --project-ref qpcafevjsrbauweuiiyq
   npx supabase functions deploy log-delivery-failure --project-ref qpcafevjsrbauweuiiyq
   ```
2. **Simulate POD Confirmation**:
   - Send test delivery confirmation via cURL / Postman for a bundle order.
   - Verify that `products.stock_quantity` remains untouched.
   - Verify that `agent_inventory.total_in_custody` decrements by the bundle's full physical count.
   - Verify that `products.delivered_count` increments by the bundle's full physical count.
