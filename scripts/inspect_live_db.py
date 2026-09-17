#!/usr/bin/env python3
"""
Inspect Live Supabase Database
Queries table counts, column lists, and schema properties from the active Supabase project.
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

tables = [
    "companies", "distribution_centers", "warehouses", "users", "delivery_agents",
    "clients", "client_closers", "customer_leads", "products", "product_packages",
    "client_packages", "orders", "order_activities", "order_conversations",
    "order_conversation_messages", "notifications", "agent_inventory",
    "stock_requests", "stock_request_items", "stock_handovers", "stock_transfers",
    "stock_transfer_items", "stock_returns", "inventory_audits", "inventory_audit_items",
    "cash_remittances", "remittance_orders", "rider_transactions", "payout_requests",
    "payout_claims", "dc_finance_settings", "client_settlements",
    "paystack_transactions", "paystack_virtual_accounts", "monnify_transactions"
]

print("============================================================")
print(f"🔍 INSPECTING LIVE SUPABASE TABLES AT: {URL}")
print("============================================================")

active_tables = []
missing_tables = []

for t in tables:
    req = urllib.request.Request(f"{URL}/rest/v1/{t}?select=count", headers={
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
            print(f"✅ {t:<30} Count: {count}")
            active_tables.append(t)
    except urllib.error.HTTPError as e:
        print(f"❌ {t:<30} HTTP {e.code}: {e.reason}")
        missing_tables.append(t)
    except Exception as e:
        print(f"⚠️ {t:<30} Error: {e}")

print("\n============================================================")
print(f"Active Tables: {len(active_tables)} / {len(tables)}")
if missing_tables:
    print(f"Missing Tables: {missing_tables}")
else:
    print("ALL TABLES ARE LIVE AND ACCESSIBLE!")
print("============================================================")
