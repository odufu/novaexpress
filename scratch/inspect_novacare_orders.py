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

url = f"{SUPABASE_URL}/rest/v1/orders?client_id=eq.00000000-0000-4000-8000-789382731303&select=id,order_number,status,financial_settlement_status,remittance_status,remittance_reference,total_amount,client_delivery_fee,payment_method,payment_type,delivered_at,distribution_center_id"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    orders = json.loads(resp.read().decode('utf-8'))

print("=== NOVACARE ORDERS DETAILS ===")
for o in orders:
    print(json.dumps(o, indent=2))
