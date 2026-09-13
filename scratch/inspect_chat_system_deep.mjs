import fs from 'fs';

const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';
const baseUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1';

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`
};

async function inspect() {
  const openapi = JSON.parse(fs.readFileSync('scratch/openapi.json', 'utf-8'));

  console.log('=== OPENAPI DEFINITION: order_conversations ===');
  console.log(openapi.definitions?.order_conversations?.properties);

  console.log('\n=== OPENAPI DEFINITION: order_conversation_messages ===');
  console.log(openapi.definitions?.order_conversation_messages?.properties);

  console.log('\n=== OPENAPI DEFINITION: users (avatar fields) ===');
  const userProps = openapi.definitions?.users?.properties || {};
  for (const [k, v] of Object.entries(userProps)) {
    if (k.includes('avatar') || k.includes('image') || k.includes('photo') || k.includes('picture') || k.includes('name')) {
      console.log(`  ${k}:`, v);
    }
  }

  // Fetch samples from remote
  const convsRes = await fetch(`${baseUrl}/order_conversations?limit=3`, { headers });
  const convs = await convsRes.json();
  console.log('\n=== SAMPLE order_conversations ===');
  console.log(JSON.stringify(convs, null, 2));

  const msgsRes = await fetch(`${baseUrl}/order_conversation_messages?limit=5&order=created_at.desc`, { headers });
  const msgs = await msgsRes.json();
  console.log('\n=== SAMPLE order_conversation_messages ===');
  console.log(JSON.stringify(msgs, null, 2));

  const notifsRes = await fetch(`${baseUrl}/notifications?limit=5&order=created_at.desc`, { headers });
  const notifs = await notifsRes.json();
  console.log('\n=== SAMPLE notifications ===');
  console.log(JSON.stringify(notifs, null, 2));
}

inspect().catch(console.error);
