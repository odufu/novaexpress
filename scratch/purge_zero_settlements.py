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

# Delete settlements with total_orders_count = 0
url = f"{SUPABASE_URL}/rest/v1/client_settlements?total_orders_count=eq.0"
req = urllib.request.Request(url, headers=headers, method="DELETE")
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print(f"Deleted zero-order settlements: HTTP {resp.status}")
except Exception as e:
    print(f"Error deleting: {e}")

# Fetch remaining settlements
url2 = f"{SUPABASE_URL}/rest/v1/client_settlements?select=settlement_number,total_orders_count,gross_collections,net_payout_amount,created_at"
req2 = urllib.request.Request(url2, headers=headers)
with urllib.request.urlopen(req2, timeout=10) as resp2:
    remaining = json.loads(resp2.read().decode('utf-8'))

print("\nRemaining client_settlements:")
print(json.dumps(remaining, indent=2))
