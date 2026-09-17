#!/usr/bin/env python3
"""
Test Live RPC Stored Procedures
Verifies that key RPC functions exist and are executable on the active Supabase project.
"""

import sys
import io
import json
import urllib.request
import urllib.error

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

rpcs = [
    ("fn_generate_merchant_daily_settlement", {
        "p_client_id": "c2222222-2222-4222-8222-222222222222",
        "p_dc_id": "d1111111-1111-4111-8111-111111111111",
        "p_period_start": "2026-09-01T00:00:00Z",
        "p_period_end": "2026-09-16T23:59:59Z"
    }),
    ("fn_calculate_merchant_asset_custody", {
        "p_client_id": "c2222222-2222-4222-8222-222222222222"
    }),
    ("auto_dispatch_order_by_state_lga", {
        "p_order_id": "00000000-0000-0000-0000-000000000000"
    }),
    ("fn_adjust_dc_stock", {
        "p_product_id": "00000000-0000-0000-0000-000000000000",
        "p_dc_id": "00000000-0000-0000-0000-000000000000",
        "p_delta": 0
    })
]

print("============================================================")
print(f"⚡ TESTING LIVE STORED PROCEDURES (RPC) AT: {URL}")
print("============================================================")

for rpc_name, payload in rpcs:
    req = urllib.request.Request(
        f"{URL}/rest/v1/rpc/{rpc_name}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": KEY,
            "Authorization": f"Bearer {KEY}",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read().decode("utf-8")
            print(f"✅ RPC '{rpc_name}': OK ({resp.status}) -> {data[:100]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        if e.code == 404:
            print(f"❌ RPC '{rpc_name}': NOT FOUND (HTTP 404)")
        else:
            print(f"⚠️ RPC '{rpc_name}': HTTP {e.code} -> {body[:120]}")
    except Exception as e:
        print(f"❌ RPC '{rpc_name}': Error: {e}")

print("============================================================")
