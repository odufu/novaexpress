const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function run() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json'
  };

  // Find an order
  const ordersRes = await fetch(`${baseUrl}/orders?delivery_state=ilike.*Benue*&limit=1`, { headers });
  const orders = await ordersRes.json();
  console.log('Found order:', orders[0]?.order_number, orders[0]?.id, 'State:', orders[0]?.delivery_state, 'LGA:', orders[0]?.lga, 'delivery_lga:', orders[0]?.delivery_lga);

  if (orders[0]) {
    const rpcRes = await fetch(`${baseUrl}/rpc/auto_dispatch_order_by_state_lga`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_order_id: orders[0].id })
    });
    const result = await rpcRes.json();
    console.log('Dispatch result:', result);
  }
}

run().catch(console.error);
