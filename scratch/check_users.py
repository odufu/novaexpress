import urllib.request
import json

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    'apikey': TGT_KEY,
    'Authorization': f'Bearer {TGT_KEY}',
    'Content-Type': 'application/json'
}

req = urllib.request.Request(f"{TGT_URL}/auth/v1/admin/users?per_page=50", headers=headers)
with urllib.request.urlopen(req) as resp:
    users = json.loads(resp.read().decode()).get("users", [])
    print(f"Auth users count: {len(users)}")
    for u in users:
        print("AUTH:", u["id"], u["email"])

req = urllib.request.Request(f"{TGT_URL}/rest/v1/users?select=*", headers=headers)
with urllib.request.urlopen(req) as resp:
    pusers = json.loads(resp.read().decode())
    print(f"Public users count: {len(pusers)}")
    for pu in pusers:
        print("PUBLIC:", pu.get("id"), pu.get("email"), pu.get("role"), pu.get("first_name"), pu.get("last_name"))
