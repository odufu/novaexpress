import io
import sys
import os
import json
import urllib.request

os.environ['no_proxy'] = '*'

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json"
}

tables = [
    "orders",
    "order_items",
    "client_package_pickups",
    "b2b_clients",
    "business_expenditures",
    "products",
    "clients",
    "client_stock_balances",
    "client_stock_invoices",
    "distribution_centers",
    "delivery_agents",
    "client_closers",
    "users",
    "companies",
    "rider_transactions",
    "paystack_transactions",
    "cash_remittances",
]

print("=" * 60)
print("INSPECTING CURRENT DATABASE RECORD COUNTS ON LIVE SUPABASE")
print("=" * 60)

for t in tables:
    try:
        req = urllib.request.Request(f"{URL}/rest/v1/{t}?select=id", headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            print(f"- {t:28}: {len(data)} rows")
    except Exception as e:
        print(f"- {t:28}: error ({e})")

# Auth users
try:
    req = urllib.request.Request(f"{URL}/auth/v1/admin/users?per_page=100", headers=headers)
    with urllib.request.urlopen(req, timeout=10) as resp:
        users = json.loads(resp.read().decode()).get("users", [])
        print(f"\n- auth.users: {len(users)} users")
        for u in users:
            print(f"  • {u.get('email')} ({u.get('id')})")
except Exception as e:
    print(f"auth.users error: {e}")
