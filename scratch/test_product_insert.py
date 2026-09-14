import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# Payload exactly as stock_remote_datasource creates it
payload1 = {
    'company_id': '11111111-1111-4111-8111-111111111111',
    'name': 'Audit Test Product',
    'sku': 'SKU-AUDIT-001',
    'client_name': 'Leafora Limited',
    'client_id': '00000000-0000-4000-8000-789381618649',
    'category': 'Health & Wellness',
    'description': 'Test Description [COVERING_STATES: ["Lagos"]]',
    'base_price': 15000.0,
    'cost_price': 8000.0,
    'weight_kg': 0.5,
    'stock_quantity': 0,
    'low_stock_threshold': 10,
    'is_active': True,
    'covering_states': ['Lagos'],
    'dc_stocks': {'00000000-0000-4000-8000-789334173209': 0},
    'image_url': 'https://example.com/img.png'
}

print('Testing upsert to products table with service role key...')
req = urllib.request.Request(
    'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/products?on_conflict=sku',
    data=json.dumps(payload1).encode(),
    headers=headers
)
try:
    with urllib.request.urlopen(req, context=ctx) as r:
        res = json.loads(r.read().decode())
        print('Upsert SUCCESS with service role:', res)
        prod_id = res[0]['id']
        
        # Now clean up
        del_req = urllib.request.Request(
            f'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/products?id=eq.{prod_id}',
            headers=headers,
            method='DELETE'
        )
        urllib.request.urlopen(del_req, context=ctx)
        print('Cleaned up test product.')
except urllib.error.HTTPError as e:
    print('Upsert FAILED with service role:', e.code, e.read().decode())
