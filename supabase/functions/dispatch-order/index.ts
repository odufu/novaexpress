import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DispatchRequest {
  orderId?: string;
  deliveryState?: string;
  deliveryLga?: string;
  deliveryAddress?: string;
  productName?: string;
  quantity?: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body: DispatchRequest = await req.json().catch(() => ({}));
    const { orderId } = body;

    let deliveryState = body.deliveryState?.trim() ?? "";
    let deliveryLga = body.deliveryLga?.trim() ?? "";
    let orderRecord: any = null;

    if (orderId) {
      const { data: ord, error: ordErr } = await supabase
        .from("orders")
        .select("*")
        .eq("id", orderId)
        .single();

      if (ordErr || !ord) {
        return new Response(
          JSON.stringify({ success: false, error: `Order not found: ${ordErr?.message}` }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      orderRecord = ord;
      deliveryState = (ord.delivery_state || ord.destination_state || deliveryState || "").trim();
      deliveryLga = (ord.delivery_lga || ord.lga || deliveryLga || "").trim();
    }

    // 1. Fetch Grand DC (HQ)
    const { data: grandDcs } = await supabase
      .from("distribution_centers")
      .select("*")
      .eq("is_grand_dc", true)
      .eq("is_active", true)
      .limit(1);

    const grandDc = grandDcs && grandDcs.length > 0 ? grandDcs[0] : null;

    // 2. Fetch all active DCs
    const { data: allDcs, error: dcErr } = await supabase
      .from("distribution_centers")
      .select("*")
      .eq("is_active", true);

    if (dcErr) {
      throw new Error(`Failed to load DCs: ${dcErr.message}`);
    }

    // Helper for matching LGA in DC's operating_zones
    const normalize = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");

    let matchedDc: any = null;
    const cleanLga = normalize(deliveryLga);
    const cleanState = normalize(deliveryState);

    if (allDcs && allDcs.length > 0) {
      // Priority 1: Match by state + LGA
      matchedDc = allDcs.find((dc: any) => {
        const dcState = normalize(dc.state || "");
        if (dcState !== cleanState && !cleanState.includes(dcState) && !dcState.includes(cleanState)) {
          return false;
        }
        const zones: string[] = Array.isArray(dc.operating_zones) ? dc.operating_zones : [];
        return zones.some((z: string) => {
          const cz = normalize(z);
          return cz === cleanLga || cleanLga.includes(cz) || cz.includes(cleanLga);
        });
      });

      // Priority 2: Fallback to State matching DC
      if (!matchedDc) {
        matchedDc = allDcs.find((dc: any) => {
          const dcState = normalize(dc.state || "");
          return dcState === cleanState || cleanState.includes(dcState) || dcState.includes(cleanState);
        });
      }
    }

    // FALLBACK A: No DC matches State/LGA -> Escalate to Grand DC
    if (!matchedDc) {
      const targetDc = grandDc || (allDcs && allDcs[0]) || { id: "dc-hq-fallback", name: "Grand DC National HQ" };
      const dispatchNotes = `🚨 Escalated to Grand DC (${targetDc.name}). No DC configured for State: "${deliveryState}", LGA: "${deliveryLga}".`;

      if (orderId) {
        await supabase
          .from("orders")
          .update({
            distribution_center_id: targetDc.id,
            assigned_agent_id: null,
            status: "pending_dispatch",
            assignment_status: "pending_dc_assignment",
            routing_notes: dispatchNotes,
            updated_at: new Date().toISOString(),
          })
          .eq("id", orderId);
      }

      return new Response(
        JSON.stringify({
          success: true,
          status: "pending_dc_assignment",
          distributionCenterId: targetDc.id,
          distributionCenterName: targetDc.name,
          isGrandDc: true,
          assignedAgentId: null,
          routingNotes: dispatchNotes,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Find active riders attached to matched DC covering this LGA
    const { data: allDrivers, error: driverErr } = await supabase
      .from("delivery_agents")
      .select("*, users(first_name, last_name, phone_number, email)")
      .eq("is_active", true)
      .eq("current_status", "active");

    if (driverErr) {
      throw new Error(`Failed to load fleet riders: ${driverErr.message}`);
    }

    let matchedDriver: any = null;
    if (allDrivers && allDrivers.length > 0) {
      const dcDrivers = allDrivers.filter((d: any) => {
        return !d.distribution_center_id || d.distribution_center_id === matchedDc.id;
      });

      matchedDriver = dcDrivers.find((d: any) => {
        const lgas: string[] = Array.isArray(d.covered_lgas) ? d.covered_lgas : [];
        if (lgas.length > 0) {
          return lgas.some((l: string) => {
            const cl = normalize(l);
            return cl === cleanLga || cleanLga.includes(cl) || cl.includes(cleanLga);
          });
        }
        const city = normalize(d.operating_city || "");
        return city === cleanLga || cleanLga.includes(city) || city.includes(cleanLga);
      });
    }

    // SUCCESS: Rider found covering the LGA
    if (matchedDriver) {
      const riderName = matchedDriver.users
        ? `${matchedDriver.users.first_name || ""} ${matchedDriver.users.last_name || ""}`.trim()
        : matchedDriver.agent_code;
      const dispatchNotes = `✅ Auto-assigned to ${riderName} (${matchedDriver.agent_code}) at ${matchedDc.name} covering LGA: "${deliveryLga}".`;

      if (orderId) {
        await supabase
          .from("orders")
          .update({
            distribution_center_id: matchedDc.id,
            assigned_agent_id: matchedDriver.id,
            status: "assigned",
            assignment_status: "auto_assigned",
            routing_notes: dispatchNotes,
            assigned_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", orderId);
      }

      return new Response(
        JSON.stringify({
          success: true,
          status: "auto_assigned",
          distributionCenterId: matchedDc.id,
          distributionCenterName: matchedDc.name,
          assignedAgentId: matchedDriver.id,
          assignedAgentCode: matchedDriver.agent_code,
          assignedAgentName: riderName,
          routingNotes: dispatchNotes,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // FALLBACK B: DC matched, but no rider covers this LGA -> Route to Station DC for manual rider dispatch
    const dispatchNotes = `⚠️ Routed to ${matchedDc.name}. Awaiting manual rider assignment for LGA: "${deliveryLga}".`;

    if (orderId) {
      await supabase
        .from("orders")
        .update({
          distribution_center_id: matchedDc.id,
          assigned_agent_id: null,
          status: "pending_dispatch",
          assignment_status: "pending_rider_assignment",
          routing_notes: dispatchNotes,
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId);
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: "pending_rider_assignment",
        distributionCenterId: matchedDc.id,
        distributionCenterName: matchedDc.name,
        assignedAgentId: null,
        routingNotes: dispatchNotes,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
