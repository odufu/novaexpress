import os
import json
import urllib.request
import urllib.error

os.environ['no_proxy'] = '*'

URL = 'https://oygtaeriljuelhshfvkv.supabase.co'
SERVICE_ROLE_KEY = (
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.'
    '2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
)

headers = {'apikey': SERVICE_ROLE_KEY, 'Authorization': f'Bearer {SERVICE_ROLE_KEY}'}

query_select = '*,stock_transfer_items(id,transfer_id,product_id,quantity_shipped,quantity_received,quantity_damaged,quantity_missing,item_notes,product:products(id,name,sku))'
url = f'{URL}/rest/v1/stock_transfers?select={urllib.parse.quote(query_select)}&order=created_at.desc'

try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode())
        print('FETCH TRANSFERS SUCCESS! Count:', len(res))
        for r in res:
            print('Transfer:', r.get('transfer_number'), 'Type:', r.get('transfer_type'), 'Status:', r.get('status'), 'Items:', r.get('stock_transfer_items'))
except urllib.error.HTTPError as e:
    print('HTTP ERROR:', e.code, e.read().decode())
except Exception as e:
    print('ERROR:', e)
