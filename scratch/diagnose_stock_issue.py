import urllib.request
import json
import ssl

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

ctx = ssl.create_default_context()

def api_call(endpoint, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        f"{SUPABASE_URL}{endpoint}",
        headers={
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        },
        data=data,
        method=method
    )
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            content = resp.read().decode()
            return resp.status, json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        return e.code, err_body

print("=== RECENT STOCK TRANSFERS ===")
st, transfers = api_call("/rest/v1/stock_transfers?order=created_at.desc&limit=10&select=*,stock_transfer_items(*)")
if isinstance(transfers, list):
    for t in transfers:
        print(f"ID: {t.get('id')} | WB: {t.get('waybill_number')} | Type: {t.get('transfer_type')} | Status: {t.get('status')} | Src: {t.get('source_dc_id')} | Dest: {t.get('destination_dc_id')} | DestWH: {t.get('destination_warehouse_id')}")
        for item in t.get("stock_transfer_items", []):
            print(f"   Item: id={item.get('id')} prod={item.get('product_id')} ship={item.get('quantity_shipped')} rec={item.get('quantity_received')}")
else:
    print(transfers)

print("\n=== FIND RIDER EMEKA ===")
st, riders = api_call("/rest/v1/users?email=ilike.*emeka*&select=*")
print("Rider user:", riders)

st, pda_list = api_call("/rest/v1/delivery_agents?select=*")
print("\nAll delivery agents:", pda_list)

print("\n=== FIND DISTRIBUTION CENTERS ===")
st, dcs = api_call("/rest/v1/distribution_centers?select=id,name,code,is_active")
print("DCs:", dcs)
