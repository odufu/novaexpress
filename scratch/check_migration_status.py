import urllib.request
import json

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

def test_table(table):
    url = f"{SUPABASE_URL}/rest/v1/{table}?select=*&limit=1"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            print(f"[OK] Table '{table}' exists. Count: {len(data)}")
            if data:
                print(f"  Sample keys: {list(data[0].keys())[:10]}")
    except urllib.error.HTTPError as e:
        print(f"[ERROR] Table '{table}': {e.code} - {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"[EXCEPTION] Table '{table}': {e}")

test_table("order_conversations")
test_table("order_conversation_messages")
test_table("client_settlements")
test_table("products")
test_table("orders")
