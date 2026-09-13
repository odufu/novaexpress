const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function testQuery() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const dcId = '00000000-0000-4000-8000-788825051520';
  
  // Test 1: filter by dc_id and active and duty
  const r1 = await fetch(`${baseUrl}/delivery_agents?distribution_center_id=eq.${dcId}&is_active=eq.true&is_on_duty=eq.true`, { headers });
  const agents1 = await r1.json();
  console.log('Test 1 (DC + Active + OnDuty): count =', agents1.length);
  for (const a of agents1) {
    console.log(`- ${a.agent_code}: current_status="${a.current_status}", covered_lgas contains Otukpo? ${JSON.stringify(a.covered_lgas).includes('Otukpo')}`);
  }
}

testQuery().catch(console.error);
