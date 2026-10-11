import urllib.request
import json
import ssl

SUPABASE_URL = "https://oygtaeriljuelhshfvkv.supabase.co"
SERVICE_ROLE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ."
    "2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
)

headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json"
}

req = urllib.request.Request(f"{SUPABASE_URL}/auth/v1/admin/users?per_page=100", headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        users = data.get("users", [])
        print(f"Total Auth Users on oygtaeriljuelhshfvkv: {len(users)}")
        for u in users:
            print(f"- Email: {u.get('email')}, ID: {u.get('id')}, Confirmed: {u.get('email_confirmed_at') is not None}, Metadata: {u.get('user_metadata')}")
except Exception as e:
    print(f"Error fetching auth users: {e}")
