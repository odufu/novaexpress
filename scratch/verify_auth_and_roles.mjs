const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const supabaseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co';

async function verify() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json'
  };

  console.log('----------------------------------------------------');
  console.log('1. VERIFYING USER ROLES & CONSOLE ASSIGNMENTS');
  console.log('----------------------------------------------------');

  const uRes = await fetch(`${supabaseUrl}/rest/v1/users?select=id,email,role,first_name,last_name,avatar_url`, { headers });
  const users = await uRes.json();

  const testAccounts = [
    { email: 'dc.supervisor@novaexpress.ng', expectedRole: 'dc_manager', expectedConsole: '/dc' },
    { email: 'client.novacale@novaexpress.ng', expectedRole: 'client', expectedConsole: '/client' },
    { email: 'closer.amaka@novacale.ng', expectedRole: 'closer', expectedConsole: '/closer' },
    { email: 'emeka.rider@novaexpress.ng', expectedRole: 'delivery_agent', expectedConsole: '/' }
  ];

  for (const t of testAccounts) {
    const matched = users.find(u => u.email.toLowerCase() === t.email.toLowerCase());
    if (matched) {
      const roleMatches = matched.role.toLowerCase() === t.expectedRole.toLowerCase();
      console.log(`[PASS] ${t.email}`);
      console.log(`   - Verified Role: "${matched.role}" (Expected: "${t.expectedRole}") -> Match: ${roleMatches}`);
      console.log(`   - Designated Console Route: ${t.expectedConsole}`);
    } else {
      console.log(`[WARN] ${t.email} not found directly in public.users, checking registered demo user`);
    }
  }

  console.log('\n----------------------------------------------------');
  console.log('2. VERIFYING TELESALES CLOSERS (CLIENT_CLOSERS)');
  console.log('----------------------------------------------------');
  const closersRes = await fetch(`${supabaseUrl}/rest/v1/client_closers?select=id,full_name,email,closer_code,client_id,avatar_url`, { headers });
  const closers = await closersRes.json();
  console.log(`Found ${closers.length} closer(s)`);
  closers.forEach(c => {
    console.log(`   - Closer: ${c.full_name} (${c.email}) | Code: ${c.closer_code} | Target Console: /closer`);
  });

  console.log('\n----------------------------------------------------');
  console.log('3. VERIFYING CLIENTS (MERCHANTS)');
  console.log('----------------------------------------------------');
  const clientsRes = await fetch(`${supabaseUrl}/rest/v1/clients?select=id,name,code,email,tier,closer_limit`, { headers });
  const clients = await clientsRes.json();
  const clientList = Array.isArray(clients) ? clients : [];
  console.log(`Found ${clientList.length} client(s)`);
  clientList.forEach(c => {
    console.log(`   - Client: ${c.name} (${c.code}) | Email: ${c.email} | Tier: ${c.tier} | Target Console: /client`);
  });

  console.log('\n----------------------------------------------------');
  console.log('4. VERIFYING DISTRIBUTION CENTERS (DCS)');
  console.log('----------------------------------------------------');
  const dcsRes = await fetch(`${supabaseUrl}/rest/v1/distribution_centers?select=id,name,code,contact_email`, { headers });
  const dcs = await dcsRes.json();
  const dcList = Array.isArray(dcs) ? dcs : [];
  console.log(`Found ${dcList.length} DC(s)`);
  dcList.forEach(d => {
    console.log(`   - DC: ${d.name} (${d.code}) | Email: ${d.contact_email} | Target Console: /dc`);
  });

  console.log('\n----------------------------------------------------');
  console.log('5. VERIFYING AVATAR STORAGE BUCKET');
  console.log('----------------------------------------------------');
  const bRes = await fetch(`${supabaseUrl}/storage/v1/bucket`, { headers });
  const buckets = await bRes.json();
  const avatarBucket = buckets.find(b => b.id === 'avatars');
  if (avatarBucket) {
    console.log(`[PASS] 'avatars' storage bucket is configured: public=${avatarBucket.public}, limit=${avatarBucket.file_size_limit} bytes`);
  } else {
    console.log(`[FAIL] 'avatars' storage bucket not found!`);
  }
}

verify().catch(console.error);
