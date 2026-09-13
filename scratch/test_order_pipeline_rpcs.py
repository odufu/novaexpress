import json
import subprocess

SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

def call_rpc(rpc_name, params):
    cmd = [
        "curl.exe", "--ipv4", "-s", "-X", "POST",
        f"https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/rpc/{rpc_name}",
        "-H", f"apikey: {SERVICE_KEY}",
        "-H", f"Authorization: Bearer {SERVICE_KEY}",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(params)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout

print("=== 1. TEST fn_mark_conversation_read ===")
print(call_rpc("fn_mark_conversation_read", {
    "p_conversation_id": "00000000-0000-0000-0000-000000000000",
    "p_role": "dc"
}))

print("\n=== 2. TEST auto_dispatch_order_by_state_lga ===")
# Let's test on order NOV-2026-2045 (id: d0ed71eb-a7c4-4de4-9a63-7fad0811736c) which has delivery_state: Benue, lga: Otukpo
print(call_rpc("auto_dispatch_order_by_state_lga", {
    "p_order_id": "d0ed71eb-a7c4-4de4-9a63-7fad0811736c"
}))

print("\n=== 3. TEST transfer_order_product_and_ownership (dry run test) ===")
# Let's see what happens if called by a rider role (should raise unauthorized exception)
print("Testing rider restriction:")
print(call_rpc("transfer_order_product_and_ownership", {
    "p_order_id": "d0ed71eb-a7c4-4de4-9a63-7fad0811736c",
    "p_new_product_id": "4e52cc92-a760-4311-941c-2fdd7d9d8218",
    "p_new_package_deal_id": "pkg-sku-prd-1379-1",
    "p_actor_name": "Emeka Rider",
    "p_actor_role": "rider",
    "p_transfer_reason": "Customer changed mind"
}))
