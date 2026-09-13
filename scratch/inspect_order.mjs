const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function test() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const res = await fetch(`${baseUrl}/orders?id=eq.3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0`, { headers });
  const order = (await res.json())[0];
  console.log('Order:', {
    id: order.id,
    order_number: order.order_number,
    delivery_state: order.delivery_state,
    delivery_city: order.delivery_city,
    delivery_lga: order.delivery_lga,
    lga: order.lga,
    distribution_center_id: order.distribution_center_id,
    routing_notes: order.routing_notes
  });
}

test().catch(console.error);
