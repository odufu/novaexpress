import io
import sys
import os
import json
import urllib.request
import urllib.error

os.environ['no_proxy'] = '*'

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
SERVICE_ROLE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ."
    "2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
)

AUTH_HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}

REST_HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates,return=representation",
}

PASSWORD = "Password123!"

# Canonical Grand DC Identifiers
GRAND_COMPANY_ID = "11111111-1111-4111-8111-111111111111"
GRAND_DC_ID = "22222222-2222-4222-8222-222222222222"
GRAND_DC_USER_ID = "a2222222-2222-4222-8222-222222222222"
GRAND_DC_EMAIL = "dc.supervisor@novaxpress.ng"

def api_call(url, data=None, method="GET", headers=REST_HEADERS):
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else None
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"[-] HTTP Error [{e.code}] on {url}: {err[:200]}", flush=True)
        return None
    except Exception as ex:
        print(f"[-] Request error on {url}: {ex}", flush=True)
        return None

def purge_table(table_name):
    # Try deleting all records where id is not 00000000-0000-0000-0000-000000000000 or similar
    url = f"{URL}/rest/v1/{table_name}?id=neq.00000000-0000-0000-0000-000000000000"
    api_call(url, method="DELETE")
    print(f"  ✓ Purged table: {table_name}", flush=True)

def step1_wipe_all_operational_data():
    print("\n--- STEP 1: PURGING ALL OPERATIONAL, TRANSACTIONAL & MOCK CATALOG DATA ---", flush=True)
    tables_to_wipe = [
        "order_conversation_messages",
        "order_conversations",
        "conversation_messages",
        "order_items",
        "client_package_pickups",
        "rider_transactions",
        "paystack_transactions",
        "cash_remittances",
        "payout_requests",
        "client_settlements",
        "business_expenditures",
        "orders",
        "stock_transfer_items",
        "stock_transfer_requests",
        "stock_transfers",
        "stock_intakes",
        "inventory_ledger_records",
        "stock_audit_logs",
        "client_stock_invoice_items",
        "client_stock_invoices",
        "client_stock_balances",
        "upsell_configurations",
        "package_deals",
        "product_variants",
        "products",
        "b2b_clients",
        "customer_leads",
        "client_closers",
        "digital_marketers",
        "delivery_agents",
        "clients",
        "notifications",
    ]

    for t in tables_to_wipe:
        purge_table(t)

def step2_purge_non_grand_infrastructure():
    print("\n--- STEP 2: PURGING SECONDARY HUBS & NON-HQ COMPANIES ---", flush=True)
    # 1. Distribution Centers: keep only Grand DC
    del_dcs_url = f"{URL}/rest/v1/distribution_centers?id=neq.{GRAND_DC_ID}"
    api_call(del_dcs_url, method="DELETE")
    print("  ✓ Purged all non-Grand distribution centers", flush=True)

    # 2. Companies: keep only NovaXpress Logistics HQ
    del_comp_url = f"{URL}/rest/v1/companies?id=neq.{GRAND_COMPANY_ID}"
    api_call(del_comp_url, method="DELETE")
    print("  ✓ Purged all non-HQ companies", flush=True)

    # 3. Public Users: keep only Grand DC user
    del_users_url = f"{URL}/rest/v1/users?id=neq.{GRAND_DC_USER_ID}"
    api_call(del_users_url, method="DELETE")
    print("  ✓ Purged all non-Grand DC public users", flush=True)

def step3_ensure_grand_dc_infrastructure():
    print("\n--- STEP 3: ENSURING PRISTINE GRAND DC INFRASTRUCTURE & SETTINGS ---", flush=True)
    # Ensure HQ Company
    company_row = [{
        "id": GRAND_COMPANY_ID,
        "name": "NovaXpress Logistics HQ",
        "type": "logistics",
        "company_type": "logistics",
        "is_active": True,
    }]
    api_call(f"{URL}/rest/v1/companies", company_row, method="POST")
    print("  ✓ Ensured NovaXpress Logistics HQ Company record", flush=True)

    # Ensure Grand DC
    grand_dc_row = [{
        "id": GRAND_DC_ID,
        "company_id": GRAND_COMPANY_ID,
        "name": "Wuse Grand Central Distribution Center",
        "code": "DC-WUSE-01",
        "state": "Abuja (FCT)",
        "city": "Wuse 2",
        "address": "Plot 402 Aminu Kano Crescent, Wuse 2, Abuja",
        "contact_email": GRAND_DC_EMAIL,
        "contact_phone": "+2348023456789",
        "manager_name": "Ahmed Bello",
        "is_active": True,
        "is_main_dc": True,
        "is_hub": True,
    }]
    api_call(f"{URL}/rest/v1/distribution_centers", grand_dc_row, method="POST")
    print("  ✓ Ensured Wuse Grand Central Distribution Center", flush=True)

def step4_cleanup_and_ensure_grand_dc_auth():
    print("\n--- STEP 4: CLEANING AUTH USERS & PROVISIONING GRAND DC ACCOUNT ---", flush=True)
    # Fetch all auth users
    list_url = f"{URL}/auth/v1/admin/users?per_page=100"
    res = api_call(list_url, headers=AUTH_HEADERS)
    users = res.get("users", []) if res else []
    
    grand_dc_auth_id = None
    preserved_emails = {GRAND_DC_EMAIL.lower(), "dc.supervisor@novaexpress.ng".lower()}

    # Delete all other auth users
    for u in users:
        email = u.get("email", "").lower()
        uid = u.get("id")
        if email in preserved_emails:
            if email == GRAND_DC_EMAIL.lower():
                grand_dc_auth_id = uid
                # Update password and metadata
                update_url = f"{URL}/auth/v1/admin/users/{uid}"
                update_data = {
                    "password": PASSWORD,
                    "email_confirm": True,
                    "user_metadata": {
                        "first_name": "Ahmed",
                        "last_name": "Bello",
                        "role": "dc_manager",
                        "distribution_center_id": GRAND_DC_ID,
                        "email_verified": True,
                    }
                }
                api_call(update_url, update_data, method="PUT", headers=AUTH_HEADERS)
                print(f"  ✓ Updated Grand DC Auth User ({email}) -> ID: {uid}", flush=True)
        else:
            del_url = f"{URL}/auth/v1/admin/users/{uid}"
            api_call(del_url, method="DELETE", headers=AUTH_HEADERS)
            print(f"  🗑️ Purged Auth User: {email} ({uid})", flush=True)

    if not grand_dc_auth_id:
        create_url = f"{URL}/auth/v1/admin/users"
        create_data = {
            "email": GRAND_DC_EMAIL,
            "password": PASSWORD,
            "email_confirm": True,
            "user_metadata": {
                "first_name": "Ahmed",
                "last_name": "Bello",
                "role": "dc_manager",
                "distribution_center_id": GRAND_DC_ID,
                "email_verified": True,
            }
        }
        created = api_call(create_url, create_data, method="POST", headers=AUTH_HEADERS)
        grand_dc_auth_id = created.get("id")
        print(f"  ✓ Created fresh Grand DC Auth User ({GRAND_DC_EMAIL}) -> ID: {grand_dc_auth_id}", flush=True)

    # Upsert public.users row
    user_row = [{
        "id": GRAND_DC_USER_ID,
        "auth_user_id": grand_dc_auth_id,
        "company_id": GRAND_COMPANY_ID,
        "role": "dc_manager",
        "first_name": "Ahmed",
        "last_name": "Bello",
        "email": GRAND_DC_EMAIL,
        "phone": "+2348023456789",
        "phone_number": "+2348023456789",
        "is_active": True,
        "operating_state": "Abuja (FCT)",
        "operating_city": "Abuja",
        "distribution_center_id": GRAND_DC_ID,
        "distribution_center_name": "Wuse Grand Central Distribution Center",
    }]
    api_call(f"{URL}/rest/v1/users", user_row, method="POST")
    print(f"  ✓ Ensured public.users row for Grand DC Supervisor (ID: {GRAND_DC_USER_ID})", flush=True)

def step5_verify_clean_state():
    print("\n--- STEP 5: VERIFYING CLEAN STATE ---", flush=True)
    check_tables = [
        "orders", "products", "clients", "delivery_agents", "client_closers",
        "business_expenditures", "client_package_pickups", "distribution_centers",
        "users", "companies"
    ]
    for t in check_tables:
        res = api_call(f"{URL}/rest/v1/{t}?select=id")
        count = len(res) if res is not None else 0
        print(f"  • {t:25}: {count} records remaining")

    # Verify Auth sign-in
    login_url = f"{URL}/auth/v1/token?grant_type=password"
    anon_key = (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
        "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0."
        "o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc"
    )
    res = api_call(login_url, {"email": GRAND_DC_EMAIL, "password": PASSWORD}, method="POST", headers={
        "apikey": anon_key, "Content-Type": "application/json"
    })
    if res and res.get("access_token"):
        print(f"\n  ✅ [AUTH VERIFIED] Grand DC Login ({GRAND_DC_EMAIL}) SUCCESSFUL!")
    else:
        print(f"\n  ❌ [AUTH FAILED] Could not sign in with {GRAND_DC_EMAIL}")

def main():
    print("=" * 65)
    print("NOVAEXPRESS: EXECUTING PRISTINE GRAND DC CLEAN-SLATE RESET")
    print("=" * 65)
    step1_wipe_all_operational_data()
    step2_purge_non_grand_infrastructure()
    step3_ensure_grand_dc_infrastructure()
    step4_cleanup_and_ensure_grand_dc_auth()
    step5_verify_clean_state()
    print("=" * 65)
    print("CLEAN SLATE RESET COMPLETE! ONLY GRAND DC REMAINS.")
    print("=" * 65)

if __name__ == "__main__":
    main()
