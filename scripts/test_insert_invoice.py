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

headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': f'Bearer {SERVICE_ROLE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# 1. Get client Shorp 11 id
req = urllib.request.Request(f'{URL}/rest/v1/clients?company_name=eq.Shorp%2011', headers=headers)
with urllib.request.urlopen(req) as resp:
    clients = json.loads(resp.read().decode())
print('CLIENTS:', clients)
client_id = clients[0]['id'] if clients else None

# 2. Try inserting an invoice
invoice_payload = {
    'client_id': client_id,
    'invoice_number': 'SI-TEST-001',
    'destination_warehouse': 'Wuse Grand Central Distribution Center',
    'status': 'in_transit',
    'total_units': 500,
    'grand_total_landed_cost': 5225000.0,
}

try:
    req = urllib.request.Request(f'{URL}/rest/v1/client_stock_invoices', data=json.dumps(invoice_payload).encode(), headers=headers)
    with urllib.request.urlopen(req) as resp:
        print('SUCCESS INSERT INVOICE:', resp.read().decode())
except urllib.error.HTTPError as e:
    print('HTTP ERROR INVOICE INSERT:', e.code, e.read().decode())
except Exception as e:
    print('ERROR:', e)
