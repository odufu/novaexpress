import json
import subprocess

SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

cmd = [
    "curl.exe", "--ipv4", "-s", "-X", "POST",
    "https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/rpc/transfer_order_product_and_ownership",
    "-H", f"apikey: {SERVICE_KEY}",
    "-H", f"Authorization: Bearer {SERVICE_KEY}",
    "-H", "Content-Type: application/json",
    "-d", json.dumps({
        "p_order_id": "d0ed71eb-a7c4-4de4-9a63-7fad0811736c",
        "p_new_product_id": "4e52cc92-a760-4311-941c-2fdd7d9d8218",
        "p_new_package_deal_id": "pkg-alphaman-1",
        "p_actor_name": "DC Supervisor Otukpo",
        "p_actor_role": "dc_manager",
        "p_transfer_reason": "Customer changed from Tea to Alpha Man 1 Pack"
    })
]

res = subprocess.run(cmd, capture_output=True, text=True)
print("Result:", res.stdout)
