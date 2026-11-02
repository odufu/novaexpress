
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMDE0NzIsImV4cCI6MjEwNzY3NzQ3Mn0.B1epG9i_R1pryMVFo78DcL-Ett21L3HR_4VST34QifA';
const baseUrl = 'https://hwyqqjilcifxajruusoa.supabase.co';

async function test() {
  const headers = {
    apikey: serviceKey,
    Authorization: 'Bearer ' + serviceKey
  };

  const cleanId = '22222222-2222-4222-8222-222222222222';

  // 1. Check DC
  const dcRes = await fetch(baseUrl + '/rest/v1/distribution_centers?id=eq.' + cleanId + '&select=id,name', { headers });
  const dc = await dcRes.json();
  console.log('1. DC:', dc);

  // 2. Check delivery_agents
  const daRes = await fetch(baseUrl + '/rest/v1/delivery_agents?distribution_center_id=eq.' + cleanId + '&select=id', { headers });
  const das = await daRes.json();
  console.log('2. Delivery agents response:', das);
  if (Array.isArray(das)) for (const d of das) {
    console.log('  Agent:', d.id, d.full_name, d.driver_code);
  }

  // 3. Test simple DC query
  const simpleRes = await fetch(baseUrl + '/rest/v1/cash_remittances?distribution_center_id=eq.' + cleanId + '&select=*&order=created_at.desc', { headers });
  console.log('3. Simple DC Query HTTP Status:', simpleRes.status);
  const simpleData = await simpleRes.json();
  console.log('  Simple DC Query count:', Array.isArray(simpleData) ? simpleData.length : simpleData);
  if (Array.isArray(simpleData)) {
    for (const r of simpleData) {
      console.log('    REM:', r.id, r.status, r.amount, 'agent:', r.delivery_agent_id, 'created:', r.created_at);
    }
  }

  // 4. Test sign in as joelfinances and test RLS
  const authRes = await fetch(baseUrl + '/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: {
      apikey: anonKey,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: 'joelfinances@gmail.com',
      password: 'Password123!'
    })
  });
  console.log('4. Sign-in status:', authRes.status);
  const authData = await authRes.json();
  if (authData.access_token) {
    console.log('  User signed in:', authData.user.email);
    const userHeaders = {
      apikey: anonKey,
      Authorization: 'Bearer ' + authData.access_token
    };
    const userQueryRes = await fetch(baseUrl + '/rest/v1/cash_remittances?select=*&order=created_at.desc', { headers: userHeaders });
    console.log('  User query status:', userQueryRes.status);
    const userRemData = await userQueryRes.json();
    console.log('  User query count:', Array.isArray(userRemData) ? userRemData.length : userRemData);
    if (Array.isArray(userRemData)) {
      for (const r of userRemData) {
        console.log('    USER REM:', r.id, r.status, r.amount, 'agent:', r.delivery_agent_id, 'dc:', r.distribution_center_id);
      }
    }
  } else {
    console.log('  Sign-in failed:', authData);
  }
}

test().catch(console.error);
