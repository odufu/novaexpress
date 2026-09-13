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

agents = query_supabase("delivery_agents", "limit=1")
if agents and len(agents) > 0:
    print("delivery_agents columns:", list(agents[0].keys()))
    print("sample agent:", agents[0])
else:
    print("No delivery agents or empty")

all_agents = query_supabase("delivery_agents")
if all_agents:
    print(f"Total agents in delivery_agents: {len(all_agents)}")
    for a in all_agents:
        print(f"Agent: {a.get('id')} | code: {a.get('agent_code')} | DC: {a.get('distribution_center_id')}")

users = query_supabase("users", "role=eq.delivery_agent")
if users:
    print(f"\nTotal users with role delivery_agent: {len(users)}")
    for u in users:
        print(f"User: {u.get('id')} | {u.get('email')} | {u.get('full_name')} | DC: {u.get('distribution_center_id')}")
