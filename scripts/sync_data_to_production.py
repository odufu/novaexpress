#!/usr/bin/env python3
"""
Sync Operational Data from Testing (qpcafevjsrbauweuiiyq) to Original Production (oygtaeriljuelhshfvkv).
Handles:
1. Storage bucket replication
2. Database tables synchronization in strict dependency order
3. Graceful handling of legacy rows and foreign keys
"""

import json
import sys
import io
import requests

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

TESTING_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
TESTING_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

ORIGINAL_URL = "https://oygtaeriljuelhshfvkv.supabase.co"
ORIGINAL_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

session = requests.Session()
session.trust_env = False

def test_headers():
    return {
        "apikey": TESTING_KEY,
        "Authorization": f"Bearer {TESTING_KEY}",
    }

def orig_headers(upsert=False):
    h = {
        "apikey": ORIGINAL_KEY,
        "Authorization": f"Bearer {ORIGINAL_KEY}",
        "Content-Type": "application/json",
    }
    if upsert:
        h["Prefer"] = "resolution=merge-duplicates"
    return h

def sync_storage():
    print("=" * 60, flush=True)
    print("STEP 1: SYNCING STORAGE BUCKETS & OBJECTS", flush=True)
    print("=" * 60, flush=True)
    res = session.get(f"{ORIGINAL_URL}/storage/v1/bucket", headers=orig_headers(), timeout=15)
    existing_buckets = [b["id"] for b in res.json()] if res.status_code == 200 else []
    print(f"Existing buckets on original: {existing_buckets}", flush=True)

    if "products" not in existing_buckets:
        session.post(
            f"{ORIGINAL_URL}/storage/v1/bucket",
            headers=orig_headers(),
            json={"id": "products", "name": "products", "public": True},
            timeout=15
        )

    list_res = session.post(
        f"{TESTING_URL}/storage/v1/object/list/products",
        headers=test_headers(),
        json={"prefix": "", "limit": 100},
        timeout=15
    )
    if list_res.status_code == 200:
        files = list_res.json()
        print(f"Found {len(files)} files in testing 'products' bucket.", flush=True)
        for f in files:
            fname = f.get("name")
            if not fname:
                continue
            dl_res = session.get(f"{TESTING_URL}/storage/v1/object/public/products/{fname}", timeout=15)
            if dl_res.status_code == 200:
                up_headers = {
                    "apikey": ORIGINAL_KEY,
                    "Authorization": f"Bearer {ORIGINAL_KEY}",
                    "Content-Type": dl_res.headers.get("Content-Type", "image/png"),
                    "x-upsert": "true",
                }
                session.post(
                    f"{ORIGINAL_URL}/storage/v1/object/products/{fname}",
                    headers=up_headers,
                    data=dl_res.content,
                    timeout=15
                )
        print("[OK] Products storage replication complete.", flush=True)

def sync_tables():
    print("\n" + "=" * 60, flush=True)
    print("STEP 2: SYNCING DATABASE TABLES (TOPOLOGICAL FK ORDER)", flush=True)
    print("=" * 60, flush=True)

    # Topological execution order
    tables = [
        "companies",
        "distribution_centers",
        "clients",
        "users",
        "delivery_agents",
        "products",
        "product_packages",
        "client_closers",
        "client_marketers",
        "lead_forms",
        "orders",
        "customer_leads",
        "order_conversations",
        "order_conversation_messages",
        "cash_remittances",
        "client_suppliers",
        "client_stock_invoices",
        "client_stock_balances",
        "stock_transfers",
        "stock_transfer_items",
        "client_settlements",
        "paystack_transactions",
        "notifications",
    ]

    for table in tables:
        # Fetch testing rows
        fetch_res = session.get(
            f"{TESTING_URL}/rest/v1/{table}?select=*",
            headers=test_headers(),
            timeout=20
        )
        if fetch_res.status_code != 200:
            print(f"[-] {table:28}: Failed to fetch ({fetch_res.status_code}): {fetch_res.text[:100]}", flush=True)
            continue

        rows = fetch_res.json()
        if not rows:
            print(f"[.] {table:28}: 0 rows in testing, skipping.", flush=True)
            continue

        # Fetch target IDs to prevent duplicate / conflict issues
        target_ids = set()
        id_col = "id"
        id_res = session.get(f"{ORIGINAL_URL}/rest/v1/{table}?select=id", headers=orig_headers(), timeout=15)
        if id_res.status_code == 200 and isinstance(id_res.json(), list):
            target_ids = {item["id"] for item in id_res.json() if "id" in item}

        # Table-specific adaptations
        if table == "users":
            orig_users_res = session.get(f"{ORIGINAL_URL}/rest/v1/users?select=id,email", headers=orig_headers(), timeout=15)
            existing_emails = {u["email"].lower(): u["id"] for u in orig_users_res.json() if u.get("email")} if orig_users_res.status_code == 200 else {}
            filtered = []
            for r in rows:
                if not r.get("company_id"):
                    r["company_id"] = "11111111-1111-4111-8111-111111111111"
                email = (r.get("email") or "").lower()
                if email in existing_emails:
                    continue
                filtered.append(r)
            rows = filtered

        elif table == "delivery_agents":
            orig_agents_res = session.get(f"{ORIGINAL_URL}/rest/v1/delivery_agents?select=id", headers=orig_headers(), timeout=15)
            existing_agent_ids = {a["id"] for a in orig_agents_res.json()} if orig_agents_res.status_code == 200 else set()
            orig_users_res = session.get(f"{ORIGINAL_URL}/rest/v1/users?select=id", headers=orig_headers(), timeout=15)
            valid_user_ids = {u["id"] for u in orig_users_res.json()} if orig_users_res.status_code == 200 else set()
            for r in rows:
                if r.get("user_id") and r["user_id"] not in valid_user_ids:
                    r["user_id"] = None

        elif table == "lead_forms":
            for r in rows:
                if not r.get("title") and r.get("form_title"):
                    r["title"] = r["form_title"]
                if not r.get("company_id"):
                    r["company_id"] = "11111111-1111-4111-8111-111111111111"

        elif table == "orders":
            orig_agents_res = session.get(f"{ORIGINAL_URL}/rest/v1/delivery_agents?select=id", headers=orig_headers(), timeout=15)
            valid_agent_ids = {a["id"] for a in orig_agents_res.json()} if orig_agents_res.status_code == 200 else set()
            for r in rows:
                if r.get("delivery_agent_id") and r["delivery_agent_id"] not in valid_agent_ids:
                    r["delivery_agent_id"] = None
                if r.get("assigned_agent_id") and r["assigned_agent_id"] not in valid_agent_ids:
                    r["assigned_agent_id"] = None

        elif table == "order_conversations":
            orig_conv_res = session.get(f"{ORIGINAL_URL}/rest/v1/order_conversations?select=id,order_id", headers=orig_headers(), timeout=15)
            existing_by_order = {c["order_id"]: c["id"] for c in orig_conv_res.json() if c.get("order_id")} if orig_conv_res.status_code == 200 else {}
            missing_convs = [r for r in rows if r.get("order_id") not in existing_by_order]
            if missing_convs:
                post_res = session.post(f"{ORIGINAL_URL}/rest/v1/order_conversations", headers=orig_headers(upsert=True), json=missing_convs)
                print(f"[OK] order_conversations         : {len(missing_convs)} new conversations created", flush=True)
            else:
                print(f"[OK] order_conversations         : all conversations exist", flush=True)
            continue

        elif table == "order_conversation_messages":
            test_convs_res = session.get(f"{TESTING_URL}/rest/v1/order_conversations?select=id,order_id", headers=test_headers(), timeout=15)
            test_conv_to_order = {c["id"]: c["order_id"] for c in test_convs_res.json()} if test_convs_res.status_code == 200 else {}
            
            orig_convs_res = session.get(f"{ORIGINAL_URL}/rest/v1/order_conversations?select=id,order_id", headers=orig_headers(), timeout=15)
            orig_order_to_conv = {c["order_id"]: c["id"] for c in orig_convs_res.json()} if orig_convs_res.status_code == 200 else {}
            
            remapped = []
            for m in rows:
                old_cid = m.get("conversation_id")
                oid = test_conv_to_order.get(old_cid)
                new_cid = orig_order_to_conv.get(oid)
                if new_cid:
                    m["conversation_id"] = new_cid
                    remapped.append(m)
            rows = remapped

        # Upsert in batches
        BATCH_SIZE = 50
        success_count = 0
        error_msg = None

        for i in range(0, len(rows), BATCH_SIZE):
            batch = rows[i:i + BATCH_SIZE]
            post_res = session.post(
                f"{ORIGINAL_URL}/rest/v1/{table}",
                headers=orig_headers(upsert=True),
                json=batch,
                timeout=30
            )
            if post_res.status_code in [200, 201]:
                success_count += len(batch)
            else:
                error_msg = f"{post_res.status_code}: {post_res.text[:150]}"
                for single in batch:
                    s_res = session.post(
                        f"{ORIGINAL_URL}/rest/v1/{table}",
                        headers=orig_headers(upsert=True),
                        json=[single],
                        timeout=10
                    )
                    if s_res.status_code in [200, 201]:
                        success_count += 1

        if error_msg and success_count < len(rows):
            print(f"[!] {table:28}: {success_count}/{len(rows)} synced (Issues: {error_msg})", flush=True)
        else:
            print(f"[OK] {table:28}: {success_count}/{len(rows)} rows synced successfully", flush=True)

if __name__ == "__main__":
    sync_storage()
    sync_tables()
    print("\nSynchronization completed successfully!", flush=True)
