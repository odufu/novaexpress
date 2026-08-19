import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.json();
    const eventData = body.eventData || body;

    const accountReference = eventData.accountReference || eventData.product?.reference;
    const amountPaid = parseFloat(eventData.amountPaid || eventData.settlementAmount || "0");
    const transactionReference = eventData.transactionReference || eventData.paymentReference;

    if (!accountReference || !transactionReference) {
      return new Response(
        JSON.stringify({ error: "Invalid webhook payload structure." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Find virtual account record
    const { data: vAccount, error: vaError } = await supabaseClient
      .from("monnify_virtual_accounts")
      .select("*, order:orders(*)")
      .eq("account_reference", accountReference)
      .single();

    if (vaError || !vAccount) {
      return new Response(
        JSON.stringify({ error: "Virtual account not found.", details: vaError }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Insert Monnify Transaction Log
    await supabaseClient.from("monnify_transactions").insert({
      virtual_account_id: vAccount.id,
      order_id: vAccount.order_id,
      transaction_reference: transactionReference,
      amount_paid: amountPaid,
      payer_name: eventData.paymentDescription || eventData.accountName,
      webhook_payload: body,
      verification_status: "verified",
      created_at: new Date().toISOString(),
    });

    // 3. Mark Virtual Account & Order as paid/transferred
    await supabaseClient
      .from("monnify_virtual_accounts")
      .update({
        status: "paid",
        amount_paid: amountPaid,
        payment_received_at: new Date().toISOString(),
      })
      .eq("id", vAccount.id);

    await supabaseClient
      .from("orders")
      .update({
        payment_status: "transferred",
        updated_at: new Date().toISOString(),
      })
      .eq("id", vAccount.order_id);

    // 4. Credit Rider's Direct Transfer Balance
    const agentId = vAccount.order?.delivery_agent_id;
    if (agentId) {
      const entitlement = vAccount.order?.agent_entitlement || 2500.0;
      
      const { data: agent } = await supabaseClient
        .from("delivery_agents")
        .select("direct_transfer_balance")
        .eq("id", agentId)
        .single();

      const newBalance = (agent?.direct_transfer_balance || 0) + entitlement;
      await supabaseClient
        .from("delivery_agents")
        .update({ direct_transfer_balance: newBalance })
        .eq("id", agentId);

      // Record Rider Transaction Ledger Credit
      const txnCode = `TXN-${Math.floor(1000 + Math.random() * 9000)}`;
      await supabaseClient.from("rider_transactions").insert({
        delivery_agent_id: agentId,
        transaction_code: txnCode,
        title: `Direct Transfer Credit (${vAccount.order?.order_number})`,
        category: "direct_transfer",
        amount: entitlement,
        is_credit: true,
        reference: transactionReference,
        status: "settled",
        description: `Commission & allowance credited from Monnify payment on order ${vAccount.order?.order_number}.`,
        created_at: new Date().toISOString(),
      });
    }

    return new Response(
      JSON.stringify({ success: true, message: "Webhook processed and ledger updated." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
