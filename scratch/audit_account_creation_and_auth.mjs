const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const supabaseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co';

async function main() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json'
  };

  console.log('====================================================');
  console.log('AUDIT 1: DISTINCT ROLES & USER SAMPLE');
  console.log('====================================================');
  const uRes = await fetch(`${supabaseUrl}/rest/v1/users?select=id,email,phone_number,first_name,last_name,role,avatar_url,company_id,is_active`, { headers });
  const users = await uRes.json();
  console.log(`Total users in public.users: ${users.length}`);
  const roles = {};
  users.forEach(u => {
    roles[u.role] = (roles[u.role] || 0) + 1;
  });
  console.log('Roles breakdown:', JSON.stringify(roles, null, 2));
  console.log('Sample users:');
  users.forEach(u => {
    console.log(`  - [${u.role}] ${u.email} (${u.first_name} ${u.last_name}) | Avatar: ${u.avatar_url ? u.avatar_url.substring(0, 40) + '...' : 'NULL'}`);
  });

  console.log('\n====================================================');
  console.log('AUDIT 2: CLIENTS & CLOSER CAPACITY');
  console.log('====================================================');
  const cRes = await fetch(`${supabaseUrl}/rest/v1/clients?select=*`, { headers });
  const clients = await cRes.json();
  console.log(`Total clients: ${clients.length}`);
  clients.forEach(c => {
    console.log(`  - Client [${c.code}] ${c.name} | Tier: ${c.tier} | Closer Limit: ${c.closer_limit} | Contact: ${c.email}`);
  });

  console.log('\n====================================================');
  console.log('AUDIT 3: CLIENT CLOSERS (TELESALES CLOSERS)');
  console.log('====================================================');
  const clRes = await fetch(`${supabaseUrl}/rest/v1/client_closers?select=*`, { headers });
  const closers = await clRes.json();
  console.log(`Total closers: ${closers.length}`);
  closers.forEach(cl => {
    console.log(`  - Closer [${cl.closer_code}] ${cl.full_name} (${cl.email}) | User ID: ${cl.user_id} | Client ID: ${cl.client_id} | Avatar: ${cl.avatar_url ? cl.avatar_url.substring(0, 40) + '...' : 'NULL'}`);
  });

  console.log('\n====================================================');
  console.log('AUDIT 4: DELIVERY AGENTS (RIDERS)');
  console.log('====================================================');
  const daRes = await fetch(`${supabaseUrl}/rest/v1/delivery_agents?select=id,user_id,agent_code,vehicle_type,operating_state,operating_city,distribution_center_id,is_active`, { headers });
  const agents = await daRes.json();
  console.log(`Total delivery agents: ${agents.length}`);
  agents.forEach(a => {
    console.log(`  - Agent [${a.agent_code}] User: ${a.user_id} | DC: ${a.distribution_center_id} | State: ${a.operating_state} | Active: ${a.is_active}`);
  });

  console.log('\n====================================================');
  console.log('AUDIT 5: DISTRIBUTION CENTERS (DCS)');
  console.log('====================================================');
  const dcRes = await fetch(`${supabaseUrl}/rest/v1/distribution_centers?select=*`, { headers });
  const dcs = await dcRes.json();
  console.log(`Total DCs: ${dcs.length}`);
  dcs.forEach(dc => {
    console.log(`  - DC [${dc.code}] ${dc.name} | State: ${dc.state}, City: ${dc.city} | Email: ${dc.contact_email}`);
  });

  console.log('\n====================================================');
  console.log('AUDIT 6: STORAGE BUCKETS (DP / AVATARS / PROFILES)');
  console.log('====================================================');
  const bRes = await fetch(`${supabaseUrl}/storage/v1/bucket`, { headers });
  const buckets = await bRes.json();
  console.log('Storage Buckets:', JSON.stringify(buckets, null, 2));

  console.log('\n====================================================');
  console.log('AUDIT 7: AUTH USERS (AUTH.USERS VIA ADMIN API)');
  console.log('====================================================');
  const authUsersRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, { headers });
  const authUsers = await authUsersRes.json();
  if (authUsers && authUsers.users) {
    console.log(`Total auth.users: ${authUsers.users.length}`);
    authUsers.users.forEach(au => {
      console.log(`  - Auth User: ${au.email} (ID: ${au.id}) | Meta: ${JSON.stringify(au.user_metadata)} | AppMeta: ${JSON.stringify(au.app_metadata)}`);
    });
  } else {
    console.log('Auth users response:', JSON.stringify(authUsers).substring(0, 200));
  }
}

main().catch(console.error);
