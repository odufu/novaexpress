import urllib.request
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

print("=== DISTRIBUTION CENTERS ===")
for d in get("/rest/v1/distribution_centers?select=*"):
    print("DC:", d.get("id"), d.get("name"), d.get("code"))

print("=== DELIVERY AGENTS ===")
for a in get("/rest/v1/delivery_agents?select=*"):
    print("AGENT:", a.get("id"), a.get("full_name"), a.get("driver_code"), "dc:", a.get("distribution_center_id"))

print("=== CASH REMITTANCES ===")
for r in get("/rest/v1/cash_remittances?select=*&order=created_at.desc"):
    print("REM:", r.get("id"), r.get("status"), r.get("amount"), "agent:", r.get("delivery_agent_id"), "dc:", r.get("distribution_center_id"))