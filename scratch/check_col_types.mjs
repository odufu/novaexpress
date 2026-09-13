import fs from 'fs';

const openapi = JSON.parse(fs.readFileSync('scratch/openapi.json', 'utf-8'));
const agentProps = openapi.definitions?.delivery_agents?.properties;
console.log('delivery_agents.distribution_center_id:', agentProps?.distribution_center_id);
console.log('delivery_agents.id:', agentProps?.id);
console.log('delivery_agents.covered_lgas:', agentProps?.covered_lgas);

const dcProps = openapi.definitions?.distribution_centers?.properties;
console.log('distribution_centers.id:', dcProps?.id);
console.log('distribution_centers.operating_zones:', dcProps?.operating_zones);
