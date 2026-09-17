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

def call_rpc(rpc_name, params):
    url = f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}"
    req = urllib.request.Request(url, data=json.dumps(params).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as ex:
        return 0, str(ex)

print("=== TESTING RPC WITH EMPTY/NO ORDERS ===")
st, res = call_rpc("fn_generate_merchant_daily_settlement", {
    "p_client_id": "00000000-0000-4000-8000-789333871429", # Novacare Limited (0 delivered orders)
    "p_dc_id": "22222222-2222-4222-8222-222222222222",
})
print(f"Status: {st}")
print(f"Response: {res}")

# Check that no zero settlement was created
url = f"{SUPABASE_URL}/rest/v1/client_settlements?total_orders_count=eq.0"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    zeros = json.loads(resp.read().decode('utf-8'))
print(f"Zero settlements count: {len(zeros)} (Expected: 0)")
