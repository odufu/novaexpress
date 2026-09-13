import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SubmitRemittancePayload {
  agentId: string;
  companyId?: string;
  distributionCenterId?: string;
  amount: number;
  paymentMethod: "bank_transfer" | "dc_handover" | "pos_settlement" | "paystack";
  depositReceiptUrl?: string;
  referenceNumber?: string;
  notes?: string;
  failedStipendsDeducted?: number;
  commissionDeducted?: number;
  transportAllowanceDeducted?: number;
  posFee?: number;
  associatedOrders?: Array<{
    orderId: string;
    amount?: number;
    paymentType?: string;
  }>;
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

    const payload: SubmitRemittancePayload = await req.json();

    if (!payload.agentId || !payload.amount || payload.amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid remittance submission: Agent ID and positive amount required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Resolve Delivery Agent details (DC ID, Company ID, COD balance)
    const { data: agent } = await supabaseClient
      .from("delivery_agents")
      .select("id, company_id, distribution_center_id, current_cod_balance")
      .eq("id", payload.agentId)
      .single();

    const companyId = payload.companyId || agent?.company_id || "11111111-1111-4111-8111-111111111111";
    const dcId = payload.distributionCenterId || agent?.distribution_center_id || null;

    // 2. Generate unique reference if missing
    const ref = payload.referenceNumber && payload.referenceNumber.trim().length > 0
      ? payload.referenceNumber.trim()
      : `REM-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;

    const isPaystack = payload.paymentMethod.toLowerCase() === "paystack";
    const remittanceNotes = `[${payload.paymentMethod.toUpperCase()}] Ref: ${ref} - ${payload.notes || ""}`.trim();

    // 3. Insert into cash_remittances
    const { data: newRemittance, error: insertError } = await supabaseClient
      .from("cash_remittances")
      .insert({
        company_id: companyId,
        delivery_agent_id: payload.agentId,
        distribution_center_id: dcId,
        amount: payload.amount,
        reference_number: ref,
        payment_method: payload.paymentMethod,
        deposit_receipt_url: payload.depositReceiptUrl || null,
        failed_stipends_deducted: payload.failedStipendsDeducted || 0.00,
        commission_deducted: payload.commissionDeducted || 0.00,
        transport_allowance_deducted: payload.transportAllowanceDeducted || 0.00,
        pos_fee: payload.posFee || 0.00,
        status: isPaystack ? "verified" : "pending",
        is_verified: isPaystack,
        verified_at: isPaystack ? new Date().toISOString() : null,
        notes: remittanceNotes,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (insertError) {
      return new Response(
        JSON.stringify({ error: "Failed to create remittance record.", details: insertError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Link associated orders in remittance_orders
    if (payload.associatedOrders && payload.associatedOrders.length > 0 && newRemittance?.id) {
      const orderLinks = payload.associatedOrders.map((o) => ({
        cash_remittance_id: newRemittance.id,
        order_id: o.orderId,
        order_amount: o.amount || 0.00,
        payment_type: o.paymentType || "pay_on_delivery",
      }));
      await supabaseClient.from("remittance_orders").insert(orderLinks);
    }

    // 5. If instant Paystack remittance, immediately execute atomic clearance procedure
    if (isPaystack && newRemittance?.id) {
      await supabaseClient.rpc("fn_approve_cash_remittance", {
        p_remittance_id: newRemittance.id,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        remittance: newRemittance,
        message: isPaystack
          ? "Instant Paystack remittance verified and COD balance cleared."
          : "Cash remittance logged successfully. Awaiting DC Finance verification.",
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
