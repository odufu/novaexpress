import urllib.request
import json

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

def query_supabase(table, params=""):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{params}"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code} for {url}: {e.read().decode('utf-8')}")
        return None

remits = query_supabase("cash_remittances", "limit=5")
if remits:
    print("cash_remittances count:", len(remits))
    print("columns:", list(remits[0].keys()))
    for r in remits:
        print(f"Remit: {r.get('id')} | ref: {r.get('reference_number')} | rider: {r.get('delivery_agent_id')} | DC: {r.get('distribution_center_id')} | amount: {r.get('amount')} | status: {r.get('status')}")
else:
    print("No remittances found.")
