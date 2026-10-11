import os
import sys
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

req = urllib.request.Request(f'{URL}/rest/v1/client_stock_invoices?select=*,client_stock_invoice_items(*)', headers=headers)
with urllib.request.urlopen(req) as resp:
    invoices = json.loads(resp.read().decode())

print(f'INVOICES FOUND: {len(invoices)}')
for inv in invoices:
    print('Invoice ID:', inv.get('id'), 'Number:', inv.get('invoice_number'), 'Status:', inv.get('status'), 'Warehouse:', inv.get('destination_warehouse'))
    for it in inv.get('client_stock_invoice_items', []):
        print('  Item:', it.get('product_name'), 'Qty:', it.get('quantity'), 'Product ID:', it.get('product_id'))

req2 = urllib.request.Request(f'{URL}/rest/v1/stock_transfers?select=*', headers=headers)
with urllib.request.urlopen(req2) as resp:
    transfers = json.loads(resp.read().decode())

print(f'STOCK TRANSFERS FOUND: {len(transfers)}')
for trf in transfers:
    print('Transfer ID:', trf.get('id'), 'Ref:', trf.get('transfer_reference'), 'Type:', trf.get('transfer_type'), 'Status:', trf.get('status'), 'Dest DC:', trf.get('destination_dc_id'))
