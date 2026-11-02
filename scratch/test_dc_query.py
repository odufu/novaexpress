import urllib.request
import json

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "iyJhbGciOiJSUzUNIiwiTXPCVCI6IkpXVCJ9.eyJpcyI6Imh3eXFxamp1bGlfaWZycnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIwMWlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrqq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    'apikey': TGT_KEY,
    'Authorization': f'Bearer {TGT_KEY}',
    'Content-Type': 'application/json'
}

cleanId = "22222222-2222-4222-8222-222222222222"

# 1. Check DC
req = urllib.request.Request(f"_TGT_URL_/rest/v1/distribution_centers?id=eq.{cleanId}&select=id".replace('_TGT_URL_', TGT_URL), headers=headers)
with urllib.request.urlopen(req) as resp:
    dc = json.loads(resp.read().decode())
    print("DC CHECK:", dc)

# 2. Check riders
req = urllib.request.Request(f"_TGT_URL_/rest/v1/delivery_agents?distribution_center_id=eq.{cleanId}&select=id".replace('_TGT_URL_', TGT_URL), headers=headers)
with urllib.request.urlopen(req) as resp:
    riders = json.loads(resp.read().decode())
    print("RIDERS COUNT:", len(riders))
    rider_ids = [r['id'] for r in riders if r.get('id')]
    print("RIDER IDS:", rider_ids)

# 3. Check cash_remittances with dc_id = cleanId
req = urllib.request.Request(f"_TGT_URL_/rest/v1/cash_remittances?distribution_center_id=eq.{cleanId}&select=*".replace('_TGT_URL_', TGT_URL), headers=headers)
with urllib.request.urlopen(req) as resp:
    rems = json.loads(resp.read().decode())
    print("REMITTANCES with distribution_center_id:", len(rems))
    for r in rems:
        print(" ->", r[\"id\"], r.get('status'), 'dc:gs r.get('distribution_center_id'), 'agent:', r.get('delivery_agent_id'))

# 4. Check all pending remittances
req = urllib.request.Request(f"_TGT_URL_/rest/v1/cash_remittances?status=eq.pending&select=*".replace('_TGT_URL_', TGT_URL), headers=headers)
with urllib.request.urlopen(req) as resp:
    rems = json.loads(resp.read().decode())
    print("ALL PENDING REMITTANCES:", len(rems))
    for r in rems:
        print(" ->", r[\"id\"], r.get('status'), 'dc:gs r.get('distribution_center_id'), 'agent:', r.get('delivery_agent_id'))
