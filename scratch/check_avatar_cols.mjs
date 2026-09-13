import fs from 'fs';

const openapi = JSON.parse(fs.readFileSync('scratch/openapi.json', 'utf-8'));
const userProps = openapi.definitions?.users?.properties || {};
console.log('=== USERS TABLE PROPERTIES ===');
for (const [k, v] of Object.entries(userProps)) {
  console.log(`  ${k}: type=${v.type}, format=${v.format}`);
}

const daProps = openapi.definitions?.delivery_agents?.properties || {};
console.log('=== DELIVERY AGENTS PROPERTIES ===');
for (const [k, v] of Object.entries(daProps)) {
  if (k.includes('photo') || k.includes('image') || k.includes('avatar') || k.includes('url')) {
    console.log(`  ${k}: type=${v.type}`);
  }
}

const clientProps = openapi.definitions?.clients?.properties || {};
console.log('=== CLIENTS PROPERTIES ===');
for (const [k, v] of Object.entries(clientProps)) {
  if (k.includes('photo') || k.includes('image') || k.includes('avatar') || k.includes('logo') || k.includes('url')) {
    console.log(`  ${k}: type=${v.type}`);
  }
}
