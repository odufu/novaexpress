import json
import urllib.request
import urllib.error

URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def check_table(table_name):
    req = urllib.request.Request(f"{URL}/rest/v1/{table_name}?select=count", headers={
        "apikey": KEY,
        "Authorization": f"Bearer {KEY}",
        "Range": "0-0",
        "Prefer": "count=exact"
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            content_range = resp.headers.get("Content-Range")
            count = content_range.split("/")[-1] if content_range else "0"
            print(f"Table '{table_name}' EXISTS. Row count: {count}")
            return True
    except urllib.error.HTTPError as e:
        print(f"Table '{table_name}' error: {e.code} {e.reason}")
        return False

print("1. Checking client_marketers table...")
check_table("client_marketers")

print("2. Checking lead_forms table...")
check_table("lead_forms")

print("3. Checking client_closers schema for assigned_product_ids...")
req = urllib.request.Request(f"{URL}/rest/v1/client_closers?select=id,full_name,assigned_product_ids&limit=2", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print("client_closers sample:", data)
except Exception as e:
    print("Error querying client_closers:", e)
