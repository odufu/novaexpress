import urllib.request
import json

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    'apikey': TGT_KEY,
    'Authorization': f'Bearer {TGT_KEY}',
    'Content-Type': 'application/json'
}

req = urllib.request.Request(
    f"{TGT_URL}/rest/v1/users?email=eq.abigail.kooyon@novaxpress.net",
    data=json.dumps({"role": "dc_operations"}).encode(),
    headers=headers,
    method="PATCH"
)
try:
    with urllib.request.urlopen(req) as resp:
        print("Updated Abigail role to dc_operations:", resp.status)
except urllib.error.HTTPError as e:
    print("HTTP error:", e.code, e.read().decode())
