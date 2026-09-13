import fs from 'fs';

const openapi = JSON.parse(fs.readFileSync('scratch/openapi.json', 'utf-8'));
console.log('order_conversation_messages properties:', Object.keys(openapi.definitions?.order_conversation_messages?.properties || {}));
console.log('order_conversations properties:', Object.keys(openapi.definitions?.order_conversations?.properties || {}));
