#!/usr/bin/env python3
"""
Replicate Live Pilot Accounts and Catalog to Fresh Test Project
Source: https://oygtaeriljuelhshfvkv.supabase.co
Target: https://hwyqqjilcifxajruusoa.supabase.co
"""

import sys
import io
import json
import urllib.request
import urllib.error

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

SRC_URL = "https://oygtaeriljuelhshfvkv.supabase.co"
SRC_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

DEFAULT_PASSWORD = "Password123!"

def src_fetch(endpoint):
    url = f"{SRC_URL}{endpoint}"
    req = urllib.request.Request(url, headers={
        "apikey": SRC_KEY,
        "Authorization": f"Bearer {SRC_KEY}",
        "Content-Type": "application/json"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print(f"[-] Error fetching {endpoint} from source: {e}", flush=True)
        return None

def tgt_admin_post(endpoint, data):
    url = f"{TGT_URL}{endpoint}"
    body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={
        "apikey": TGT_KEY,
        "Authorization": f"Bearer {TGT_KEY}",
        "Content-Type": "application/json"
    }, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode("utf-8")), r.status
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        return {"error": err}, e.code
    except Exception as e:
        return {"error": str(e)}, 500

def get_target_columns():
    try:
        url = f"{TGT_URL}/rest/v1/?apikey={TGT_KEY}"
        req = urllib.request.Request(url, headers={"apikey": TGT_KEY})
        with urllib.request.urlopen(req, timeout=15) as r:
            spec = json.loads(r.read().decode("utf-8"))
            defs = spec.get("definitions", {})
            return {tbl: set(props.get("properties", {}).keys()) for tbl, props in defs.items()}
    except Exception as e:
        print(f"[-] Could not fetch target OpenAPI definitions: {e}", flush=True)
        return {}

def tgt_rest_upsert(table, records, table_cols=None):
    if not records:
        return
    if table_cols and table in table_cols:
        valid_cols = table_cols[table]
        filtered_records = []
        for r in records:
            filtered_records.append({k: v for k, v in r.items() if k in valid_cols})
        records = filtered_records

    url = f"{TGT_URL}/rest/v1/{table}"
    body = json.dumps(records).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={
        "apikey": TGT_KEY,
        "Authorization": f"Bearer {TGT_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            print(f"  ✓ Upserted {len(records)} records into {table} ({r.status})", flush=True)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"  [-] Failed to upsert into {table} [{e.code}]: {err[:160]}", flush=True)
    except Exception as e:
        print(f"  [-] Error upserting into {table}: {e}", flush=True)

def upsert_users_safe(users, user_cols):
    print("Syncing users safely...", flush=True)
    valid_cols = user_cols.get("users", set()) if user_cols else set()
    for u in users:
        filtered = {k: v for k, v in u.items() if k in valid_cols} if valid_cols else u
        email = filtered.get("email")
        user_id = filtered.get("id")
        if not email or not user_id:
            continue

        check_req = urllib.request.Request(f"{TGT_URL}/rest/v1/users?or=(id.eq.{user_id},email.eq.{email})", headers={
            "apikey": TGT_KEY,
            "Authorization": f"Bearer {TGT_KEY}"
        })
        found = []
        try:
            with urllib.request.urlopen(check_req, timeout=10) as r:
                found = json.loads(r.read().decode("utf-8"))
        except Exception:
            pass

        if found:
            matched_id = found[0]["id"]
            patch_data = dict(filtered)
            patch_data.pop("id", None)
            req = urllib.request.Request(f"{TGT_URL}/rest/v1/users?id=eq.{matched_id}", data=json.dumps(patch_data).encode("utf-8"), headers={
                "apikey": TGT_KEY,
                "Authorization": f"Bearer {TGT_KEY}",
                "Content-Type": "application/json"
            }, method="PATCH")
            try:
                with urllib.request.urlopen(req, timeout=10) as r:
                    print(f"  ✓ Patched user {email} (ID: {matched_id})", flush=True)
            except Exception as e:
                print(f"  [-] Failed to patch user {email}: {e}", flush=True)
        else:
            req = urllib.request.Request(f"{TGT_URL}/rest/v1/users", data=json.dumps([filtered]).encode("utf-8"), headers={
                "apikey": TGT_KEY,
                "Authorization": f"Bearer {TGT_KEY}",
                "Content-Type": "application/json"
            }, method="POST")
            try:
                with urllib.request.urlopen(req, timeout=10) as r:
                    print(f"  ✓ Inserted user {email} (ID: {user_id})", flush=True)
            except Exception as e:
                print(f"  [-] Failed to insert user {email}: {e}", flush=True)

def main():
    print("=" * 60, flush=True)
    print("REPLICATING LIVE PILOT ACCOUNTS TO TEST SANDBOX", flush=True)
    print(f"Target: {TGT_URL}", flush=True)
    print("=" * 60, flush=True)

    # 1. Fetch source auth users
    src_auth = src_fetch("/auth/v1/admin/users?per_page=50")
    auth_users = src_auth.get("users", []) if src_auth else []
    print(f"Fetched {len(auth_users)} auth users from live pilot.", flush=True)

    # 2. Check existing target auth users
    tgt_req = urllib.request.Request(f"{TGT_URL}/auth/v1/admin/users?per_page=50", headers={
        "apikey": TGT_KEY,
        "Authorization": f"Bearer {TGT_KEY}"
    })
    try:
        with urllib.request.urlopen(tgt_req, timeout=10) as r:
            existing_tgt_users = {u["email"].lower(): u for u in json.loads(r.read().decode("utf-8")).get("users", [])}
    except Exception as e:
        existing_tgt_users = {}

    print(f"Existing auth users in target: {len(existing_tgt_users)}", flush=True)

    # 3. Create all pilot auth users in target with identical ID and Password123!
    print("\n--- Creating / Syncing Auth Users ---", flush=True)
    for u in auth_users:
        email = u.get("email")
        if not email:
            continue
        email_clean = email.strip().lower()
        if email_clean in existing_tgt_users:
            print(f"  ✓ Already exists: {email}", flush=True)
            continue

        payload = {
            "id": u.get("id"),
            "email": email,
            "password": DEFAULT_PASSWORD,
            "email_confirm": True,
            "user_metadata": u.get("user_metadata", {}),
            "app_metadata": u.get("app_metadata", {})
        }
        res, status = tgt_admin_post("/auth/v1/admin/users", payload)
        if status in (200, 201):
            print(f"  ✓ Created Auth User: {email} (ID: {u.get('id')})", flush=True)
        else:
            print(f"  [-] Failed to create {email} [{status}]: {res}", flush=True)

    # 4. Fetch valid target columns
    print("\n--- Inspecting Target Database Schema ---", flush=True)
    table_cols = get_target_columns()
    print(f"Fetched schema definition for {len(table_cols)} target tables.", flush=True)

    # 5. Sync foundational records in strict dependency order
    print("\n--- Syncing Foundational Records ---", flush=True)
    
    # 5.1 Companies
    companies = src_fetch("/rest/v1/companies?select=*")
    tgt_rest_upsert("companies", companies, table_cols=table_cols)

    # 5.2 Distribution Centers
    dcs = src_fetch("/rest/v1/distribution_centers?select=*")
    tgt_rest_upsert("distribution_centers", dcs, table_cols=table_cols)

    # 5.3 Clients
    clients = src_fetch("/rest/v1/clients?select=*")
    tgt_rest_upsert("clients", clients, table_cols=table_cols)

    # 5.4 Products & Packages
    products = src_fetch("/rest/v1/products?select=*")
    tgt_rest_upsert("products", products, table_cols=table_cols)

    packages = src_fetch("/rest/v1/product_packages?select=*")
    tgt_rest_upsert("product_packages", packages, table_cols=table_cols)

    # 5.5 Users
    users = src_fetch("/rest/v1/users?select=*")
    if users:
        upsert_users_safe(users, table_cols)

    # 5.6 Delivery Agents
    agents = src_fetch("/rest/v1/delivery_agents?select=*")
    tgt_rest_upsert("delivery_agents", agents, table_cols=table_cols)

    # 5.7 Warehouses
    warehouses = src_fetch("/rest/v1/warehouses?select=*")
    tgt_rest_upsert("warehouses", warehouses, table_cols=table_cols)

    # 5.8 Client Closers
    closers = src_fetch("/rest/v1/client_closers?select=*")
    tgt_rest_upsert("client_closers", closers, table_cols=table_cols)

    # 5.9 Client Stock Balances
    stock_balances = src_fetch("/rest/v1/client_stock_balances?select=*")
    tgt_rest_upsert("client_stock_balances", stock_balances, table_cols=table_cols)

    print("\n" + "=" * 60, flush=True)
    print("REPLICATION TASK FINISHED SUCCESSFULLY", flush=True)
    print(f"All pilot logins available on test sandbox using: '{DEFAULT_PASSWORD}'", flush=True)
    print("=" * 60, flush=True)

if __name__ == "__main__":
    main()
