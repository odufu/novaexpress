import urllib.request
import json
import sys

# Ensure UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'
BASE = 'https://hwyqqjilcifxajruusoa.supabase.co/rest/v1'

def query(endpoint):
    req = urllib.request.Request(f'{BASE}/{endpoint}', headers={
        'apikey': SERVICE_KEY,
        'Authorization': f'Bearer {SERVICE_KEY}',
        'Content-Type': 'application/json'
    })
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

try:
    orders = query('orders?select=id,order_number,customer_name,status&customer_name=ilike.*Michael*')
    print('Orders matching Michael:', len(orders))
    for o in orders:
        print('Order:', o)
        oid = o['id']
        convs = query(f'order_conversations?order_id=eq.{oid}')
        print(f'  Convs for order {oid}:', len(convs))
        for c in convs:
            cid = c['id']
            msgs = query(f'order_conversation_messages?conversation_id=eq.{cid}&select=id,sender_name,sender_role,message_body,is_system,created_at')
            print(f'    Messages ({len(msgs)}):')
            for m in msgs:
                print(f"      - [{m.get('sender_name')} ({m.get('sender_role')})]: {m.get('message_body')}")

except Exception as e:
    print('Error:', e)
