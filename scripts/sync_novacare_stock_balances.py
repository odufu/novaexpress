import urllib.request
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

BASE = 'https://hwyqqjilcifxajruusoa.supabase.co/rest/v1'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'

NOVACARE_CID = '00000000-0000-4000-8000-791731264594'
WUSE_DC_NAME = 'Wuse Grand Central Distribution Center'
IKEJA_DC_NAME = 'Ikeja Central Distribution Center'

headers = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}',
    'Content-Type': 'application/json'
}

cols = [
    'client_id', 'product_id', 'item_code', 'item_name', 'item_group',
    'warehouse', 'stock_uom', 'opening_qty', 'opening_value',
    'in_qty', 'in_value', 'out_qty', 'out_value',
    'balance_qty', 'balance_value', 'valuation_rate',
    'reserved_stock', 'low_stock_threshold', 'company', 'last_entry_invoice_id'
]

raw_records = [
    {
        "client_id": NOVACARE_CID,
        "product_id": "e7f8f4ec-66fe-4830-83eb-60b4e4d84103",
        "item_code": "SKU-PRD-6731",
        "item_name": "URA Clear",
        "item_group": "Health & Wellness",
        "warehouse": WUSE_DC_NAME,
        "stock_uom": "Nos",
        "opening_qty": 700.0,
        "opening_value": 7700000.0,
        "in_qty": 0.0,
        "in_value": 0.0,
        "out_qty": 3.0,
        "out_value": 33000.0,
        "balance_qty": 697.0,
        "balance_value": 7667000.0,
        "valuation_rate": 11000.0,
        "reserved_stock": 3.0,
        "low_stock_threshold": 20,
        "company": "NOVACARE LIMITED",
        "last_entry_invoice_id": None
    },
    {
        "client_id": NOVACARE_CID,
        "product_id": "e05b6c38-cc3e-4553-b556-52ebbb50c18b",
        "item_code": "SKU-PRD-8309",
        "item_name": "Grazer Herbal Detox Tea",
        "item_group": "Health & Wellness",
        "warehouse": WUSE_DC_NAME,
        "stock_uom": "Nos",
        "opening_qty": 100.0,
        "opening_value": 1100000.0,
        "in_qty": 0.0,
        "in_value": 0.0,
        "out_qty": 2.0,
        "out_value": 22000.0,
        "balance_qty": 98.0,
        "balance_value": 1078000.0,
        "valuation_rate": 11000.0,
        "reserved_stock": 2.0,
        "low_stock_threshold": 20,
        "company": "NOVACARE LIMITED",
        "last_entry_invoice_id": None
    },
    {
        "client_id": NOVACARE_CID,
        "product_id": "e7f8f4ec-66fe-4830-83eb-60b4e4d84103",
        "item_code": "SKU-PRD-6731",
        "item_name": "URA Clear",
        "item_group": "Health & Wellness",
        "warehouse": IKEJA_DC_NAME,
        "stock_uom": "Nos",
        "opening_qty": 500.0,
        "opening_value": 5500000.0,
        "in_qty": 0.0,
        "in_value": 0.0,
        "out_qty": 0.0,
        "out_value": 0.0,
        "balance_qty": 500.0,
        "balance_value": 5500000.0,
        "valuation_rate": 11000.0,
        "reserved_stock": 0.0,
        "low_stock_threshold": 20,
        "company": "NOVACARE LIMITED",
        "last_entry_invoice_id": None
    },
    {
        "client_id": NOVACARE_CID,
        "product_id": "e05b6c38-cc3e-4553-b556-52ebbb50c18b",
        "item_code": "SKU-PRD-8309",
        "item_name": "Grazer Herbal Detox Tea",
        "item_group": "Health & Wellness",
        "warehouse": IKEJA_DC_NAME,
        "stock_uom": "Nos",
        "opening_qty": 300.0,
        "opening_value": 3300000.0,
        "in_qty": 0.0,
        "in_value": 0.0,
        "out_qty": 0.0,
        "out_value": 0.0,
        "balance_qty": 300.0,
        "balance_value": 3300000.0,
        "valuation_rate": 11000.0,
        "reserved_stock": 0.0,
        "low_stock_threshold": 20,
        "company": "NOVACARE LIMITED",
        "last_entry_invoice_id": None
    }
]

# Fetch legacy balances from 00000000-0000-4000-8000-789382731303
legacy_req = urllib.request.Request(f'{BASE}/client_stock_balances?client_id=eq.00000000-0000-4000-8000-789382731303&select=*', headers=headers)
legacy_bals = json.loads(urllib.request.urlopen(legacy_req).read().decode())
print(f"Found {len(legacy_bals)} legacy records to mirror for NOVACARE LIMITED")
for lb in legacy_bals:
    cloned = dict(lb)
    cloned['client_id'] = NOVACARE_CID
    cloned['company'] = 'NOVACARE LIMITED'
    raw_records.append(cloned)

# Normalize all records so they contain EXACTLY the same keys
normalized_records = []
for r in raw_records:
    norm = {}
    for col in cols:
        norm[col] = r.get(col, None)
    normalized_records.append(norm)

# Upsert records
print(f"Inserting {len(normalized_records)} normalized stock balance records for {NOVACARE_CID}...")
post_req = urllib.request.Request(f'{BASE}/client_stock_balances', data=json.dumps(normalized_records).encode('utf-8'), headers=headers, method='POST')
try:
    with urllib.request.urlopen(post_req) as resp:
        print(f"Success! Status: {resp.status}")
except urllib.error.HTTPError as e:
    print(f"HTTPError: {e.code} - {e.read().decode()}")
except Exception as e:
    print(f"Error: {e}")

# Verify count now
verify_req = urllib.request.Request(f'{BASE}/client_stock_balances?client_id=eq.{NOVACARE_CID}&select=id,item_name,warehouse,balance_qty,balance_value', headers=headers)
after = json.loads(urllib.request.urlopen(verify_req).read().decode())
print(f"\nTotal client_stock_balances for {NOVACARE_CID} after sync: {len(after)}")
for a in after:
    print(f"  - {a['item_name']} @ {a['warehouse']}: {a['balance_qty']} units (NGN {a['balance_value']:,.2f})")
