import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface TelemetryPayload {
  agentId: string;
  latitude: number;
  longitude: number;
  isOnDuty?: boolean;
  batteryLevel?: number;
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

    const payload: TelemetryPayload = await req.json();

    if (!payload.agentId || payload.latitude === undefined || payload.longitude === undefined) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: agentId, latitude, and longitude are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error: rpcError } = await supabaseClient.rpc("update_rider_gps_telemetry", {
      p_agent_id: payload.agentId,
      p_latitude: payload.latitude,
      p_longitude: payload.longitude,
    });

    if (rpcError) {
      // Direct update fallback if RPC is not loaded
      await supabaseClient
        .from("delivery_agents")
        .update({
          current_latitude: payload.latitude,
          current_longitude: payload.longitude,
          last_location_update: new Date().toISOString(),
          if (payload.isOnDuty !== undefined) is_on_duty: payload.isOnDuty,
        })
        .eq("id", payload.agentId);
    }

    return new Response(
      JSON.stringify({
        success: true,
        agentId: payload.agentId,
        latitude: payload.latitude,
        longitude: payload.longitude,
        timestamp: new Date().toISOString(),
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
