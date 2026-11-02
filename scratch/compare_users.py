import urllib.request, json

def get_users(url, key):
    headers = {'apikey': key, 'Authorization': 'Bearer ' + key}
    req = urllib.request.Request(url + '/rest/v1/users?select=id,email,first_name,last_name,role', headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode('utf-8'))

dev_users = get_users('https://hwyqqjilcifxajruusoa.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI')
prod_users = get_users('https://oygtaeriljuelhshfvkv.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM')

print(f"Dev has {len(dev_users)} users:")
for u in dev_users:
    fn = u.get('first_name') or ''
    ln = u.get('last_name') or ''
    print(f"   [{u.get('role')}] {u.get('email')} ({fn} {ln})")

print(f"\nProd has {len(prod_users)} users:")
for u in prod_users:
    fn = u.get('first_name') or ''
    ln = u.get('last_name') or ''
    print(f"   [{u.get('role')}] {u.get('email')} ({fn} {ln})")
