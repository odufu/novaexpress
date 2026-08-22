import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface GeocodeRequestPayload {
  orderId?: string;
  address?: string;
  city?: string;
  state?: string;
  country?: string;
  autoDispatch?: boolean;
  maxDistanceKm?: number;
}

// Built-in high-precision Nigerian city & landmark centroids fallback
const NIGERIAN_CENTROIDS: Record<string, { lat: number; lng: number; confidence: number; label: string }> = {
  // Lagos Locations
  "lekki": { lat: 6.4474, lng: 3.4839, confidence: 0.85, label: "Lekki Phase 1, Lagos, Nigeria" },
  "lekki phase 1": { lat: 6.4474, lng: 3.4839, confidence: 0.90, label: "Admiralty Way, Lekki Phase 1, Lagos, Nigeria" },
  "ikeja": { lat: 6.5922, lng: 3.3556, confidence: 0.85, label: "Ikeja GRA, Lagos, Nigeria" },
  "ikeja gra": { lat: 6.5922, lng: 3.3556, confidence: 0.90, label: "Isaac John St, Ikeja GRA, Lagos, Nigeria" },
  "victoria island": { lat: 6.4281, lng: 3.4219, confidence: 0.90, label: "Victoria Island, Lagos, Nigeria" },
  "vi": { lat: 6.4281, lng: 3.4219, confidence: 0.85, label: "Victoria Island, Lagos, Nigeria" },
  "yaba": { lat: 6.5095, lng: 3.3711, confidence: 0.85, label: "Yaba, Commercial Ave, Lagos, Nigeria" },
  "surulere": { lat: 6.4975, lng: 3.3554, confidence: 0.85, label: "Surulere, Adeniran Ogunsanya, Lagos, Nigeria" },
  "festac": { lat: 6.4678, lng: 3.2833, confidence: 0.80, label: "Festac Town, Lagos, Nigeria" },
  "lagos": { lat: 6.5244, lng: 3.3792, confidence: 0.60, label: "Lagos State, Nigeria" },

  // Abuja Locations
  "wuse": { lat: 9.0765, lng: 7.4832, confidence: 0.85, label: "Wuse 2, Abuja, Nigeria" },
  "wuse 2": { lat: 9.0765, lng: 7.4832, confidence: 0.90, label: "Aminu Kano Cres, Wuse 2, Abuja, Nigeria" },
  "garki": { lat: 9.0345, lng: 7.4891, confidence: 0.85, label: "Area 11, Garki, Abuja, Nigeria" },
  "garki 2": { lat: 9.0345, lng: 7.4891, confidence: 0.85, label: "Garki 2, Abuja, Nigeria" },
  "maitama": { lat: 9.0882, lng: 7.4933, confidence: 0.90, label: "Maitama, Abuja, Nigeria" },
  "asokoro": { lat: 9.0435, lng: 7.5255, confidence: 0.90, label: "Asokoro, Abuja, Nigeria" },
  "gwarinpa": { lat: 9.1108, lng: 7.4116, confidence: 0.85, label: "Gwarinpa Estate, Abuja, Nigeria" },
  "abuja": { lat: 9.0765, lng: 7.3986, confidence: 0.65, label: "Federal Capital Territory, Abuja, Nigeria" },

  // Other Major Cities
  "port harcourt": { lat: 4.8156, lng: 7.0498, confidence: 0.80, label: "Port Harcourt, Rivers State, Nigeria" },
  "ibadan": { lat: 7.3775, lng: 3.9470, confidence: 0.80, label: "Ibadan, Oyo State, Nigeria" },
  "kano": { lat: 12.0022, lng: 8.5920, confidence: 0.80, label: "Kano, Kano State, Nigeria" },
  "benin city": { lat: 6.3350, lng: 5.6037, confidence: 0.80, label: "Benin City, Edo State, Nigeria" },
};

function cleanNigerianAddress(rawAddress: string): string {
  return rawAddress
    .replace(/\b(0[789][01]\d{8}|\+?234\d{10})\b/g, "")
    .replace(/(?i)\b(call|contact|deliver|reach|urgent|please|before|after|near|behind|opposite|beside)\b.*/g, "")
    .replace(/[,;]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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

    const payload: GeocodeRequestPayload = await req.json();

    let targetAddress = payload.address || "";
    let targetCity = payload.city || "";
    let targetState = payload.state || "";
    let companyId: string | null = null;
    let distributionCenterId: string | null = null;

    // 1. If orderId is provided, fetch latest order from database
    if (payload.orderId) {
      const { data: order, error: orderError } = await supabaseClient
        .from("orders")
        .select("id, delivery_address, delivery_city, delivery_state, landmark, company_id, distribution_center_id, latitude, longitude")
        .eq("id", payload.orderId)
        .single();

      if (orderError || !order) {
        return new Response(
          JSON.stringify({ error: "Order not found.", details: orderError }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      targetAddress = order.delivery_address;
      targetCity = order.delivery_city || targetCity;
      targetState = order.delivery_state || targetState;
      companyId = order.company_id;
      distributionCenterId = order.distribution_center_id;
    }

    if (!targetAddress && !targetCity && !targetState) {
      return new Response(
        JSON.stringify({ error: "Address information missing. Please provide address or valid orderId." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Synthesize cleaned query
    const cleaned = cleanNigerianAddress(targetAddress);
    const queryParts = [cleaned];
    if (targetCity && !cleaned.toLowerCase().includes(targetCity.toLowerCase())) {
      queryParts.push(targetCity);
    }
    if (targetState && !cleaned.toLowerCase().includes(targetState.toLowerCase())) {
      queryParts.push(targetState);
    }
    queryParts.push("Nigeria");
    const synthesizedQuery = queryParts.filter(Boolean).join(", ");

    let resolvedLat: number | null = null;
    let resolvedLng: number | null = null;
    let resolvedAddress = synthesizedQuery;
    let confidence = 0.0;
    let status = "pending";

    // 3. Multi-Tier Resolution
    // Tier 1: Try OpenStreetMap Nominatim Live Geocoding
    try {
      const encoded = encodeURIComponent(synthesizedQuery);
      const url = `https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&countrycodes=ng&limit=1`;
      const geoResp = await fetch(url, {
        headers: { "User-Agent": "NoveXPS-Logistics/1.0 (contact@novaexpress.ng)" },
      });

      if (geoResp.ok) {
        const results = await geoResp.json();
        if (Array.isArray(results) && results.length > 0) {
          const first = results[0];
          resolvedLat = parseFloat(first.lat);
          resolvedLng = parseFloat(first.lon);
          resolvedAddress = first.display_name || synthesizedQuery;
          confidence = 0.95;
          status = "exact_verified";
        }
      }
    } catch (err) {
      console.warn("[GEOCODE] Nominatim query notice:", err);
    }

    // Tier 2: Heuristic Sub-zone & Landmark Dictionary Match
    if (!resolvedLat || !resolvedLng) {
      const searchKey = `${cleaned} ${targetCity} ${targetState}`.toLowerCase();
      for (const [key, centroid] of Object.entries(NIGERIAN_CENTROIDS)) {
        if (searchKey.includes(key)) {
          resolvedLat = centroid.lat;
          resolvedLng = centroid.lng;
          resolvedAddress = centroid.label;
          confidence = centroid.confidence;
          status = centroid.confidence >= 0.85 ? "landmark_match" : "locality_fallback";
          break;
        }
      }
    }

    // Tier 3: State Centroid Fallback
    if (!resolvedLat || !resolvedLng) {
      const stateKey = (targetState || targetCity || "lagos").toLowerCase();
      for (const [key, centroid] of Object.entries(NIGERIAN_CENTROIDS)) {
        if (stateKey.includes(key)) {
          resolvedLat = centroid.lat;
          resolvedLng = centroid.lng;
          resolvedAddress = centroid.label;
          confidence = 0.50;
          status = "locality_fallback";
          break;
        }
      }
    }

    // Default Fallback to Central DC if entirely unresolved
    if (!resolvedLat || !resolvedLng) {
      resolvedLat = 6.4474;
      resolvedLng = 3.4839;
      resolvedAddress = `${targetAddress}, ${targetCity}, ${targetState}, Nigeria`;
      confidence = 0.30;
      status = "locality_fallback";
    }

    // 4. Update Database if orderId was provided
    let autoDispatchResult = null;
    if (payload.orderId) {
      const { error: updateError } = await supabaseClient
        .from("orders")
        .update({
          latitude: resolvedLat,
          longitude: resolvedLng,
          geocoded_address: resolvedAddress,
          location_confidence: confidence,
          geocoding_status: status,
          updated_at: new Date().toISOString(),
        })
        .eq("id", payload.orderId);

      if (updateError) {
        console.error("[GEOCODE] Database update error:", updateError);
      }

      // 5. Automatic Proximity Dispatch (if requested)
      if (payload.autoDispatch === true) {
        const { data: dispatchData, error: dispatchError } = await supabaseClient.rpc("auto_dispatch_order", {
          p_order_id: payload.orderId,
          p_max_distance_km: payload.maxDistanceKm || 25.0,
        });

        if (dispatchError) {
          console.warn("[GEOCODE] Auto-dispatch RPC error:", dispatchError);
        } else {
          autoDispatchResult = dispatchData;
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId: payload.orderId,
        latitude: resolvedLat,
        longitude: resolvedLng,
        geocodedAddress: resolvedAddress,
        locationConfidence: confidence,
        geocodingStatus: status,
        synthesizedQuery: synthesizedQuery,
        autoDispatch: autoDispatchResult,
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
