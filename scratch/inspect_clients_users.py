import urllib.request
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI'
BASE = 'https://hwyqqjilcifxajruusoa.supabase.co/rest/v1'

def query(endpoint):
    req = urllib.request.Request(f'{BASE}/{endpoint}', headers={
        'apikey': SERVICE_KEY,
        'Authorization': f'Bearer {SERVICE_KEY}',
        'Content-Type': 'application/json'
    })
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTPError on {endpoint}: {e.code} - {e.read().decode()}")
        return None
    except Exception as e:
        print(f"Error on {endpoint}: {e}")
        return None

print("=== CLIENTS (ALL COLS) ===")
clients = query('clients?select=*')
print(f"Total clients: {len(clients) if clients else 0}")
for c in (clients or []):
    print("Client:", c)

print("\n=== USERS (ROLE = client OR CLIENT_ID NOT NULL) ===")
users = query('users?select=id,email,full_name,role,client_id,status')
for u in (users or []):
    if u.get('role') in ['client', 'merchant'] or 'nova' in str(u.get('email', '')).lower() or u.get('client_id'):
        print("User:", u)

print("\n=== PRODUCTS (ALL COLS) ===")
products = query('products?select=*')
print(f"Total products: {len(products) if products else 0}")
for p in (products or []):
    print("Product:", p)
