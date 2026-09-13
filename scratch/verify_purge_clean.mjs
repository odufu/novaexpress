const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const supabaseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co';

async function main() {
  const headers = {
    apikey: serviceKey,
    Authorization: 'Bearer ' + serviceKey,
    'Content-Type': 'application/json'
  };

  const tables = [
    'orders', 'cash_remittances', 'products', 'product_packages',
    'stock_transfers', 'stock_transfer_items',
    'paystack_transactions', 'rider_transactions', 'payout_requests', 'client_settlements',
    'order_conversations', 'notifications',
    'client_closers', 'clients', 'delivery_agents', 'distribution_centers', 'users'
  ];

  console.log('====================================================');
  console.log('📊 DATABASE POST-PURGE AUDIT REPORT');
  console.log('====================================================');

  for (const t of tables) {
    try {
      const res = await fetch(supabaseUrl + '/rest/v1/' + t + '?select=count', {
        headers: { ...headers, Prefer: 'count=exact' }
      });
      const countHeader = res.headers.get('content-range');
      const count = countHeader ? countHeader.split('/')[1] : '0';
      console.log(t.padEnd(25) + ': ' + count + ' record(s)');
    } catch (e) {
      console.log(t.padEnd(25) + ': error');
    }
  }

  const authRes = await fetch(supabaseUrl + '/auth/v1/admin/users?per_page=50', { headers });
  const authData = await authRes.json();
  const authUsers = authData.users || [];
  console.log('\n' + 'auth.users'.padEnd(25) + ': ' + authUsers.length + ' user(s)');
  authUsers.forEach(u => {
    console.log('   -> Email: ' + u.email + ' | ID: ' + u.id + ' | Role: ' + u.user_metadata?.role);
  });

  const dcRes = await fetch(supabaseUrl + '/rest/v1/distribution_centers?select=id,name,code,state,city,contact_email,manager_name', { headers });
  const dcs = await dcRes.json();
  console.log('\n' + 'Active DCs'.padEnd(25) + ': ' + dcs.length + ' DC(s)');
  dcs.forEach(dc => {
    console.log('   -> DC: ' + dc.name + ' (' + dc.code + ') | City: ' + dc.city + ', ' + dc.state + ' | Supervisor: ' + dc.manager_name + ' (' + dc.contact_email + ')');
  });

  const uRes = await fetch(supabaseUrl + '/rest/v1/users?select=id,email,first_name,last_name,role,distribution_center_id', { headers });
  const users = await uRes.json();
  console.log('\n' + 'Active Users'.padEnd(25) + ': ' + users.length + ' user(s)');
  users.forEach(u => {
    console.log('   -> User: ' + u.first_name + ' ' + u.last_name + ' (' + u.email + ') | Role: ' + u.role + ' | DC: ' + u.distribution_center_id);
  });
}
main().catch(console.error);
