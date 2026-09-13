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

def get_openapi():
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/?apikey={SERVICE_KEY}", headers={"apikey": SERVICE_KEY})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode('utf-8'))

openapi = get_openapi()
definitions = openapi.get('definitions', {})

print("=== ALL TABLES IN REMOTE OPENAPI ===")
table_names = sorted(list(definitions.keys()))
for t in table_names:
    print(f"- {t}")

print("\n=== ORDER & ROUTING & CHAT RELATED TABLES SCHEMA ===")
target_tables = [
    'orders', 'order_items', 'order_activities', 'package_deals', 'client_package_deals',
    'distribution_centers', 'dc_coverage_areas', 'delivery_agents', 'clients',
    'chat_messages', 'messages', 'conversations', 'order_chats', 'notifications',
    'customer_follow_ups', 'order_status_history', 'order_notes'
]

for t in target_tables:
    if t in definitions:
        props = definitions[t].get('properties', {})
        print(f"\nTABLE: {t} ({len(props)} columns)")
        for col, col_info in sorted(props.items()):
            col_type = col_info.get('type', col_info.get('format', 'unknown'))
            default_val = col_info.get('default', '')
            desc = col_info.get('description', '')
            fk = " [FK]" if "Foreign Key" in desc else ""
            print(f"   {col:30}: {col_type:15} | def: {default_val} {fk}")
    else:
        print(f"\nTABLE: {t} NOT FOUND in OpenAPI definitions!")

print("\n=== RPCs RELATED TO ORDERS & ROUTING & CHAT ===")
paths = openapi.get('paths', {})
for path, methods in sorted(paths.items()):
    if path.startswith('/rpc/'):
        rpc_name = path.replace('/rpc/', '')
        post_info = methods.get('post', {})
        desc = post_info.get('description', '')
        params = post_info.get('parameters', [])
        # Check if relevant
        print(f"\nRPC: {rpc_name}")
        for p in params:
            schema = p.get('schema', {})
            props = schema.get('properties', {})
            print(f"   Parameters: {list(props.keys())}")
