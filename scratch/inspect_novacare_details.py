import json
import urllib.request
import urllib.error
import sys

sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json"
}

url = f"{SUPABASE_URL}/rest/v1/orders?client_id=eq.00000000-0000-4000-8000-789382731303&select=*"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    orders = json.loads(resp.read().decode('utf-8'))

# Let's inspect each order's notes, payment_status, remittance_status, financial_settlement_status
for o in orders:
    print(f"\nOrder: {o.get('order_number')}")
    print(f"  status: {o.get('status')}")
    print(f"  financial_settlement_status: {o.get('financial_settlement_status')}")
    print(f"  remittance_status: {o.get('remittance_status')}")
    print(f"  remittance_reference: {o.get('remittance_reference')}")
    print(f"  payment_status: {o.get('payment_status')}")
    print(f"  notes: {o.get('delivery_notes')}")
