const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function testTagging() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation'
  };

  const orderId = '3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0';

  // 1. Get conversation
  const convRes = await fetch(`${baseUrl}/order_conversations?order_id=eq.${orderId}`, { headers });
  const conv = (await convRes.json())[0];
  console.log('Conversation:', conv?.id, conv?.order_number, 'DC:', conv?.distribution_center_name, 'Rider:', conv?.delivery_agent_name);

  // 2. Rider tags @Operations in chat
  const msgPayload = {
    conversation_id: conv.id,
    order_id: orderId,
    sender_name: 'Joel Odufu (PDA-7437)',
    sender_role: 'delivery_agent',
    message_type: 'text',
    message_body: '@Operations Customer requested 2-pack deal instead of single pack.',
    read_by_client: false,
    read_by_dc: false,
    read_by_rider: true,
    created_at: new Date().toISOString()
  };

  const insertMsgRes = await fetch(`${baseUrl}/order_conversation_messages`, {
    method: 'POST',
    headers,
    body: JSON.stringify(msgPayload)
  });
  console.log('Insert Message Status:', insertMsgRes.status);

  // 3. Verify notification created in notifications table
  const notifsRes = await fetch(`${baseUrl}/notifications?category=eq.chat&order=created_at.desc&limit=3`, { headers });
  const notifs = await notifsRes.json();
  console.log('Latest Chat Notifications in public.notifications:');
  for (const n of notifs) {
    console.log(`- [${n.title}] to user_id: ${n.user_id}, agent_id: ${n.delivery_agent_id}: "${n.message}" (route: ${n.action_route})`);
  }
}

testTagging().catch(console.error);
