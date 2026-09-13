const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const supabaseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co';

const MAIN_DC_ID = '22222222-2222-4222-8222-222222222222';
const MAIN_DC_CODE = 'DC-WUSE-01';
const SUPERVISOR_EMAIL = 'dc.supervisor@novaexpress.ng';
const SUPERVISOR_USER_ID = 'a2222222-2222-4222-8222-222222222222';

async function purge() {
  const headers = {
    apikey: serviceKey,
    Authorization: 'Bearer ' + serviceKey,
    'Content-Type': 'application/json',
    Prefer: 'return=representation'
  };

  console.log('====================================================');
  console.log('🚀 EXECUTING DATABASE PURGE (PRESERVING MAIN DC & SUPERVISOR)');
  console.log('====================================================\n');

  async function deleteFromTable(table, filter = '') {
    const url = `${supabaseUrl}/rest/v1/${table}${filter ? '?' + filter : ''}`;
    try {
      const res = await fetch(url, {
        method: 'DELETE',
        headers
      });
      console.log(`[DELETE] ${table}: HTTP ${res.status}`);
      return res.status;
    } catch (e) {
      console.error(`[ERROR] ${table}:`, e);
    }
  }

  // 1. Delete Chat Messages & Conversations
  console.log('1. Purging Chat & Conversations...');
  await deleteFromTable('conversation_messages', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('order_conversations', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 2. Delete Orders & Order Items
  console.log('\n2. Purging Orders & Order Items...');
  await deleteFromTable('order_items', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('orders', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 3. Delete Cash Remittances & Financial Records
  console.log('\n3. Purging Remittances & Financial Ledgers...');
  await deleteFromTable('cash_remittances', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('paystack_transactions', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('rider_transactions', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('payout_requests', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('client_settlements', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 4. Delete Stock & Inventory Records
  console.log('\n4. Purging Stock & Inventory...');
  await deleteFromTable('stock_transfer_items', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('stock_transfer_requests', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('stock_transfers', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('rider_stock_allocations', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('inventory_audit_items', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('inventory_audits', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('product_stock_custody', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('stock_items', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 5. Delete Products & Packages
  console.log('\n5. Purging Product Packages & Products...');
  await deleteFromTable('product_packages', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('products', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 6. Delete Operational Notifications
  console.log('\n6. Purging Notifications...');
  await deleteFromTable('notifications', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 7. Delete Sales Closers, Clients, Delivery Agents
  console.log('\n7. Purging Sales Closers, Clients, Delivery Agents...');
  await deleteFromTable('client_closers', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('clients', 'id=neq.00000000-0000-0000-0000-000000000000');
  await deleteFromTable('delivery_agents', 'id=neq.00000000-0000-0000-0000-000000000000');

  // 8. Delete Non-Main Distribution Centers
  console.log('\n8. Removing Non-Main Distribution Centers...');
  await deleteFromTable('distribution_centers', `code=neq.${MAIN_DC_CODE}&id=neq.${MAIN_DC_ID}`);

  // 9. Clean up public.users (Keep ONLY the Main DC Supervisor)
  console.log('\n9. Pruning public.users (Preserving Main DC Supervisor)...');
  await deleteFromTable('users', `email=neq.${SUPERVISOR_EMAIL}`);

  // 10. Clean up auth.users (Keep ONLY dc.supervisor@novaexpress.ng if present, otherwise delete others)
  console.log('\n10. Pruning auth.users Admin API...');
  const authRes = await fetch(`${supabaseUrl}/auth/v1/admin/users?per_page=100`, { headers });
  const authData = await authRes.json();
  const authUsers = authData.users || [];
  let supervisorAuthUser = null;

  for (const u of authUsers) {
    if (u.email?.toLowerCase() === SUPERVISOR_EMAIL.toLowerCase()) {
      supervisorAuthUser = u;
      console.log(`  [KEEP] Auth User: ${u.email} (${u.id})`);
    } else {
      console.log(`  [DELETE] Auth User: ${u.email} (${u.id})...`);
      try {
        await fetch(`${supabaseUrl}/auth/v1/admin/users/${u.id}`, {
          method: 'DELETE',
          headers
        });
      } catch (e) {
        console.error(`  [ERROR] deleting auth user ${u.id}:`, e);
      }
    }
  }

  // 11. Ensure Main DC Supervisor Auth Account exists and has valid password
  console.log('\n11. Ensuring Main DC Supervisor Auth Account...');
  let effectiveAuthId = SUPERVISOR_USER_ID;
  if (!supervisorAuthUser) {
    console.log('  Creating fresh Supabase Auth account for dc.supervisor@novaexpress.ng...');
    const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        email: SUPERVISOR_EMAIL,
        password: 'Password123!',
        email_confirm: true,
        user_metadata: {
          first_name: 'Adekunle',
          last_name: 'Supervisor',
          role: 'dc_manager',
          distribution_center_id: MAIN_DC_ID
        }
      })
    });
    const created = await createRes.json();
    if (created.id) {
      effectiveAuthId = created.id;
      console.log(`  ✅ Created Auth account with ID: ${effectiveAuthId}`);
    } else {
      console.log('  Notice on create:', created);
    }
  } else {
    // Reset password to Password123! and ensure metadata
    console.log('  Updating supervisor password to Password123! and ensuring confirmed email...');
    await fetch(`${supabaseUrl}/auth/v1/admin/users/${supervisorAuthUser.id}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        password: 'Password123!',
        email_confirm: true,
        user_metadata: {
          first_name: 'Adekunle',
          last_name: 'Supervisor',
          role: 'dc_manager',
          distribution_center_id: MAIN_DC_ID
        }
      })
    });
    effectiveAuthId = supervisorAuthUser.id;
    console.log(`  ✅ Supervisor Auth account refreshed: ${effectiveAuthId}`);
  }

  // 12. Ensure Main DC Supervisor Profile in public.users
  console.log('\n12. Ensuring Main DC Supervisor in public.users...');
  const supervisorRow = {
    id: effectiveAuthId,
    email: SUPERVISOR_EMAIL,
    first_name: 'Adekunle',
    last_name: 'Supervisor',
    role: 'dc_manager',
    phone_number: '+2348039876543',
    distribution_center_id: MAIN_DC_ID,
    company_id: '11111111-1111-4111-8111-111111111111',
    is_active: true
  };

  const upsertRes = await fetch(`${supabaseUrl}/rest/v1/users`, {
    method: 'POST',
    headers: { ...headers, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify(supervisorRow)
  });
  console.log(`  [UPSERT] public.users: HTTP ${upsertRes.status}`);

  // 13. Ensure Main DC in public.distribution_centers
  console.log('\n13. Ensuring Main DC in public.distribution_centers...');
  const dcRow = {
    id: MAIN_DC_ID,
    code: MAIN_DC_CODE,
    name: 'Wuse Central Distribution Hub',
    address: 'Plot 482 Aminu Kano Crescent, Wuse 2, Abuja',
    city: 'Wuse 2',
    state: 'Abuja (FCT)',
    is_active: true,
    contact_email: SUPERVISOR_EMAIL,
    contact_phone: '+2348039876543',
    manager_name: 'Adekunle Supervisor',
    latitude: 9.0765,
    longitude: 7.4812,
    operating_hours: 'Mon-Sat: 07:00 - 20:00'
  };

  const dcUpsertRes = await fetch(`${supabaseUrl}/rest/v1/distribution_centers`, {
    method: 'POST',
    headers: { ...headers, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify(dcRow)
  });
  console.log(`  [UPSERT] public.distribution_centers: HTTP ${dcUpsertRes.status}`);

  console.log('\n====================================================');
  console.log('✅ DATABASE PURGE & RESET COMPLETE!');
  console.log('====================================================');
}

purge().catch(console.error);
