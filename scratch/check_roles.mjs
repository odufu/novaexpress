const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function check() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const res = await fetch(`${baseUrl}/users?select=role`, { headers });
  const users = await res.json();
  const roles = [...new Set(users.map(u => u.role))];
  console.log('Distinct roles in users table:', roles);
}

check().catch(console.error);
