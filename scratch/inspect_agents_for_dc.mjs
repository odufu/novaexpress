const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

// We can query pg_proc via a custom rpc or inspect migrations
// Or let's test executing the query against delivery_agents directly
async function testAgentQuery() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const dcId = '00000000-0000-4000-8000-788825051520';
  const lga = 'Otukpo';

  // Test what matches
  const res = await fetch(`${baseUrl}/delivery_agents?distribution_center_id=eq.${dcId}&is_active=eq.true&is_on_duty=eq.true`, { headers });
  const rows = await res.json();
  console.log('Riders for DC:', rows.map(r => ({
    code: r.agent_code,
    status: r.current_status,
    lgas: r.covered_lgas,
    city: r.operating_city
  })));
}

testAgentQuery().catch(console.error);
