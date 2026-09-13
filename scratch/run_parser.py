import sys
sys.stdout.reconfigure(encoding='utf-8')
_out = open('scratch/order_pipeline_schema_utf8.txt', 'w', encoding='utf-8')
_old = sys.stdout
sys.stdout = _out
import json
import os
import sys

sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

with open('scratch/openapi.json', 'r', encoding='utf-8') as f:
    openapi = json.load(f)

definitions = openapi.get('definitions', {})

print("=== 1. ALL TABLES IN REMOTE OPENAPI ===")
for t in sorted(definitions.keys()):
    print(f"- {t}")

print("\n=== 2. DETAILED SCHEMAS FOR ORDER PIPELINE TABLES ===")
target_tables = [
    'orders', 'order_items', 'order_activities', 'package_deals', 'client_package_deals',
    'distribution_centers', 'delivery_agents', 'clients', 'products',
    'chat_messages', 'messages', 'conversations', 'order_chats', 'notifications',
    'customer_follow_ups', 'order_status_history', 'order_notes', 'order_tracking'
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
            print(f"   {col:32}: {col_type:15} | def: {str(default_val):20} {fk}")
    else:
        print(f"\nTABLE: {t} NOT IN OPENAPI DEFINITIONS!")

print("\n=== 3. ALL STORED PROCEDURES / RPCs ===")
paths = openapi.get('paths', {})
for path, methods in sorted(paths.items()):
    if path.startswith('/rpc/'):
        rpc_name = path.replace('/rpc/', '')
        post_info = methods.get('post', {})
        desc = post_info.get('description', '')
        params = post_info.get('parameters', [])
        param_list = []
        for p in params:
            schema = p.get('schema', {})
            props = schema.get('properties', {})
            for k, v in props.items():
                param_list.append(f"{k}: {v.get('type', v.get('format', 'unknown'))}")
        print(f"\nRPC: {rpc_name}")
        if desc:
            print(f"   Description: {desc}")
        print(f"   Parameters: {', '.join(param_list) if param_list else 'None'}")

sys.stdout = _old
_out.close()
