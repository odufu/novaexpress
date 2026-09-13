const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function testDeliveryReport() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json'
  };

  const orderId = '3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0';

  // Update order to delivered
  await fetch(`${baseUrl}/orders?id=eq.${orderId}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({
      status: 'delivered',
      payment_status: 'collected',
      delivered_at: new Date().toISOString(),
      proof_of_delivery_url: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800'
    })
  });

  // Verify conversation messages
  const convRes = await fetch(`${baseUrl}/order_conversations?order_id=eq.${orderId}`, { headers });
  const conv = (await convRes.json())[0];
  console.log('Conversation status:', conv?.order_status, 'last_msg:', conv?.last_message_text);

  const msgRes = await fetch(`${baseUrl}/order_conversation_messages?conversation_id=eq.${conv.id}&order=created_at.desc&limit=3`, { headers });
  const msgs = await msgRes.json();
  console.log('Latest 3 messages:');
  for (const m of msgs) {
    console.log(`- [${m.message_type}] by ${m.sender_name}: "${m.message_body}"`);
  }
}

testDeliveryReport().catch(console.error);
