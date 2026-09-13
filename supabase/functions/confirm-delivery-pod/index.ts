import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ConfirmDeliveryPayload {
  orderId: string;
  agentId: string;
  paymentType: "pay_on_delivery" | "prepaid";
  paymentMethod: "cash" | "bank_transfer" | "paystack";
  amountCollected: number;
  customerSignatureUrl?: string;
  photoProofUrl?: string;
  notes?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const payload: ConfirmDeliveryPayload = await req.json();

    if (!payload.orderId || !payload.agentId) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: orderId and agentId are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch current order
    const { data: order, error: orderError } = await supabaseClient
      .from("orders")
      .select("*")
      .eq("id", payload.orderId)
      .single();

    if (orderError || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found.", details: orderError }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Update order status to delivered & collected
    const proofUrl = payload.photoProofUrl || payload.customerSignatureUrl || null;
    const nowIso = new Date().toISOString();
    const isDirectTransfer = payload.paymentType !== "pay_on_delivery" || payload.paymentMethod !== "cash";
    const { error: updateError } = await supabaseClient
      .from("orders")
      .update({
        status: "delivered",
        payment_status: isDirectTransfer ? "paid" : "collected",
        remittance_status: isDirectTransfer ? "direct_transfer" : "unremitted",
        financial_settlement_status: isDirectTransfer ? "direct_transfer_settled" : "in_dc_custody",
        delivered_at: nowIso,
        proof_of_delivery_url: proofUrl,
        delivery_notes: payload.notes || order.delivery_notes,
        updated_at: nowIso,
      })
      .eq("id", payload.orderId);

    if (updateError) {
      return new Response(
        JSON.stringify({ error: "Failed to update order status.", details: updateError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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

    // 3. Fetch delivery agent details to compute exact entitlement (Commission + Transport)
    const { data: agent } = await supabaseClient
      .from("delivery_agents")
      .select("current_cod_balance, direct_transfer_balance, commission_rate, transport_allowance, fuel_allowance, personnel_type")
      .eq("id", payload.agentId)
      .single();

    const commissionRate = agent?.commission_rate || (agent?.personnel_type === "in_house_rider" ? 500 : 1000);
    const transportAllowance = agent?.personnel_type === "in_house_rider"
      ? (agent?.fuel_allowance || 800)
      : (agent?.transport_allowance || 1500);
    const riderEarning = commissionRate + transportAllowance;

    let updatedCodBalance = agent?.current_cod_balance || 0;
    let updatedDirectBalance = agent?.direct_transfer_balance || 0;

    const isCashPod = payload.paymentType === "pay_on_delivery" && payload.paymentMethod === "cash";

    if (isCashPod) {
      // Rider collected cash. Rider retains their earning (commission + transport) and transfer charge directly from cash.
      // Dynamic transfer charge: ₦100 per ₦5,000 transfer block (e.g. ₦5,000 -> ₦100, ₦5,200 -> ₦200, ₦35,000 -> ₦700)
      const cashCollected = payload.amountCollected || order.total_amount || 0;
      const transferCharge = cashCollected > 0 ? Math.ceil(cashCollected / 5000) * 100 : 0;
      const netToRemit = Math.max(0, cashCollected - riderEarning - transferCharge);
      updatedCodBalance = updatedCodBalance + netToRemit;

      await supabaseClient
        .from("delivery_agents")
        .update({ current_cod_balance: updatedCodBalance })
        .eq("id", payload.agentId);
    } else {
      // Customer paid directly to company's account (Prepaid / Transfer / POS online).
      // Rider collected ₦0 cash in hand, so company owes rider their entitlement.
      // Rider withdrawable balance increases by riderEarning.
      updatedDirectBalance = updatedDirectBalance + riderEarning;

      await supabaseClient
        .from("delivery_agents")
        .update({ direct_transfer_balance: updatedDirectBalance })
        .eq("id", payload.agentId);

      // Log credit transaction into rider_transactions ledger
      await supabaseClient.from("rider_transactions").insert({
        delivery_agent_id: payload.agentId,
        transaction_code: `TXN-${Date.now().toString().slice(-6)}`,
        title: "Direct Transfer Delivery Credited",
        category: "direct_transfer",
        amount: riderEarning,
        is_credit: true,
        reference: order.order_number || payload.orderId,
        status: "settled",
        description: `Commission (₦${commissionRate}) + Transport Allowance (₦${transportAllowance}) credited to My Balance from direct company transfer.`,
        created_at: new Date().toISOString(),
      });
    }

    // 4. Log Audit Activity
    await supabaseClient.from("order_activities").insert({
      order_id: payload.orderId,
      user_id: payload.agentId,
      activity_type: "delivery_completed",
      notes: `Delivery completed via ${payload.paymentMethod}. Collected: ₦${payload.amountCollected || order.total_amount}. Rider Entitlement: ₦${riderEarning}`,
      created_at: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        orderId: payload.orderId,
        status: "delivered",
        paymentStatus: "collected",
        currentCodBalance: updatedCodBalance,
        directTransferBalance: updatedDirectBalance,
        riderEarning: riderEarning,
        message: "Order successfully confirmed and marked as Delivered.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
