import os
import json
import urllib.request
import urllib.error

url = "https://qpcafevjsrbauweuiiyq.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json',
}

def query(endpoint):
    full_url = f"{url}/rest/v1/{endpoint}"
    req = urllib.request.Request(full_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return {"error": e.code, "reason": e.read().decode('utf-8')}
    except Exception as e:
        return {"error": str(e)}

print("=== 1. ORDERS SCHEMA & SAMPLE ===")
orders = query("orders?select=*&limit=2")
if isinstance(orders, list) and len(orders) > 0:
    print("Order columns:", list(orders[0].keys()))
    sample = orders[0]
    for k in ['order_number', 'product_name', 'product_sku', 'quantity', 'total_amount', 'delivery_fee', 'status', 'client_id']:
        print(f"  {k}: {sample.get(k)}")
else:
    print("Orders query response:", orders)

print("\n=== 2. ORDER ITEMS TABLE ===")
order_items = query("order_items?select=*&limit=1")
print("Order items query response:", order_items)

print("\n=== 3. CLIENTS TABLE SCHEMA & RECORD ===")
clients = query("clients?select=*&limit=1")
if isinstance(clients, list) and len(clients) > 0:
    print("Clients columns:", list(clients[0].keys()))
    print("Sample client tariffs:")
    for k in ['id', 'company_name', 'name', 'custom_delivery_fee', 'custom_failed_attempt_fee', 'custom_platform_fee', 'custom_platform_fee_type', 'brand_color_primary', 'brand_color_secondary']:
        print(f"  {k}: {clients[0].get(k)}")
else:
    print("Clients query:", clients)

print("\n=== 5. CLIENT SETTLEMENTS SCHEMA & RECORD ===")
settlements = query("client_settlements?select=*&limit=1")
if isinstance(settlements, list) and len(settlements) > 0:
    print("Settlements columns:", list(settlements[0].keys()))
    print("Sample settlement:", settlements[0])
else:
    print("Settlements query:", settlements)


