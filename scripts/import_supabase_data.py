#!/usr/bin/env python3
"""
NovaExpress Supabase Data Import Tool
Imports an exported JSON database backup into a target Supabase project using conflict-safe upserts.
"""

import sys
import os
import json
import io
import urllib.request
import urllib.error

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

# Tables imported in strict foreign-key dependency order
IMPORT_TABLES_ORDER = [
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

def upsert_table_data(base_url, service_key, table_name, records):
    if not records or len(records) == 0:
        return 0

    url = f"{base_url}/rest/v1/{table_name}"
    
    # Process in batches of 50 to prevent large payload timeouts
    batch_size = 50
    inserted_count = 0

    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        payload_bytes = json.dumps(batch).encode("utf-8")

        req = urllib.request.Request(url, data=payload_bytes, method="POST")
        req.add_header("apikey", service_key)
        req.add_header("Authorization", f"Bearer {service_key}")
        req.add_header("Content-Type", "application/json")
        req.add_header("Prefer", "resolution=merge-duplicates")

        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status in (200, 201):
                    inserted_count += len(batch)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            print(f"   ⚠️ Batch failed for '{table_name}': HTTP {e.code} - {err_body}")
        except Exception as e:
            print(f"   ⚠️ Batch failed for '{table_name}': {str(e)}")

    return inserted_count

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Import NovaExpress Supabase Database Backup")
    parser.add_argument("--file", type=str, required=True, help="Path to exported backup JSON file")
    parser.add_argument("--url", type=str, help="Target Supabase Project URL")
    parser.add_argument("--service-key", type=str, help="Target Supabase Service Role Key")

    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"❌ Error: Backup file '{args.file}' not found.")
        sys.exit(1)

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
        print("❌ Error: Target Supabase URL and Service Role Key are required.")
        sys.exit(1)

    print("============================================================")
    print("📥 NOVEXPS SUPABASE DATA IMPORTER")
    print(f"Source file: {args.file}")
    print(f"Target URL:  {base_url}")
    print("============================================================")

    with open(args.file, "r", encoding="utf-8") as f:
        bundle = json.load(f)

    tables_data = bundle.get("tables", {})
    total_restored = 0

    for tbl in IMPORT_TABLES_ORDER:
        if tbl in tables_data and len(tables_data[tbl]) > 0:
            recs = tables_data[tbl]
            print(f"Restoring table: {tbl} ({len(recs)} records)...")
            count = upsert_table_data(base_url, service_key, tbl, recs)
            total_restored += count
            print(f"   ✅ {count}/{len(recs)} records restored successfully.")

    print("\n============================================================")
    print(f"🎉 RESTORE COMPLETE! Total records restored: {total_restored}")
    print("Target Supabase project is now populated with your live data.")
    print("============================================================")

if __name__ == "__main__":
    main()
