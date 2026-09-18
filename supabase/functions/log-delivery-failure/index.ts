import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LogFailurePayload {
  orderId: string;
  agentId: string;
  reasonCode: "customer_unavailable" | "wrong_address" | "cash_shortfall" | "customer_cancelled" | "rescheduled" | "other";
  notes?: string;
  scheduledCallbackAt?: string;
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

    const payload: LogFailurePayload = await req.json();

    if (!payload.orderId || !payload.agentId || !payload.reasonCode) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: orderId, agentId, and reasonCode are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const isCallback = payload.reasonCode === "rescheduled" || !!payload.scheduledCallbackAt;
    const newStatus = isCallback ? "call_back" : "cancelled";

    // 1. Update order record
    const { data: order, error: updateError } = await supabaseClient
      .from("orders")
      .update({
        status: newStatus,
        reschedule_note: payload.reasonCode,
        scheduled_callback_at: payload.scheduledCallbackAt || null,
        delivery_notes: payload.notes || null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", payload.orderId)
      .select("order_number, distribution_center_id")
      .single();

    if (updateError) {
      return new Response(
        JSON.stringify({ error: "Failed to update order failure status.", details: updateError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch rider's configured failed delivery allowance and current balance
    const { data: agent } = await supabaseClient
      .from("delivery_agents")
      .select("failed_delivery_allowance, direct_transfer_balance")
      .eq("id", payload.agentId)
      .maybeSingle();

    // Fetch DC fallback settings
    const { data: dcSettings } = await supabaseClient
      .from("dc_finance_settings")
      .select("default_failed_stipend, default_failed_delivery_allowance")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const failedStipend = Number(
      agent?.failed_delivery_allowance ??
      dcSettings?.default_failed_stipend ??
      dcSettings?.default_failed_delivery_allowance ??
      500.00
    );

    // 3. Credit rider's direct_transfer_balance with transport allowance for attempt
    if (!isCallback && failedStipend > 0) {
      const newBalance = Number(agent?.direct_transfer_balance || 0) + failedStipend;

      await supabaseClient
        .from("delivery_agents")
        .update({
          direct_transfer_balance: newBalance,
          updated_at: new Date().toISOString(),
        })
        .eq("id", payload.agentId);

      // Record transaction
      const txnCode = `TXN-${Math.floor(1000 + Math.random() * 9000)}`;
      await supabaseClient.from("rider_transactions").insert({
        delivery_agent_id: payload.agentId,
        transaction_code: txnCode,
        title: "Failed Delivery Attempt Allowance",
        category: "earnings",
        amount: failedStipend,
        is_credit: true,
        reference: order?.order_number || payload.orderId,
        status: "settled",
        description: `Transport stipend credited for failed delivery attempt on order ${order?.order_number ?? payload.orderId} (${payload.reasonCode}).`,
        created_at: new Date().toISOString(),
      });
    }

    // 4. Audit Activity Log
    await supabaseClient.from("order_activities").insert({
      order_id: payload.orderId,
      user_id: payload.agentId,
      activity_type: "delivery_failed",
      notes: `Delivery attempt failed: [${payload.reasonCode}]. Notes: ${payload.notes || "None"}`,
      created_at: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        orderId: payload.orderId,
        status: newStatus,
        reasonCode: payload.reasonCode,
        stipendCredited: !isCallback ? failedStipend : 0,
        message: `Order delivery recorded as ${newStatus}.`,
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
