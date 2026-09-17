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

def query_table(path):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')

# 1. Check Clients
st, clients = query_table("clients?select=id,name,company_name,email")
print("=== CLIENTS ===")
print(json.dumps(clients, indent=2))

# 2. Check Novacare orders
st, orders = query_table("orders?select=id,order_number,client_id,status,financial_settlement_status,remittance_status,remittance_reference,total_amount,delivered_at,created_at&order=created_at.desc")
print("\n=== ORDERS ===")
for o in orders:
    print(f"Order: {o.get('order_number')} | Client: {o.get('client_id')} | Status: {o.get('status')} | FinSettlement: {o.get('financial_settlement_status')} | Remittance: {o.get('remittance_status')} | DeliveredAt: {o.get('delivered_at')}")

# 3. Check client_settlements
st, settlements = query_table("client_settlements?select=*&order=created_at.desc")
print("\n=== CLIENT SETTLEMENTS ===")
for s in settlements:
    print(f"Settlement: {s.get('settlement_number')} | ClientId: {s.get('client_id')} | OrdersCount: {s.get('total_orders_count')} | Gross: {s.get('gross_collections')} | Net: {s.get('net_payout_amount')} | Date: {s.get('created_at')} | Status: {s.get('status')}")
