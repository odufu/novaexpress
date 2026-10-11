import os
import json
import urllib.request

os.environ['no_proxy'] = '*'

URL = 'https://oygtaeriljuelhshfvkv.supabase.co'
SERVICE_ROLE_KEY = (
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.'
    '2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
)

req = urllib.request.Request(f'{URL}/rest/v1/?apikey={SERVICE_ROLE_KEY}')
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode())

paths = spec.get('paths', {})
rpcs = [p for p in paths.keys() if p.startswith('/rpc/')]
print("RPCs in oygtaeriljuelhshfvkv:")
for r in sorted(rpcs):
    if any(k in r.lower() for k in ['stock', 'consignment', 'invoice', 'sql', 'exec']):
        print(f"  {r}")
