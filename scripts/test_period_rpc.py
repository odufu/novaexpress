import urllib.request
import json
import sys

URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

payload = {
    "p_client_id": "33333333-3333-4333-8333-333333333333",
    "p_start_date": "2026-09-07",
    "p_end_date": "2026-09-19"
}

req = urllib.request.Request(
    f"{URL}/rest/v1/rpc/fn_get_client_stock_balance_period",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "apikey": KEY,
        "Authorization": f"Bearer {KEY}",
        "Content-Type": "application/json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = resp.read().decode("utf-8")
        data = json.loads(body)
        print(f"SUCCESS: Returned {len(data)} balance positions")
        if data:
            print("First item:", json.dumps(data[0], indent=2))
except urllib.error.HTTPError as e:
    err = e.read().decode("utf-8")
    print(f"HTTP Error {e.code}: {err}")
except Exception as e:
    print(f"Error: {e}")
