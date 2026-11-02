import urllib.request
import json

SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInZiZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'
BASE_URL = 'https://hwyqqjilcifxajruusoa.supabase.co'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json'
}

# 1. Check client
req = urllib.request.Request(f"{BASE_URL}/rest/v1/clients?select=id,company_name,contact_email", headers=headers)
with urllib.request.urlopen(req) as resp:
    clients = json.loads(resp.read().decode())
    print("Clients:", clients)

# 2. Check public.users
req = urllib.request.Request(f"{BASE_URL}/rest/v1/users?select=id,email,role,full_name", headers=headers)
with urllib.request.urlopen(req) as resp:
    users = json.loads(resp.read().decode())
    print(f"Public users count: {len(users)}")
    for u in users:
        print(f" - {u.get('email')} ({u.get('role')})")
