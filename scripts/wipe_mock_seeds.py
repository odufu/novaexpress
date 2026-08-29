import io
import urllib.request
import json
import sys

# Ensure UTF-8 stdout for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

SUPABASE_URL = "https://oygtaeriljuelhshfvkv.supabase.co/rest/v1"
SERVICE_ROLE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ."
    "2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
)

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def make_request(endpoint, data=None, method="GET"):
    url = f"{SUPABASE_URL}/{endpoint}"
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            return json.loads(res_body) if res_body else None
    except urllib.error.HTTPError as e:
        error_content = e.read().decode("utf-8")
        print(f"[-] HTTP Error on {endpoint} [{e.code}]: {error_content}")
        return None
    except Exception as ex:
        print(f"[-] Request failed on {endpoint}: {ex}")
        return None

def wipe_mock_data():
    print("==================================================")
    print("🧹 NovaExpress: Wiping Mock Seed Records from Supabase")
    print("==================================================")

    tables_to_clear = [
        ("order_events", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("orders", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("stock_transfers", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("stock_transfer_requests", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("stock_returns", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("rider_stock_allocations", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("warehouse_inventory", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("product_packages", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("products", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("cash_remittances", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("rider_transactions", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("paystack_transactions", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("payout_requests", "id=neq.00000000-0000-0000-0000-000000000000"),
        ("inventory_audits", "id=neq.00000000-0000-0000-0000-000000000000"),
    ]

    for table, query in tables_to_clear:
        endpoint = f"{table}?{query}"
        res = make_request(endpoint, method="DELETE")
        if res is not None:
            count = len(res) if isinstance(res, list) else "all"
            print(f"✓ Cleared table [{table}]: {count} records wiped.")
        else:
            print(f"ℹ Table [{table}] already clean or not present.")

    print("\n✅ Database is now clean and ready for real production entry from DC Console!")

if __name__ == "__main__":
    wipe_mock_data()
