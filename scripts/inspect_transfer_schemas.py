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

headers = {'apikey': SERVICE_ROLE_KEY, 'Authorization': f'Bearer {SERVICE_ROLE_KEY}'}

req = urllib.request.Request(f'{URL}/rest/v1/?apikey={SERVICE_ROLE_KEY}')
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode())

table_def = spec.get('definitions', {}).get('stock_transfer_items', {})
print("COLUMNS OF stock_transfer_items:")
for prop, val in table_def.get('properties', {}).items():
    print(f"  {prop}: {val.get('type')}")

table_def2 = spec.get('definitions', {}).get('stock_transfers', {})
print("\nCOLUMNS OF stock_transfers:")
for prop, val in table_def2.get('properties', {}).items():
    print(f"  {prop}: {val.get('type')}")
