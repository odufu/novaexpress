#!/usr/bin/env python3
"""
NovaXpress Supabase Data Export Tool
Exports all active tables and records from a Supabase project into a structured JSON backup.
"""

import sys
import os
import json
import io
import urllib.request
import urllib.error
from datetime import datetime

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

# Tables exported in strict foreign-key dependency order
EXPORT_TABLES = [
    "companies",
    "distribution_centers",
    "warehouses",
    "users",
    "delivery_agents",
    "clients",
    "client_closers",
    "customer_leads",
    "products",
    "product_packages",
    "client_packages",
    "product_batches",
    "dc_finance_settings",
    "orders",
    "order_activities",
    "order_conversations",
    "order_conversation_messages",
    "stock_transfers",
    "stock_transfer_items",
    "stock_handovers",
    "stock_requests",
    "stock_request_items",
    "stock_returns",
    "agent_inventory",
    "cash_remittances",
    "remittance_orders",
    "rider_transactions",
    "paystack_virtual_accounts",
    "paystack_transactions",
    "monnify_virtual_accounts",
    "monnify_transactions",
    "inventory_audits",
    "inventory_audit_items",
    "client_settlements",
    "payout_requests",
    "payout_claims",
    "notifications"
]

def fetch_table_data(base_url, service_key, table_name):
    url = f"{base_url}/rest/v1/{table_name}?select=*"
    req = urllib.request.Request(url)
    req.add_header("apikey", service_key)
    req.add_header("Authorization", f"Bearer {service_key}")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data
    except urllib.error.HTTPError as e:
        print(f"   ⚠️ Table '{table_name}': HTTP {e.code} - {e.reason}")
    except Exception as e:
        print(f"   ⚠️ Table '{table_name}': {str(e)}")
    return []

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Export NovaXpress Supabase Database Data")
    parser.add_argument("--url", type=str, help="Source Supabase Project URL")
    parser.add_argument("--service-key", type=str, help="Source Supabase Service Role Key")
    parser.add_argument("--out", type=str, help="Output JSON file path")

    args = parser.parse_args()

    # Fallback to active constants in supabase_constants.dart if omitted
    base_url = args.url
    service_key = args.service_key

    if not base_url or not service_key:
        constants_path = os.path.join("lib", "core", "constants", "supabase_constants.dart")
        if os.path.exists(constants_path):
            with open(constants_path, "r", encoding="utf-8") as f:
                code = f.read()
            import re
            m_url = re.search(r"static const String _defaultUrl = ['\"]([^'\"]+)['\"]", code)
            m_key = re.search(r"static const String _defaultServiceRoleKey =\s*['\"]([^'\"]+)['\"]", code)
            if m_url and not base_url:
                base_url = m_url.group(1)
            if m_key and not service_key:
                service_key = m_key.group(1)

    if not base_url or not service_key:
        print("❌ Error: Supabase URL and Service Role Key are required.")
        sys.exit(1)

    print("============================================================")
    print("📦 NOVEXPS SUPABASE DATA EXPORTER")
    print(f"Source URL: {base_url}")
    print("============================================================")

    os.makedirs("backups", exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = args.out or os.path.join("backups", f"supabase_export_{timestamp}.json")

    backup_bundle = {
        "metadata": {
            "source_url": base_url,
            "exported_at": datetime.now().isoformat(),
            "generator": "NovaXpress Migration Toolkit v2"
        },
        "tables": {}
    }

    total_records = 0
    for tbl in EXPORT_TABLES:
        print(f"Fetching table: {tbl}...")
        records = fetch_table_data(base_url, service_key, tbl)
        backup_bundle["tables"][tbl] = records
        total_records += len(records)
        print(f"   ✅ {len(records)} records extracted.")

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(backup_bundle, f, indent=2, ensure_ascii=False)

    print("\n============================================================")
    print(f"🎉 EXPORT COMPLETE! Total records: {total_records}")
    print(f"Saved to: {out_file}")
    print("============================================================")

if __name__ == "__main__":
    main()
