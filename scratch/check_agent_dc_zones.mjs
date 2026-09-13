import fs from 'fs';

const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function run() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const agentsRes = await fetch(`${baseUrl}/delivery_agents?select=id,agent_code,distribution_center_id,operating_state,operating_city,covered_lgas,current_status,is_on_duty,is_active`, { headers });
  const agents = await agentsRes.json();

  const dcsRes = await fetch(`${baseUrl}/distribution_centers?select=id,name,state,city,operating_zones,is_hub,is_grand_dc,is_active`, { headers });
  const dcs = await dcsRes.json();

  let out = '=== DELIVERY AGENTS ===\n';
  for (const a of agents) {
    out += `ID: ${a.id} | Code: ${a.agent_code} | DC: ${a.distribution_center_id} | State: ${a.operating_state} | City: ${a.operating_city} | LGAs: ${JSON.stringify(a.covered_lgas)} | Status: ${a.current_status} | OnDuty: ${a.is_on_duty} | Active: ${a.is_active}\n`;
  }

  out += '\n=== DISTRIBUTION CENTERS ===\n';
  for (const d of dcs) {
    out += `ID: ${d.id} | Name: ${d.name} | State: ${d.state} | City: ${d.city} | Zones: ${JSON.stringify(d.operating_zones)} | Hub: ${d.is_hub} | Grand: ${d.is_grand_dc} | Active: ${d.is_active}\n`;
  }

  fs.writeFileSync('scratch/check_agent_dc_zones_output.txt', out, 'utf-8');
  console.log('Successfully wrote scratch/check_agent_dc_zones_output.txt');
}

run().catch(console.error);
