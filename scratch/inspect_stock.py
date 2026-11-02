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

print("=== 1. CLIENTS ===")
clients = query('clients?select=id,company_name,client_code,status')
print(f"Total clients: {len(clients) if clients else 0}")
novacare_id = None
for c in (clients or []):
    print(" ", c)
    if 'novacare' in c.get('company_name', '').lower() or 'CLI-S1-212' in str(c.get('client_code', '')):
        novacare_id = c.get('id')

print(f"\nNovacare client ID: {novacare_id}")

print("\n=== 2. PRODUCTS ===")
products = query('products?select=id,name,sku,client_id,stock_quantity,price')
print(f"Total products: {len(products) if products else 0}")
for p in (products or []):
    print(" ", p)

print("\n=== 3. CLIENT_STOCK_BALANCES ===")
balances = query('client_stock_balances?select=*')
print(f"Total client_stock_balances rows: {len(balances) if balances else 0}")
for b in (balances or []):
    print(" ", b)

print("\n=== 4. STOCK_INVOICES ===")
invoices = query('stock_invoices?select=*')
print(f"Total stock_invoices rows: {len(invoices) if invoices else 0}")
for inv in (invoices or []):
    print(" ", inv)

print("\n=== 5. ORDERS IN CIRCULATION ===")
orders = query('orders?select=id,order_number,product_name,quantity,status,delivery_state,client_id&limit=20')
print(f"Total sample orders: {len(orders) if orders else 0}")
for o in (orders or []):
    print(" ", o)
