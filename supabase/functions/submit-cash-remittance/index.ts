import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SubmitRemittancePayload {
  agentId: string;
  companyId: string;
  amount: number;
  paymentMethod: "bank_transfer" | "dc_handover" | "pos_settlement";
  depositReceiptUrl?: string;
  referenceNumber?: string;
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

    const payload: SubmitRemittancePayload = await req.json();

    if (!payload.agentId || !payload.amount || payload.amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid remittance submission: Agent ID and positive amount required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const remittanceNotes = `[${payload.paymentMethod.toUpperCase()}] Ref: ${payload.referenceNumber || "N/A"} - ${payload.notes || ""}`;

    const { data: newRemittance, error: insertError } = await supabaseClient
      .from("cash_remittances")
      .insert({
        company_id: payload.companyId || "11111111-1111-4111-8111-111111111111",
        delivery_agent_id: payload.agentId,
        amount: payload.amount,
        deposit_receipt_url: payload.depositReceiptUrl || null,
        status: "pending",
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

    return new Response(
      JSON.stringify({
        success: true,
        remittance: newRemittance,
        message: "Cash remittance logged successfully. Awaiting DC Finance verification.",
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
