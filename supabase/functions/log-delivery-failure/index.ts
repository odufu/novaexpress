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
    const { error: updateError } = await supabaseClient
      .from("orders")
      .update({
        status: newStatus,
        reschedule_note: payload.reasonCode,
        scheduled_callback_at: payload.scheduledCallbackAt || null,
        delivery_notes: payload.notes || null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", payload.orderId);

    if (updateError) {
      return new Response(
        JSON.stringify({ error: "Failed to update order failure status.", details: updateError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Audit Activity Log
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
