import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU',
    'Content-Type': 'application/json'
}

# 1. Inspect schema
req = urllib.request.Request('https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/', headers=headers)
with urllib.request.urlopen(req, context=ctx) as r:
    spec = json.loads(r.read().decode())
    props = spec.get('definitions', {}).get('products', {}).get('properties', {})
    req_fields = spec.get('definitions', {}).get('products', {}).get('required', [])
    print('=== PRODUCTS TABLE SCHEMA ===')
    print('Required fields:', req_fields)
    for k, v in props.items():
        print(f"  {k}: {v.get('type')} ({v.get('format')})")

# 2. Inspect a sample product row
req2 = urllib.request.Request('https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/products?limit=1', headers=headers)
with urllib.request.urlopen(req2, context=ctx) as r2:
    data = json.loads(r2.read().decode())
    print('\n=== SAMPLE PRODUCT ROW ===')
    if data:
        for k, v in data[0].items():
            print(f"  {k}: {repr(v)}")
    else:
        print('  (No products in database)')
