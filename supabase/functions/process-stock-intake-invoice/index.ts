import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface StockIntakePayload {
  action?: "process_invoice" | "create_consignment" | "handshake_reception";
  invoice_id?: string;
  transfer_id?: string;
  sender_id?: string;
  sender_name?: string;
  sender_signature_url?: string;
  receiver_id?: string;
  receiver_name?: string;
  receiver_role?: string;
  receiver_signature_url?: string;
  carrier_driver_name?: string;
  carrier_phone?: string;
  carrier_license_plate?: string;
  waybill_slip_url?: string;
  destination_bin?: string;
  verified_items?: any[];
  notes?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body: StockIntakePayload = await req.json();

    // 1. Handshake Reception Flow
    if (body.action === "handshake_reception" || (body.transfer_id && !body.invoice_id)) {
      if (!body.transfer_id) {
        return new Response(
          JSON.stringify({ error: "Missing transfer_id for handshake reception" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data, error } = await supabase.rpc("fn_receive_supply_consignment_handshake", {
        p_transfer_id: body.transfer_id,
        p_receiver_id: body.receiver_id || "00000000-0000-0000-0000-000000000000",
        p_receiver_name: body.receiver_name || "DC Station Supervisor",
        p_receiver_role: body.receiver_role || "dc_supervisor",
        p_receiver_signature_url: body.receiver_signature_url || "",
        p_carrier_driver_name: body.carrier_driver_name || "",
        p_carrier_phone: body.carrier_phone || "",
        p_carrier_license_plate: body.carrier_license_plate || "",
        p_waybill_slip_url: body.waybill_slip_url || "",
        p_destination_bin: body.destination_bin || "",
        p_verified_items: body.verified_items || [],
        p_notes: body.notes || "",
      });

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, result: data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Create DC Consignment Flow
    if (body.action === "create_consignment") {
      if (!body.invoice_id) {
        return new Response(
          JSON.stringify({ error: "Missing invoice_id for creating DC consignment" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data, error } = await supabase.rpc("fn_create_dc_consignment_for_intake_invoice", {
        p_invoice_id: body.invoice_id,
        p_sender_id: body.sender_id || null,
        p_sender_name: body.sender_name || "",
        p_sender_signature_url: body.sender_signature_url || "",
        p_carrier_driver_name: body.carrier_driver_name || "",
        p_carrier_phone: body.carrier_phone || "",
      });

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, result: data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Default Legacy Invoice Processing Flow
    if (!body.invoice_id) {
      return new Response(
        JSON.stringify({ error: "Missing invoice_id in request body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // First ensure consignment handshake exists
    try {
      await supabase.rpc("fn_create_dc_consignment_for_intake_invoice", {
        p_invoice_id: body.invoice_id,
        p_sender_id: body.sender_id || null,
        p_sender_name: body.sender_name || "",
      });
    } catch (_) {
      // Non-blocking
    }

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
        title: `📦 Stock Intake Registered: ${invoice.invoice_number}`,
        message: `Registered ${invoice.total_units} units from ${invoice.supplier_name} for ${invoice.destination_warehouse}. Total Landed Cost: ₦${Number(invoice.grand_total_landed_cost).toLocaleString()}`,
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
