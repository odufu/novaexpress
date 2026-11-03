import urllib.request, json

k1 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
u1 = 'https://oygtaeriljuelhshfvkv.supabase.co'

req = urllib.request.Request(f'{u1}/auth/v1/admin/users', headers={'apikey': k1, 'Authorization': f'Bearer {k1}'})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    for u in data.get('users', []):
        print(u.get('email'), '|', u.get('id'), '|', u.get('user_metadata'))

