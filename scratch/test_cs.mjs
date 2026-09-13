const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function testAgents() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const dcId = '00000000-0000-4000-8000-788825051520';
  const lga = 'Otukpo';

  // Test query with ilike on covered_lgas::text
  // Can we do filter with covered_lgas=cs.["Otukpo"] ?
  const r1 = await fetch(`${baseUrl}/delivery_agents?distribution_center_id=eq.${dcId}&covered_lgas=cs.["${lga}"]`, { headers });
  console.log('Test with cs (contains array):', await r1.json());
}

testAgents().catch(console.error);
