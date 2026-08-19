import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface StockTransferItemPayload {
  productId: string;
  quantityRequested: number;
}

interface StockTransferPayload {
  agentId: string;
  companyId: string;
  sourceWarehouseId: string;
  items: StockTransferItemPayload[];
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

    const payload: StockTransferPayload = await req.json();

    if (!payload.agentId || !payload.items || payload.items.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: Agent ID and at least one item are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const waybillNumber = `WB-PDA-${Date.now().toString().slice(-6)}`;

    // 1. Create stock transfer header
    const { data: transfer, error: transferError } = await supabaseClient
      .from("stock_transfers")
      .insert({
        waybill_number: waybillNumber,
        company_id: payload.companyId || "11111111-1111-4111-8111-111111111111",
        source_warehouse_id: payload.sourceWarehouseId || "c1111111-1111-4111-8111-111111111111",
        status: "pending",
        notes: `Restock request from PDA. ${payload.notes || ""}`,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (transferError) {
      return new Response(
        JSON.stringify({ error: "Failed to create stock transfer.", details: transferError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Insert items
    const transferItems = payload.items.map((item) => ({
      stock_transfer_id: transfer.id,
      product_id: item.productId,
      quantity_sent: item.quantityRequested,
      quantity_received: 0,
    }));

    await supabaseClient.from("stock_transfer_items").insert(transferItems);

    return new Response(
      JSON.stringify({
        success: true,
        waybillNumber,
        transferId: transfer.id,
        status: "pending",
        message: "Restock transfer request submitted to DC successfully.",
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
