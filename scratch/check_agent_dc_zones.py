import urllib.request
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU'
headers = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
    'Content-Type': 'application/json'
}

base_url = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1'

def get(endpoint):
    req = urllib.request.Request(f'{base_url}/{endpoint}', headers=headers)
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())

out = []
try:
    agents = get('delivery_agents?select=id,agent_code,distribution_center_id,operating_state,operating_city,covered_lgas,current_status,is_on_duty,is_active')
    out.append('=== DELIVERY AGENTS ===')
    for a in agents:
        out.append(f"ID: {a['id']}, Code: {a['agent_code']}, DC: {a['distribution_center_id']}, State: {a['operating_state']}, City: {a['operating_city']}, LGAs: {a['covered_lgas']}, Status: {a['current_status']}, Duty: {a['is_on_duty']}, Active: {a['is_active']}")

    dcs = get('distribution_centers?select=id,name,state,city,operating_zones,is_hub,is_grand_dc,is_active')
    out.append('\n=== DISTRIBUTION CENTERS ===')
    for d in dcs:
        out.append(f"ID: {d['id']}, Name: {d['name']}, State: {d['state']}, City: {d['city']}, Zones: {d['operating_zones']}, Hub: {d['is_hub']}, Grand: {d['is_grand_dc']}, Active: {d['is_active']}")
except Exception as e:
    out.append(f"ERROR: {e}")

output_str = "\n".join(out)
with open('scratch/check_agent_dc_zones_output.txt', 'w', encoding='utf-8') as f:
    f.write(output_str)

print("Done inspecting.")
