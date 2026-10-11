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

client_id = '00000000-0000-4000-8000-791731264594'

# Fetch product compression vest
req = urllib.request.Request(f'{URL}/rest/v1/products?limit=5', headers=headers)
with urllib.request.urlopen(req) as resp:
    prods = json.loads(resp.read().decode())
print('PRODS:', prods)
prod = prods[0] if prods else None

invoice_payload = {
    'client_id': client_id,
    'invoice_number': 'SI-2026-10-7414',
    'supplier_name': 'Chiner Suplier',
    'destination_warehouse': 'Wuse Grand Central Distribution Center (DC-WUSE-01)',
    'status': 'pending_inspection',
    'payment_status': 'unpaid',
    'total_units': 500,
    'grand_total_landed_cost': 5225000.0,
}

try:
    req = urllib.request.Request(f'{URL}/rest/v1/client_stock_invoices', data=json.dumps(invoice_payload).encode(), headers=headers)
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode())
        print('SUCCESS INVOICE:', res)
        inv_id = res[0]['id']

        items_payload = [{
            'invoice_id': inv_id,
            'product_id': prod['id'] if prod else None,
            'product_name': prod['name'] if prod else 'Compression vest',
            'product_sku': prod['sku'] if prod else 'SKU-PRD-2870',
            'quantity': 500,
            'supplier_unit_price': 10000.0,
            'packaging_cost_per_unit': 250.0,
            'transportation_cost_per_unit': 150.0,
            'handling_cost_per_unit': 50.0,
            'effective_landed_cost_per_unit': 10450.0,
            'total_landed_cost': 5225000.0,
        }]

        req_item = urllib.request.Request(f'{URL}/rest/v1/client_stock_invoice_items', data=json.dumps(items_payload).encode(), headers=headers)
        with urllib.request.urlopen(req_item) as resp_item:
            print('SUCCESS ITEMS:', resp_item.read().decode())

        # Call consignment handshake RPC
        rpc_payload = {
            'p_invoice_id': inv_id,
            'p_sender_id': client_id,
            'p_sender_name': 'Chiner Suplier'
        }
        req_rpc = urllib.request.Request(f'{URL}/rest/v1/rpc/fn_create_dc_consignment_for_intake_invoice', data=json.dumps(rpc_payload).encode(), headers=headers)
        with urllib.request.urlopen(req_rpc) as resp_rpc:
            print('SUCCESS RPC:', resp_rpc.read().decode())

except urllib.error.HTTPError as e:
    print('HTTP ERROR:', e.code, e.read().decode())
except Exception as e:
    print('ERROR:', e)
