import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-id",
};

interface PickupStop {
  stop_number: number;
  location_id: string;
  location_name: string;
  pickup_address: string;
  city?: string;
  state?: string;
  lga?: string;
  landmark?: string;
  latitude?: number;
  longitude?: number;
  contact_person: string;
  contact_phone: string;
  contact_whatsapp?: string;
  items_to_collect: Array<{
    item_name: string;
    quantity: number;
    requires_cold_chain?: boolean;
  }>;
  sealed_bag_ref: string;
}

interface IngestClientPackagePayload {
  client_id: string;
  order_reference: string;
  fulfillment_type: "client_package";
  pickup_stops: PickupStop[];
  receiver: {
    name: string;
    phone_number: string;
    whatsapp_number?: string;
    address: string;
    city?: string;
    state?: string;
    lga?: string;
    landmark?: string;
    latitude?: number;
    longitude?: number;
  };
  package_summary?: {
    total_packages?: number;
    requires_cold_chain?: boolean;
    special_instructions?: string;
  };
  payment_receipt?: {
    gateway?: string;
    receipt_number?: string;
    transaction_reference?: string;
    amount_paid?: number;
    currency?: string;
    payment_status?: string;
    verified_at?: string;
  };
}

async function sha256Hex(str: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Authenticate Client API Key
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Bearer token in Authorization header." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const bearerToken = authHeader.replace("Bearer ", "").trim();
    const tokenHash = await sha256Hex(bearerToken);

    let payload: IngestClientPackagePayload;
    try {
      payload = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Malformed JSON payload." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const clientId = payload.client_id || req.headers.get("X-Client-Id");
    if (!clientId) {
      return new Response(
        JSON.stringify({ error: "Missing required client_id in payload or X-Client-Id header." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify client credentials
    const { data: b2bClient, error: clientErr } = await supabaseClient
      .from("b2b_clients")
      .select("*")
      .eq("id", clientId)
      .eq("is_active", true)
      .single();

    if (clientErr || !b2bClient) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: B2B client not found or inactive." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check token hash
    if (b2bClient.api_key_hash !== tokenHash) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid API secret token." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Validate Payload
    if (!payload.order_reference) {
      return new Response(
        JSON.stringify({ error: "Validation Error: 'order_reference' is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!payload.pickup_stops || !Array.isArray(payload.pickup_stops) || payload.pickup_stops.length === 0) {
      return new Response(
        JSON.stringify({ error: "Validation Error: At least 1 pickup stop is required in 'pickup_stops'." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!payload.receiver || !payload.receiver.name || !payload.receiver.phone_number || !payload.receiver.address) {
      return new Response(
        JSON.stringify({ error: "Validation Error: Receiver name, phone_number, and address are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Idempotency Check (Check for existing order)
    const { data: existingOrder } = await supabaseClient
      .from("orders")
      .select("id, order_number, status, total_amount, created_at, distribution_center_id")
      .eq("b2b_client_id", clientId)
      .eq("client_order_reference", payload.order_reference)
      .maybeSingle();

    if (existingOrder) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Order already ingested (idempotent duplicate request).",
          tracking_number: existingOrder.order_number,
          order_reference: payload.order_reference,
          status: existingOrder.status,
          total_logistics_fee: existingOrder.total_amount,
          created_at: existingOrder.created_at,
          live_tracking_url: `https://novaexpress.ng/track/${existingOrder.order_number}`,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Calculate Surcharge & Logistics Fee Server-Side
    const pickupCount = payload.pickup_stops.length;
    const baseRate = Number(b2bClient.base_flat_rate) || 3500.0;
    const extraStops = Math.max(0, pickupCount - 1);
    const extraStopFee = extraStops * (Number(b2bClient.additional_pickup_fee) || 1500.0);
    const totalLogisticsFee = baseRate + extraStopFee;
    const riderAllowance = (Number(b2bClient.rider_base_allowance) || 1800.0) +
      (extraStops * (Number(b2bClient.rider_extra_stop_allowance) || 1000.0));

    // 5. Match Nearest Active Distribution Center (DC)
    const targetCity = payload.pickup_stops[0].city || payload.receiver.city || "Abuja";
    const { data: dcList } = await supabaseClient
      .from("distribution_centers")
      .select("id, name, city, phone")
      .eq("status", "active");

    const matchedDc = (dcList && dcList.find((d) => d.city?.toLowerCase() === targetCity.toLowerCase())) ||
      (dcList && dcList[0]) || { id: null, name: "Central Hub", phone: null };

    // 6. Generate Tracking Number & Verification OTP
    const randSuffix = Math.floor(1000 + Math.random() * 9000);
    const trackingNumber = `NOV-2026-CC${randSuffix}`;
    const deliveryOtp = String(Math.floor(1000 + Math.random() * 9000));

    // 7. Insert Order Row into public.orders
    const orderInsertPayload = {
      order_number: trackingNumber,
      fulfillment_type: "client_package",
      b2b_client_id: clientId,
      client_id: b2bClient.merchant_client_id || "c3333333-3333-4333-8333-333333333333",
      client_name: b2bClient.client_name,
      company_id: "11111111-1111-4111-8111-111111111111",
      quantity: 1,
      paid_quantity: 1,
      free_quantity: 0,
      client_order_reference: payload.order_reference,
      customer_name: payload.receiver.name,
      customer_phone: payload.receiver.phone_number,
      customer_alt_phone: payload.receiver.whatsapp_number || payload.receiver.phone_number,
      recipient_whatsapp: payload.receiver.whatsapp_number || payload.receiver.phone_number,
      delivery_address: payload.receiver.address,
      delivery_city: payload.receiver.city || targetCity,
      delivery_state: payload.receiver.state || "Federal Capital Territory",
      delivery_lga: payload.receiver.lga || "Abuja Municipal (AMAC)",
      landmark: payload.receiver.landmark || null,
      latitude: payload.receiver.latitude || null,
      longitude: payload.receiver.longitude || null,
      delivery_notes: payload.package_summary?.special_instructions || null,
      status: "order_placed",
      payment_type: "prepaid",
      payment_status: "paid",
      payment_method: payload.payment_receipt?.gateway || "paystack",
      total_amount: totalLogisticsFee,
      client_delivery_fee: totalLogisticsFee,
      agent_entitlement: riderAllowance,
      pickup_stops_count: pickupCount,
      additional_pickup_fee: extraStopFee,
      rider_pickup_allowance: riderAllowance,
      delivery_otp: deliveryOtp,
      distribution_center_id: matchedDc.id,
      payment_receipt_ref: payload.payment_receipt?.receipt_number || null,
      payment_gateway: payload.payment_receipt?.gateway || "paystack",
      is_pod: false,
    };

    const { data: newOrder, error: orderInsertErr } = await supabaseClient
      .from("orders")
      .insert(orderInsertPayload)
      .select("id, order_number, created_at")
      .single();

    if (orderInsertErr || !newOrder) {
      return new Response(
        JSON.stringify({ error: "Failed to persist order.", details: orderInsertErr }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. Insert Multi-Stop Itineraries into public.client_package_pickups
    const pickupsPayload = payload.pickup_stops.map((stop, idx) => ({
      order_id: newOrder.id,
      stop_sequence: idx + 1,
      stop_label: `Stop ${String.fromCharCode(65 + idx)}: ${stop.location_name}`,
      location_id: stop.location_id,
      location_name: stop.location_name,
      pickup_address: stop.pickup_address,
      city: stop.city || targetCity,
      state: stop.state || "Federal Capital Territory",
      lga: stop.lga || null,
      landmark: stop.landmark || null,
      latitude: stop.latitude || null,
      longitude: stop.longitude || null,
      contact_person: stop.contact_person,
      contact_phone: stop.contact_phone,
      contact_whatsapp: stop.contact_whatsapp || stop.contact_phone,
      items_to_collect: stop.items_to_collect || [],
      sealed_bag_ref: stop.sealed_bag_ref,
      status: "pending",
    }));

    const { error: pickupsInsertErr } = await supabaseClient
      .from("client_package_pickups")
      .insert(pickupsPayload);

    if (pickupsInsertErr) {
      console.error("Error inserting pickup stops:", pickupsInsertErr);
    }

    // 9. Respond with 201 Created
    const responseBody = {
      success: true,
      tracking_number: newOrder.order_number,
      order_reference: payload.order_reference,
      status: "order_placed",
      assigned_hub: {
        hub_id: matchedDc.id,
        hub_name: matchedDc.name,
        hub_phone: matchedDc.phone,
      },
      logistics_pricing: {
        currency: "NGN",
        base_flat_rate: baseRate,
        additional_pickup_fee: extraStopFee,
        pickup_stops_count: pickupCount,
        total_logistics_fee: totalLogisticsFee,
      },
      estimated_delivery_time: "35 - 45 mins",
      live_tracking_url: `https://novaexpress.ng/track/${newOrder.order_number}`,
      created_at: newOrder.created_at,
    };

    return new Response(JSON.stringify(responseBody), {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Internal server error.", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
