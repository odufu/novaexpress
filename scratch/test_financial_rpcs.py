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
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as ex:
        return 0, str(ex)

print("=== TESTING FINANCIAL RPCs ===")

# 1. calculate_remittance_transfer_fee
st, res = call_rpc("calculate_remittance_transfer_fee", {"p_amount": 5000})
print(f"1. calculate_remittance_transfer_fee(5000): {st} -> {res}")
st, res = call_rpc("calculate_remittance_transfer_fee", {"p_amount": 5200})
print(f"   calculate_remittance_transfer_fee(5200): {st} -> {res}")
st, res = call_rpc("calculate_remittance_transfer_fee", {"p_amount": 55000})
print(f"   calculate_remittance_transfer_fee(55000): {st} -> {res}")

# 2. fn_calculate_merchant_asset_custody
# Novacale client id: 33333333-3333-4333-8333-333333333333
st, res = call_rpc("fn_calculate_merchant_asset_custody", {"p_client_id": "33333333-3333-4333-8333-333333333333"})
print(f"2. fn_calculate_merchant_asset_custody: {st} -> {res}")

# 3. Test calling fn_approve_cash_remittance on dummy id
st, res = call_rpc("fn_approve_cash_remittance", {
    "p_remittance_id": "00000000-0000-0000-0000-000000000000"
})
print(f"3. fn_approve_cash_remittance (non-existent id): {st} -> {res}")

# 4. Test calling fn_approve_cash_remittance on an existing row (Row 1 of cash_remittances)
# '05f38799-0d8b-45a8-a7ad-b560567dc653'
st, res = call_rpc("fn_approve_cash_remittance", {
    "p_remittance_id": "05f38799-0d8b-45a8-a7ad-b560567dc653"
})
print(f"4. fn_approve_cash_remittance (existing row): {st} -> {res}")

# 5. Test fn_generate_merchant_daily_settlement (dry run range where no new orders match or dry run)
st, res = call_rpc("fn_generate_merchant_daily_settlement", {
    "p_client_id": "33333333-3333-4333-8333-333333333333",
    "p_dc_id": "00000000-0000-4000-8000-788825051520",
    "p_period_start": "2026-09-01T00:00:00Z",
    "p_period_end": "2026-09-02T00:00:00Z",
    "p_custom_deductions": {}
})
print(f"5. fn_generate_merchant_daily_settlement: {st} -> {res}")
