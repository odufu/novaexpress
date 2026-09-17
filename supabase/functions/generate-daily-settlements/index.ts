import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SettlementTriggerPayload {
  clientId?: string;
  dcId?: string;
  periodStart?: string;
  periodEnd?: string;
  orderIds?: string[];
  customDeductions?: Record<string, any>;
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

    let payload: SettlementTriggerPayload = {};
    try {
      if (req.headers.get("content-length") !== "0") {
        payload = await req.json();
      }
    } catch (_) {}

    const now = new Date();
    // Default period: covers all pending delivered orders up to current cutoff
    const periodStart = payload.periodStart || null;
    const periodEnd = payload.periodEnd || now.toISOString();

    const results: Array<any> = [];

    // If a specific client is provided, execute for that client only
    if (payload.clientId) {
      const dcId = payload.dcId || "22222222-2222-4222-8222-222222222222";
      const { data, error } = await supabaseClient.rpc("fn_generate_merchant_daily_settlement", {
        p_client_id: payload.clientId,
        p_dc_id: dcId,
        p_period_start: periodStart,
        p_period_end: periodEnd,
        p_custom_deductions: payload.customDeductions || {},
        p_order_ids: payload.orderIds || null,
      });

      if (error) {
        return new Response(
          JSON.stringify({ success: false, error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, settlement: data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Otherwise, iterate all active clients that have delivered orders awaiting settlement
    const { data: clients, error: clientsError } = await supabaseClient
      .from("clients")
      .select("id, company_name")
      .eq("is_active", true);

    if (clientsError || !clients) {
      return new Response(
        JSON.stringify({ success: false, error: clientsError?.message || "Failed to fetch active clients." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const defaultDcId = payload.dcId || "22222222-2222-4222-8222-222222222222";

    for (const client of clients) {
      // Check if client has un-settled delivered orders
      let ordersQuery = supabaseClient
        .from("orders")
        .select("id", { count: "exact", head: true })
        .eq("client_id", client.id)
        .eq("status", "delivered")
        .or("financial_settlement_status.is.null,financial_settlement_status.neq.client_settled")
        .lte("delivered_at", periodEnd);

      if (periodStart) {
        ordersQuery = ordersQuery.gte("delivered_at", periodStart);
      }

      const { count } = await ordersQuery;

      if (count && count > 0) {
        const { data: settleRes, error: settleErr } = await supabaseClient.rpc("fn_generate_merchant_daily_settlement", {
          p_client_id: client.id,
          p_dc_id: defaultDcId,
          p_period_start: periodStart,
          p_period_end: periodEnd,
          p_custom_deductions: {},
          p_order_ids: null,
        });

        if (!settleErr && settleRes && settleRes.success !== false) {
          results.push({
            clientId: client.id,
            clientName: client.company_name,
            settlement: settleRes,
          });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Daily Client Settlement executed successfully. ${results.length} merchant batches generated.`,
        settlementsGenerated: results.length,
        batches: results,
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
