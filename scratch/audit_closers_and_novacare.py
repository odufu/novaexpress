import urllib.request
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

url = 'https://qpcafevjsrbauweuiiyq.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU'
headers = {'apikey': key, 'Authorization': f'Bearer {key}'}

def get(table):
    try:
        req = urllib.request.Request(f'{url}/rest/v1/{table}?select=*', headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        return f"Error: {e}"

clients = get('clients')
print('=== CLIENTS ===')
if isinstance(clients, list):
    for c in clients:
        print(f"ID: {c.get('id')} | Name: {c.get('company_name')} | Email: {c.get('email')} | Code: {c.get('client_code')}")
else:
    print(clients)

closers = get('client_closers')
print('\n=== CLIENT CLOSERS ===')
if isinstance(closers, list):
    for cl in closers:
        print(f"ID: {cl.get('id')} | Name: {cl.get('full_name')} | Email: {cl.get('email')} | ClientID: {cl.get('client_id')} | Status: {cl.get('status')} | Avatar: {cl.get('avatar_url')}")
else:
    print(closers)

users = get('users')
print('\n=== USERS (Closers & Clients) ===')
if isinstance(users, list):
    for u in users:
        if u.get('role') in ['closer', 'client', 'client_closer']:
            print(f"ID: {u.get('id')} | Role: {u.get('role')} | Email: {u.get('email')} | Name: {u.get('first_name')} {u.get('last_name')} | Avatar: {u.get('avatar_url')}")
else:
    print(users)

convs = get('order_conversations')
print('\n=== ORDER CONVERSATIONS ===')
if isinstance(convs, list):
    print(f"Total conversations: {len(convs)}")
    for cv in convs:
        print(f"ID: {cv.get('id')} | OrderNo: {cv.get('order_number')} | CloserID: {cv.get('closer_id')} | CloserName: {cv.get('closer_name')} | ClientID: {cv.get('client_id')}")
else:
    print(convs)

orders = get('orders')
print('\n=== ORDERS WITH CLOSER ATTRIBUTION ===')
if isinstance(orders, list):
    print(f"Total orders: {len(orders)}")
    for o in orders:
        if o.get('closer_id') or o.get('closer_name') or o.get('closer_code'):
            print(f"Order: {o.get('order_number')} | CloserID: {o.get('closer_id')} | CloserName: {o.get('closer_name')} | CloserCode: {o.get('closer_code')}")
else:
    print(orders)
