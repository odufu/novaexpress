const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function testRiderTag() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation'
  };

  const orderId = '3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0';

  // DC Manager tags @Rider in chat
  const msgPayload = {
    conversation_id: '8bb70c10-0e8e-45e3-bc29-058b8b1da9c5',
    order_id: orderId,
    sender_name: 'Otukpo DC Dispatcher',
    sender_role: 'dc_manager',
    message_type: 'text',
    message_body: '@Rider Approved. Give customer 2-pack deal and collect ₦43,000.',
    read_by_client: false,
    read_by_dc: true,
    read_by_rider: false,
    created_at: new Date().toISOString()
  };

  const insertMsgRes = await fetch(`${baseUrl}/order_conversation_messages`, {
    method: 'POST',
    headers,
    body: JSON.stringify(msgPayload)
  });
  console.log('Insert Message Status:', insertMsgRes.status);

  // Verify notification created for rider
  const notifsRes = await fetch(`${baseUrl}/notifications?category=eq.chat&delivery_agent_id=eq.cd6b53b0-5203-48f3-ae9b-81c6a0e9e5f3&order=created_at.desc&limit=1`, { headers });
  const notifs = await notifsRes.json();
  console.log('Rider Notification:');
  console.log(notifs[0]);
}

testRiderTag().catch(console.error);
