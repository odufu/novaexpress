import fs from 'fs';

const openapi = JSON.parse(fs.readFileSync('scratch/openapi.json', 'utf-8'));
console.log('notifications properties:', Object.keys(openapi.definitions?.notifications?.properties || {}));
console.log('orders properties:', Object.keys(openapi.definitions?.orders?.properties || {}));
