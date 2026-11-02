import urllib.request
import json

SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'
URL = 'https://hwyqqjilcifxajruusoa.supabase.co/auth/v1/admin/users?per_page=50'

req = urllib.request.Request(URL, headers={
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}'
})

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        users = data.get('users', [])
        print(f"Total auth users: {len(users)}")
        for u in users:
            print(f"- {u['email']} (id: {u['id']})")
except Exception as e:
    print(f"Error: {e}")
