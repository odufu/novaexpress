import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PayoutRequestPayload {
  agentId: string;
  amount: number;
  bankName: string;
  accountNumber: string;
  accountName: string;
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

    const payload: PayoutRequestPayload = await req.json();

    if (!payload.agentId || !payload.amount || payload.amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid payout request parameters." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Verify agent balance
    const { data: agent, error: agentError } = await supabaseClient
      .from("delivery_agents")
      .select("direct_transfer_balance")
      .eq("id", payload.agentId)
      .single();

    if (agentError || !agent) {
      return new Response(
        JSON.stringify({ error: "Agent not found." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if ((agent.direct_transfer_balance || 0) < payload.amount) {
      return new Response(
        JSON.stringify({
          error: "Insufficient balance.",
          availableBalance: agent.direct_transfer_balance,
          requestedAmount: payload.amount,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payoutNumber = `PAY-${Math.floor(1000 + Math.random() * 9000)}`;

    // 2. Insert Payout Request
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

    if (payoutError) {
      return new Response(
        JSON.stringify({ error: "Failed to create payout request.", details: payoutError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Record Audit Transaction
    const txnCode = `TXN-${Math.floor(1000 + Math.random() * 9000)}`;
    await supabaseClient.from("rider_transactions").insert({
      delivery_agent_id: payload.agentId,
      transaction_code: txnCode,
      title: "Balance Payout Requested",
      category: "payout",
      amount: payload.amount,
      is_credit: false,
      reference: payoutNumber,
      status: "pending",
      description: `Withdrawal from My Balance to ${payload.bankName} (${payload.accountNumber}). Awaiting DC Approval.`,
      created_at: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        payout,
        message: "Payout request submitted successfully and pending DC Finance review.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
