import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('scratch/openapi.json', 'r', encoding='utf-8') as f:
    openapi = json.load(f)

defs = openapi.get('definitions', {})
for t in ['order_conversations', 'order_conversation_messages', 'client_packages', 'product_packages']:
    if t in defs:
        props = defs[t].get('properties', {})
        print(f"\n=== TABLE: {t} ({len(props)} columns) ===")
        for k, v in sorted(props.items()):
            col_type = v.get('type', v.get('format', 'unknown'))
            default_val = v.get('default', '')
            desc = v.get('description', '')
            fk = " [FK]" if "Foreign Key" in desc else ""
            print(f"   {k:30}: {col_type:15} | def: {str(default_val):20} {fk}")
    else:
        print(f"\nTABLE: {t} NOT IN OPENAPI DEFINITIONS!")
