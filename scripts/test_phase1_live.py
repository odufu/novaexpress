import io
import sys
import os
import json
import urllib.request

os.environ['no_proxy'] = '*'

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json"
}

print("=" * 60)
print("VERIFYING PHASE 1 DATABASE TABLES & RPCS ON LIVE SUPABASE")
print("=" * 60)

# 1. Check business_expenditures table
req = urllib.request.Request(f"{URL}/rest/v1/business_expenditures?select=id&limit=1", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("✅ Table 'business_expenditures': REACHABLE (HTTP 200)")
except Exception as e:
    print(f"❌ Table 'business_expenditures': {e}")

# 2. Check b2b_clients table & seeded client
req = urllib.request.Request(f"{URL}/rest/v1/b2b_clients?select=id,client_name,base_flat_rate,additional_pickup_fee", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        print(f"✅ Table 'b2b_clients': REACHABLE -> Found {len(data)} client(s): {data[0]['client_name']} (Base: ₦{data[0]['base_flat_rate']}, Extra: ₦{data[0]['additional_pickup_fee']})")
except Exception as e:
    print(f"❌ Table 'b2b_clients': {e}")

# 3. Check client_package_pickups table
req = urllib.request.Request(f"{URL}/rest/v1/client_package_pickups?select=id&limit=1", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("✅ Table 'client_package_pickups': REACHABLE (HTTP 200)")
except Exception as e:
    print(f"❌ Table 'client_package_pickups': {e}")

# 4. Check new columns in orders
req = urllib.request.Request(f"{URL}/rest/v1/orders?select=id,fulfillment_type,pickup_stops_count,additional_pickup_fee,b2b_client_id&limit=1", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        print("✅ Table 'orders' extended columns: REACHABLE (HTTP 200)")
except Exception as e:
    print(f"❌ Table 'orders' extended columns: {e}")

# 5. Test fn_get_merchant_financial_dashboard RPC
# Get a real client ID
req_client = urllib.request.Request(f"{URL}/rest/v1/clients?select=id,name&limit=1", headers=headers)
with urllib.request.urlopen(req_client, timeout=5) as resp:
    client_row = json.loads(resp.read().decode("utf-8"))[0]
    client_id = client_row["id"]
    client_name = client_row["name"]

rpc_payload = json.dumps({"p_client_id": client_id}).encode("utf-8")
req_rpc = urllib.request.Request(f"{URL}/rest/v1/rpc/fn_get_merchant_financial_dashboard", data=rpc_payload, headers=headers, method="POST")
try:
    with urllib.request.urlopen(req_rpc, timeout=5) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"✅ RPC 'fn_get_merchant_financial_dashboard' for client '{client_name}':")
        print(f"   • Sales Revenue: ₦{res.get('sales_revenue')}")
        print(f"   • Expenditures:  ₦{res.get('total_expenditures')}")
        print(f"   • Quantity Sold: {res.get('quantity_sold')} units")
        print(f"   • Net Profit:    ₦{res.get('net_profit')}")
        print(f"   • Stock Avail:   {res.get('available_stock')} units")
        print(f"   • Advert Spend:  ₦{res.get('advertisement_expenditure')}")
        print(f"   • Procurement:   ₦{res.get('procurement_expenditure')}")
        print(f"   • Lifetime Rev:  ₦{res.get('revenue_till_date')}")
except urllib.error.HTTPError as e:
    print(f"❌ RPC 'fn_get_merchant_financial_dashboard' HTTP {e.code}: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"❌ RPC 'fn_get_merchant_financial_dashboard': {e}")

# 6. Test fn_get_dc_logistics_dashboard RPC
rpc_dc_payload = json.dumps({}).encode("utf-8")
req_dc_rpc = urllib.request.Request(f"{URL}/rest/v1/rpc/fn_get_dc_logistics_dashboard", data=rpc_dc_payload, headers=headers, method="POST")
try:
    with urllib.request.urlopen(req_dc_rpc, timeout=5) as resp:
        res_dc = json.loads(resp.read().decode("utf-8"))
        print(f"✅ RPC 'fn_get_dc_logistics_dashboard' (Grand Logistics HQ):")
        print(f"   • Gross Logistics Revenue: ₦{res_dc.get('logistics_gross_revenue')}")
        print(f"   • Network Operating Exp:   ₦{res_dc.get('network_opex')}")
        print(f"   • Total Parcels Handled:   {res_dc.get('total_parcels_handled')}")
        print(f"   • Net Logistics Margin:    ₦{res_dc.get('net_logistics_margin')}")
        print(f"   • Vault Inventory:         {res_dc.get('vault_inventory')}")
except urllib.error.HTTPError as e:
    print(f"❌ RPC 'fn_get_dc_logistics_dashboard' HTTP {e.code}: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"❌ RPC 'fn_get_dc_logistics_dashboard': {e}")
