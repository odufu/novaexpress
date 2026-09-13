import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch products where stock_quantity <= low_stock_threshold
    const { data: lowStockProducts, error } = await supabase
      .from("products")
      .select("id, name, sku, stock_quantity, low_stock_threshold, company_id")
      .filter("stock_quantity", "lte", "low_stock_threshold");

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let alertCount = 0;
    for (const prod of lowStockProducts || []) {
      const threshold = prod.low_stock_threshold ?? 10;
      const currentStock = prod.stock_quantity ?? 0;

      if (currentStock <= threshold) {
        await supabase.from("notifications").insert({
          company_id: prod.company_id,
          title: `⚠️ Low Stock Alert: ${prod.name}`,
          message: `Stock for ${prod.name} (${prod.sku || "N/A"}) has fallen to ${currentStock} units (Threshold: ${threshold}). Please replenish soon.`,
          category: "inventory",
          action_route: `/dc/stock?product_id=${prod.id}`,
          is_read: false,
        });
        alertCount++;
      }
    }

    return new Response(
      JSON.stringify({ success: true, alertsGenerated: alertCount }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
