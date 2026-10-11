import io
import sys
import json
import urllib.request
import urllib.error

# Ensure UTF-8 stdout for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

tables = [
    "companies", "distribution_centers", "warehouses", "users", "delivery_agents",
    "clients", "products", "orders", "client_stock_balances", "packages", "stock_transfers"
]

print(f"Checking tables on {URL}...")
for t in tables:
    req = urllib.request.Request(f"{URL}/rest/v1/{t}?select=id&limit=1", headers={
        "apikey": KEY,
        "Authorization": f"Bearer {KEY}",
        "Range-Unit": "items",
        "Range": "0-0",
        "Prefer": "count=exact"
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            content_range = resp.headers.get("Content-Range")
            count = content_range.split("/")[-1] if content_range else "unknown"
            print(f"  [OK] {t:<25} Count: {count}")
    except urllib.error.HTTPError as e:
        print(f"  [FAIL] {t:<25} HTTP {e.code}: {e.reason}")
    except Exception as e:
        print(f"  [ERR] {t:<25} {e}")
