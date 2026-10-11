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

invoice_payload = {
    'client_id': client_id,
    'invoice_number': 'SI-TEST-002',
    'supplier_name': 'Chiner Suplier',
    'destination_warehouse': 'Wuse Grand Central Distribution Center',
    'status': 'in_transit',
    'total_units': 500,
    'grand_total_landed_cost': 5225000.0,
}

try:
    req = urllib.request.Request(f'{URL}/rest/v1/client_stock_invoices', data=json.dumps(invoice_payload).encode(), headers=headers)
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode())
        print('SUCCESS INSERT INVOICE:', res)
        inv_id = res[0]['id']

        # Now test rpc fn_create_dc_consignment_for_intake_invoice
        rpc_req = urllib.request.Request(
            f'{URL}/rest/v1/rpc/fn_create_dc_consignment_for_intake_invoice',
            data=json.dumps({'p_invoice_id': inv_id, 'p_sender_id': client_id, 'p_sender_name': 'Chiner Suplier'}).encode(),
            headers=headers
        )
        try:
            with urllib.request.urlopen(rpc_req) as rpc_resp:
                print('RPC SUCCESS:', rpc_resp.read().decode())
        except urllib.error.HTTPError as rpc_err:
            print('RPC HTTP ERROR:', rpc_err.code, rpc_err.read().decode())

except urllib.error.HTTPError as e:
    print('HTTP ERROR INVOICE INSERT:', e.code, e.read().decode())
except Exception as e:
    print('ERROR:', e)
