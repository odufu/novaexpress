import urllib.request, json

k = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
u = 'https://oygtaeriljuelhshfvkv.supabase.co'

def simulate_profile(email):
    print(f"\n=== Simulating _fetchUserProfile for {email} ===")
    req = urllib.request.Request(f'{u}/rest/v1/users?email=ilike.{email}&select=*', headers={'apikey': k, 'Authorization': f'Bearer {k}'})
    with urllib.request.urlopen(req) as resp:
        users = json.loads(resp.read().decode())
    if not users:
        print("  User not found in users table!")
        return
    user = users[0]
    print(f"  User found: id={user.get('id')}, role={user.get('role')}, client_id={user.get('client_id')}")
    
    cid = user.get('client_id')
    if cid:
        req = urllib.request.Request(f'{u}/rest/v1/clients?id=eq.{cid}&select=*', headers={'apikey': k, 'Authorization': f'Bearer {k}'})
        with urllib.request.urlopen(req) as resp:
            clients = json.loads(resp.read().decode())
            if clients:
                c = clients[0]
                print(f"  Client found: id={c.get('id')}, name={c.get('name')}, code={c.get('code')}, company_name={c.get('company_name')}")
            else:
                print("  Client NOT found by client_id!")

simulate_profile('novacare@novaxpress.net')
simulate_profile('novacare@novaxpress.ng')
simulate_profile('shorp11@gmail.com')
simulate_profile('osimen.john@gmail.com')
simulate_profile('client.novacale@novaxpress.ng')

