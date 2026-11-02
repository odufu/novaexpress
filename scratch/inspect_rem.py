import urllib.request
import urllib.parse
import json

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    'apikey': TGT_KEY,
    'Authorization': f'Bearer {TGT_KEY}',
    'Content-Type': 'application/json'
}

def get(path):
    req = urllib.request.Request(f"{TGT_URL}{path}", headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

print("--- 1. DISTRIBUTION CENTERS ---")
dcs = get("/rest/v1/distribution_centers?select=id,name,code")
print(json.dumps(dcs, indent=2))

print("--- 2. DELIVERY AGENTS ---")
agents = get("/rest/v1/delivery_agents?select=id,full_name,driver_code,distribution_center_id")
print(json.dumps(agents, indent=2))

print("--- 3. TEST QUERY 1: distribution_center_id.eq.22222222-2222-4222-8222-222222222222 ---")
rems_dc = get("/rest/v1/cash_remittances?distribution_center_id=eq.22222222-2222-4222-8222-222222222222&select=id,status,amount,created_at,delivery_agent_id,distribution_center_id")
print(f"Count: {len(rems_dc)}")
for r in rems_dc:
    print(r)

print("--- 4. TEST QUERY 2: The exact or query from finance_remote_datasource ---")
rider_ids = [a['id'] for a in agents if a.get('id')]
in_list = ','.join([f'"{rid}"' for rid in rider_ids])
or_param = urllib.parse.quote(f"distribution_center_id.eq.22222222-2222-4222-8222-222222222222,delivery_agent_id.in.({in_list})")
try:
    rems_or = get(f"/rest/v1/cash_remittances?or=({or_param})&select=id,status,amount,created_at,delivery_agent_id,distribution_center_id")
    print(f"OR Query count: {len(rems_or)}")
    for r in rems_or:
        print(r)
except Exception as e:
    print("OR Query failed:", e)
