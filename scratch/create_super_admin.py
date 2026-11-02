import urllib.request
import json

envs = [
    {
        'name': 'Live Production (oygtaeriljuelhshfvkv)',
        'url': 'https://oygtaeriljuelhshfvkv.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
    },
    {
        'name': 'Testing Project (hwyqqjilcifxajruusoa)',
        'url': 'https://hwyqqjilcifxajruusoa.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'
    }
]

email = 'emeraldcodelines@gmail.com'
password = '@EmeraldXpress2026'

for env in envs:
    print(f"\n==========================================")
    print(f"Connecting to: {env['name']}")
    print(f"==========================================")
    headers = {
        'apikey': env['key'],
        'Authorization': f"Bearer {env['key']}",
        'Content-Type': 'application/json'
    }
    
    # Check company_id in this env
    company_id = '11111111-1111-4111-8111-111111111111'
    try:
        req_c = urllib.request.Request(f"{env['url']}/rest/v1/companies?select=id&limit=1", headers=headers)
        with urllib.request.urlopen(req_c) as resp_c:
            c_data = json.loads(resp_c.read().decode())
            if c_data:
                company_id = c_data[0]['id']
    except Exception as e:
        print('  Failed to query companies:', e)
    print(f"  Using company_id: {company_id}")

    # 1. Check if auth user exists
    req = urllib.request.Request(f"{env['url']}/auth/v1/admin/users", headers=headers)
    auth_user = None
    try:
        with urllib.request.urlopen(req) as resp:
            users_data = json.loads(resp.read().decode())
            for u in users_data.get('users', []):
                if u.get('email', '').lower() == email.lower():
                    auth_user = u
                    break
    except Exception as e:
        print('  Failed to list auth users:', e)
    
    auth_id = None
    if auth_user:
        auth_id = auth_user['id']
        print(f"  Auth user found: {auth_id} - Updating password & confirming email...")
        update_body = json.dumps({'password': password, 'email_confirm': True}).encode()
        req_up = urllib.request.Request(f"{env['url']}/auth/v1/admin/users/{auth_id}", data=update_body, headers=headers, method='PUT')
        with urllib.request.urlopen(req_up) as resp_up:
            print('  Password updated successfully!')
    else:
        print('  Auth user not found. Creating new auth user...')
        create_body = json.dumps({
            'email': email,
            'password': password,
            'email_confirm': True,
            'user_metadata': {'first_name': 'Joel', 'last_name': 'Emerald', 'role': 'super_admin'}
        }).encode()
        req_cr = urllib.request.Request(f"{env['url']}/auth/v1/admin/users", data=create_body, headers=headers, method='POST')
        with urllib.request.urlopen(req_cr) as resp_cr:
            res_json = json.loads(resp_cr.read().decode())
            auth_id = res_json['id']
            print(f"  Auth user created with ID: {auth_id}")

    # 2. Check and upsert into public.users
    if auth_id:
        query_url = f"{env['url']}/rest/v1/users?email=eq.{email}&select=*"
        req_q = urllib.request.Request(query_url, headers=headers)
        with urllib.request.urlopen(req_q) as resp_q:
            existing = json.loads(resp_q.read().decode())
        
        user_row = {
            'auth_user_id': auth_id,
            'company_id': company_id,
            'email': email,
            'first_name': 'Joel',
            'last_name': 'Emerald',
            'phone': '+2348123456789',
            'role': 'super_admin',
            'is_active': True,
            'is_supervisor': True
        }
        
        if existing:
            row_id = existing[0]['id']
            print(f"  public.users row found ({row_id}) - Updating role to super_admin...")
            up_body = json.dumps(user_row).encode()
            headers_patch = dict(headers)
            headers_patch['Prefer'] = 'return=representation'
            req_patch = urllib.request.Request(f"{env['url']}/rest/v1/users?id=eq.{row_id}", data=up_body, headers=headers_patch, method='PATCH')
            with urllib.request.urlopen(req_patch) as resp_patch:
                print('  public.users updated successfully to super_admin!')
        else:
            print('  public.users row not found. Inserting super_admin record...')
            in_body = json.dumps(user_row).encode()
            headers_post = dict(headers)
            headers_post['Prefer'] = 'return=representation'
            req_post = urllib.request.Request(f"{env['url']}/rest/v1/users", data=in_body, headers=headers_post, method='POST')
            try:
                with urllib.request.urlopen(req_post) as resp_post:
                    print('  public.users inserted successfully!')
            except urllib.error.HTTPError as e:
                print('  Insert failed:', e.code, e.read().decode())

print("\n==========================================")
print("VERIFICATION & SIGN-IN TEST")
print("==========================================")
# Test login via client auth endpoint on live production
login_payload = json.dumps({
    'email': email,
    'password': password
}).encode()
login_headers = {
    'apikey': envs[0]['key'],
    'Content-Type': 'application/json'
}
req_login = urllib.request.Request(f"{envs[0]['url']}/auth/v1/token?grant_type=password", data=login_payload, headers=login_headers, method='POST')
try:
    with urllib.request.urlopen(req_login) as resp_login:
        login_res = json.loads(resp_login.read().decode())
        print("Live Login Test: SUCCESS! Access token received.")
        print(f"User ID: {login_res.get('user', {}).get('id')}")
        print(f"Email: {login_res.get('user', {}).get('email')}")
except urllib.error.HTTPError as e:
    print("Live Login Test failed:", e.code, e.read().decode())
