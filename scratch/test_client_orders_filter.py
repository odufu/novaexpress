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

# Fetch all orders
url = f"{SUPABASE_URL}/rest/v1/orders?select=id,order_number,status,financial_settlement_status,remittance_status,client_id,client_name,client_company,total_amount,delivered_at"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    orders = json.loads(resp.read().decode('utf-8'))

print(f"Total orders in DB: {len(orders)}")

# Check Novacare orders
novacare_id = "00000000-0000-4000-8000-789382731303"
novacare_name = "Novacare Health & Wellness Ltd"

print("\nAll Novacare orders matching clientId or companyName:")
for o in orders:
    c_id = o.get('client_id')
    c_name = (o.get('client_name') or '').strip().lower()
    c_comp = (o.get('client_company') or '').strip().lower()
    
    match = (c_id == novacare_id) or (c_name == novacare_name.lower()) or (c_comp == novacare_name.lower())
    if match:
        fs = (o.get('financial_settlement_status') or '').lower()
        rs = (o.get('remittance_status') or '').lower()
        st = (o.get('status') or '').lower()
        is_delivered = st == 'delivered'
        is_settled = (fs == 'client_settled') or (fs == 'settled') or (rs == 'remitted') or (rs == 'cleared')
        awaiting = is_delivered and not is_settled
        print(f"  {o.get('order_number')}: st={st}, fs={fs}, rs={rs}, awaiting={awaiting}, delivered_at={o.get('delivered_at')}")
