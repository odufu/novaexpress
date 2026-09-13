const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function checkMigrations() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  // Check if supabase_migrations table is accessible via postgrest
  // Usually it is not exposed in public schema
  // Let's create an RPC or check functions
  const res = await fetch(`${baseUrl}/rpc/get_order_pipeline_chat`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_order_id: '3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0' })
  });
  console.log('get_order_pipeline_chat status:', res.status);
  const data = await res.json();
  console.log('get_order_pipeline_chat result exists?', !!data);
}

checkMigrations().catch(console.error);
