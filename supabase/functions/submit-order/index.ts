// ============================================================================
// NOVEXPS SUPABASE EDGE FUNCTION: submit-order
// High-Scale Public Landing Page Order & Lead Ingestion with Meta CAPI Dispatch
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-forwarded-for",
};

interface OrderPayload {
  form_id: string;
  customer_name: string;
  customer_phone: string;
  customer_alt_phone?: string;
  customer_email?: string;
  delivery_address: string;
  delivery_state: string;
  delivery_lga?: string;
  lga?: string;
  delivery_city?: string;
  notes?: string;
  package_id?: string;
  package_name?: string;
  buy_qty?: number;
  total_amount?: number;
  free_addon_product_id?: string;
  free_addon_qty?: number;
  utm_source?: string;
  utm_medium?: string;
  utm_campaign?: string;
  utm_content?: string;
  ad_id?: string;
  // Bot Honeypot fields
  hp_website?: string;
  hp_field?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: OrderPayload = await req.json();

    // 🛡️ Security Honeypot check
    if (payload.hp_website || payload.hp_field) {
      console.warn("Spam bot trapped by honeypot field");
      return new Response(
        JSON.stringify({
          success: true,
          message: "Order placed successfully",
          redirect_url: "https://novaexpress.ng/thank-you"
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 201 }
      );
    }

    if (!payload.form_id || !payload.customer_name || !payload.customer_phone || !payload.delivery_address) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required order fields (form_id, customer_name, customer_phone, delivery_address)." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Call high-performance PostgreSQL RPC: fn_submit_marketing_lead_order
    const { data: rpcResult, error: rpcError } = await supabase.rpc(
      "fn_submit_marketing_lead_order",
      { p_payload: payload }
    );

    if (rpcError) {
      console.error("RPC Error:", rpcError);
      return new Response(
        JSON.stringify({ success: false, error: rpcError.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    // Optional: Fetch Meta Pixel and CAPI credentials if configured on the form
    try {
      const { data: formData } = await supabase
        .from("lead_forms")
        .select("pixel_id, capi_token, test_event_code")
        .eq("id", payload.form_id)
        .maybeSingle();

      if (formData?.pixel_id && formData?.capi_token) {
        // Dispatch Meta Conversions API (CAPI) in background
        const eventTime = Math.floor(Date.now() / 1000);
        const eventId = rpcResult.event_id || `CAPI_${rpcResult.order_number}`;

        // Basic payload for Meta Graph API v18.0
        const capiPayload = {
          data: [
            {
              event_name: "Purchase",
              event_time: eventTime,
              event_id: eventId,
              event_source_url: req.headers.get("referer") || "",
              action_source: "website",
              user_data: {
                ph: [await hashSha256(payload.customer_phone.replace(/[^0-9]/g, ""))],
                fn: [await hashSha256(payload.customer_name.trim().toLowerCase())],
                ct: [await hashSha256((payload.delivery_city || "abuja").trim().toLowerCase())],
                st: [await hashSha256((payload.delivery_state || "abuja").trim().toLowerCase())],
                country: [await hashSha256("ng")],
                client_ip_address: req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "127.0.0.1",
                client_user_agent: req.headers.get("user-agent") || "",
              },
              custom_data: {
                currency: "NGN",
                value: rpcResult.total_amount,
                order_id: rpcResult.order_number,
              },
            }
          ],
          ...(formData.test_event_code ? { test_event_code: formData.test_event_code } : {})
        };

        // Fire-and-forget CAPI request
        fetch(`https://graph.facebook.com/v18.0/${formData.pixel_id}/events?access_token=${formData.capi_token}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(capiPayload),
        }).catch((err) => console.warn("Meta CAPI dispatch warning:", err));
      }
    } catch (e) {
      console.warn("Meta CAPI dispatch skipped or failed:", e);
    }

    return new Response(
      JSON.stringify(rpcResult),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 201 }
    );
  } catch (err: any) {
    console.error("Unhandled error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err?.message || "Internal server error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

// SHA-256 helper for Meta CAPI
async function hashSha256(str: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(str);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
