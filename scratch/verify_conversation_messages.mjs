const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

async function verify() {
  const headers = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`
  };

  const orderId = '3dbe8d4c-cd78-443e-92ec-44b2d6efdbf0';

  // 1. Check conversation
  const convRes = await fetch(`${baseUrl}/order_conversations?order_id=eq.${orderId}`, { headers });
  const conv = (await convRes.json())[0];
  console.log('Conversation:', {
    id: conv?.id,
    order_number: conv?.order_number,
    client_name: conv?.client_name,
    dc_name: conv?.distribution_center_name,
    rider_name: conv?.delivery_agent_name,
    order_status: conv?.order_status,
    last_message_text: conv?.last_message_text,
    unread_client: conv?.unread_client_count,
    unread_dc: conv?.unread_dc_count,
    unread_rider: conv?.unread_rider_count,
  });

  // 2. Check conversation messages
  if (conv?.id) {
    const msgRes = await fetch(`${baseUrl}/order_conversation_messages?conversation_id=eq.${conv.id}&order=created_at.desc`, { headers });
    const msgs = await msgRes.json();
    console.log(`Messages Count: ${msgs.length}`);
    for (const m of msgs) {
      console.log(`- [${m.message_type}] by ${m.sender_name} (${m.sender_role}): "${m.message_body}"`);
    }
  }

  // 3. Check notifications for rider
  const notifRes = await fetch(`${baseUrl}/notifications?delivery_agent_id=eq.cd6b53b0-5203-48f3-ae9b-81c6a0e9e5f3&order=created_at.desc&limit=2`, { headers });
  const notifs = await notifRes.json();
  console.log('Rider Notifications:');
  for (const n of notifs) {
    console.log(`- ${n.title}: ${n.message}`);
  }
}

verify().catch(console.error);
