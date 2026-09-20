import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface StockInvoicePayload {
  invoice_id: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body: StockInvoicePayload = await req.json();
    if (!body.invoice_id) {
      return new Response(
        JSON.stringify({ error: "Missing invoice_id in request body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Execute the database stored procedure to finalize stock entry and adjust weighted average rates
    const { data, error } = await supabase.rpc("fn_process_client_stock_intake_invoice", {
      p_invoice_id: body.invoice_id,
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Retrieve the verified invoice details to send notification
    const { data: invoice } = await supabase
      .from("client_stock_invoices")
      .select("*, client_stock_invoice_items(*)")
      .eq("id", body.invoice_id)
      .single();

    if (invoice) {
      await supabase.from("notifications").insert({
        title: `📦 Stock Intake Verified: ${invoice.invoice_number}`,
        message: `Received ${invoice.total_units} units from ${invoice.supplier_name} at ${invoice.destination_warehouse}. Total Landed Cost: ₦${Number(invoice.grand_total_landed_cost).toLocaleString()}`,
        category: "inventory",
        action_route: `/client/inventory?invoice=${invoice.id}`,
        is_read: false,
      });
    }

    return new Response(
      JSON.stringify({ success: true, result: data, invoice }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
