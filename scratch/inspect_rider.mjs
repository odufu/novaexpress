const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function test() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  // Check rider cd6b53b0-5203-48f3-ae9b-81c6a0e9e5f3
  const res = await fetch(`${baseUrl}/delivery_agents?id=eq.cd6b53b0-5203-48f3-ae9b-81c6a0e9e5f3`, { headers });
  const agent = (await res.json())[0];
  console.log('Agent:', agent);
}

test().catch(console.error);
