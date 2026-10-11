import io
import sys
import json
import urllib.request
import urllib.error

# Ensure UTF-8 stdout for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

SUPABASE_URL = "https://oygtaeriljuelhshfvkv.supabase.co"
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0."
    "o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc"
)
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

# Core IDs
COMPANY_HQ_ID = "11111111-1111-4111-8111-111111111111"
CLIENT_COMPANY_ID = "00000000-0000-4000-8000-789382731303"
DC_WUSE_ID = "22222222-2222-4222-8222-222222222222"
DC_LAGOS_ID = "c1111111-1111-4111-8111-111111111111"

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

def wipe_transactional_data():
    print("\n--- 1. PURGING TRANSACTIONAL CLUTTER ---", flush=True)
    tables_to_purge = [
        "order_conversation_messages",
        "order_conversations",
        "conversation_messages",
        "order_items",
        "paystack_transactions",
        "cash_remittances",
        "rider_transactions",
        "payout_requests",
        "client_settlements",
        "stock_transfer_items",
        "stock_transfer_requests",
        "stock_transfers",
        "orders",
        "customer_leads",
        "notifications",
    ]
    for table in tables_to_purge:
        url = f"{SUPABASE_URL}/rest/v1/{table}?id=neq.00000000-0000-0000-0000-000000000000"
        api_call(url, method="DELETE")
        print(f"  ✓ Purged {table}", flush=True)

def ensure_infrastructure():
    print("\n--- 2. ENSURING CORE INFRASTRUCTURE ---", flush=True)
    # Companies
    companies = [
        {
            "id": COMPANY_HQ_ID,
            "name": "NovaXpress Logistics HQ",
            "type": "logistics",
            "company_type": "ecommerce",
            "is_active": True,
        },
        {
            "id": CLIENT_COMPANY_ID,
            "name": "Novacare Health & Wellness Ltd",
            "type": "logistics",
            "company_type": "ecommerce",
            "is_active": True,
        },
    ]
    api_call(f"{SUPABASE_URL}/rest/v1/companies", companies, method="POST")
    print("  ✓ Companies verified", flush=True)

    # Distribution Centers
    dcs = [
        {
            "id": DC_WUSE_ID,
            "company_id": COMPANY_HQ_ID,
            "name": "Wuse Central Distribution Hub",
            "code": "DC-WUSE-01",
            "state": "Abuja (FCT)",
            "city": "Wuse 2",
            "address": "Plot 402 Aminu Kano Crescent, Wuse 2, Abuja",
            "contact_email": "dc.supervisor@novaxpress.ng",
            "contact_phone": "+2348023456789",
            "manager_name": "Ahmed Bello",
            "is_active": True,
            "is_main_dc": True,
            "is_hub": True,
        },
        {
            "id": DC_LAGOS_ID,
            "company_id": COMPANY_HQ_ID,
            "name": "Lagos Central Factory Hub",
            "code": "DC-LOS-01",
            "state": "Lagos",
            "city": "Ikeja",
            "address": "14 Allen Avenue, Ikeja, Lagos",
            "contact_email": "dc.lagos@novaxpress.ng",
            "contact_phone": "+2348023456788",
            "manager_name": "Lagos Hub Supervisor",
            "is_active": True,
            "is_main_dc": False,
            "is_hub": True,
        },
    ]
    api_call(f"{SUPABASE_URL}/rest/v1/distribution_centers", dcs, method="POST")
    print("  ✓ Distribution Centers verified (Wuse Hub & Lagos Hub)", flush=True)

    # Client Profile in public.clients
    client_row = [
        {
            "id": CLIENT_COMPANY_ID,
            "company_id": COMPANY_HQ_ID,
            "name": "Novacare Health & Wellness Ltd",
            "company_name": "Novacare Health & Wellness Ltd",
            "code": "CLI-NOVACARE-01",
            "contact_person": "Dr. Chuka Okafor",
            "phone": "+2348034455667",
            "email": "merchant@novacare.com",
            "address": "Suite 12, Garki 2 Commercial Complex",
            "city": "Abuja",
            "state": "Abuja (FCT)",
            "is_active": True,
            "tier": "enterprise_merchant",
            "has_inventory_management": True,
        }
    ]
    api_call(f"{SUPABASE_URL}/rest/v1/clients", client_row, method="POST")
    print("  ✓ Client profile verified in public.clients", flush=True)

# Cache existing auth users map once
AUTH_CACHE = {}

def load_auth_cache():
    global AUTH_CACHE
    list_url = f"{SUPABASE_URL}/auth/v1/admin/users?per_page=100"
    res = api_call(list_url, headers=AUTH_HEADERS)
    users = res.get("users", []) if res else []
    for u in users:
        em = u.get("email", "").lower()
        if em:
            AUTH_CACHE[em] = u

def get_or_create_auth_user(email, password, user_metadata):
    clean = email.lower()
    if clean in AUTH_CACHE:
        u = AUTH_CACHE[clean]
        update_url = f"{SUPABASE_URL}/auth/v1/admin/users/{u['id']}"
        update_data = {
            "password": password,
            "email_confirm": True,
            "user_metadata": user_metadata,
        }
        api_call(update_url, update_data, method="PUT", headers=AUTH_HEADERS)
        print(f"  ✓ Updated Auth user password & metadata: {email} (ID: {u['id']})", flush=True)
        return u["id"]

    create_url = f"{SUPABASE_URL}/auth/v1/admin/users"
    create_data = {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": user_metadata,
    }
    created = api_call(create_url, create_data, method="POST", headers=AUTH_HEADERS)
    if created and created.get("id"):
        AUTH_CACHE[clean] = created
        print(f"  ✓ Created new Auth user: {email} (ID: {created['id']})", flush=True)
        return created["id"]
    else:
        print(f"  [-] Failed to create Auth user: {email} -> {created}", flush=True)
        return None

def upsert_public_user(user_data):
    email = user_data["email"]
    check = api_call(f"{SUPABASE_URL}/rest/v1/users?email=eq.{email}&select=id")
    if check and len(check) > 0:
        existing_id = check[0]["id"]
        # Update existing
        update_payload = dict(user_data)
        update_payload.pop("id", None)
        api_call(f"{SUPABASE_URL}/rest/v1/users?id=eq.{existing_id}", update_payload, method="PATCH")
        print(f"  ✓ public.users updated: {email} (ID: {existing_id})", flush=True)
        return existing_id
    else:
        api_call(f"{SUPABASE_URL}/rest/v1/users", [user_data], method="POST")
        print(f"  ✓ public.users inserted: {email} (ID: {user_data.get('id')})", flush=True)
        return user_data.get("id")

def seed_test_accounts():
    print("\n--- 3. CREATING / RESETTING TEST ACCOUNTS ---", flush=True)
    load_auth_cache()

    accounts = [
        {
            "role_title": "DC Supervisor",
            "primary_email": "dc.supervisor@novaxpress.ng",
            "alias_emails": ["dc.supervisor@novaexpress.ng"],
            "first_name": "Ahmed",
            "last_name": "Bello",
            "phone": "+2348023456789",
            "role": "dc_manager",
            "fixed_id": "a2222222-2222-4222-8222-222222222222",
            "dc_id": DC_WUSE_ID,
            "dc_name": "Wuse Central Distribution Hub",
            "metadata": {
                "first_name": "Ahmed",
                "last_name": "Bello",
                "role": "dc_manager",
                "distribution_center_id": DC_WUSE_ID,
            },
        },
        {
            "role_title": "Novacare Client / Merchant",
            "primary_email": "merchant@novacare.com",
            "alias_emails": ["client@novaxpress.ng", "client.novacale@novaxpress.ng"],
            "first_name": "Dr. Chuka",
            "last_name": "Okafor",
            "phone": "+2348034455667",
            "role": "client",
            "fixed_id": "de39fac1-7450-4fc7-b3dc-b62f7c2afad1",
            "client_id": CLIENT_COMPANY_ID,
            "metadata": {
                "first_name": "Dr. Chuka",
                "last_name": "Okafor",
                "role": "client",
                "client_id": CLIENT_COMPANY_ID,
            },
        },
        {
            "role_title": "Novacare Telesales Closer",
            "primary_email": "closer@novacare.com",
            "alias_emails": ["closer.amaka@novacale.ng", "chidinma.closer@novacare.com"],
            "first_name": "Amaka",
            "last_name": "Chioma",
            "phone": "+2348021122334",
            "role": "closer",
            "fixed_id": "44444444-4444-4444-8444-444444444444",
            "closer_code": "CLS-NOVA-001",
            "client_id": CLIENT_COMPANY_ID,
            "metadata": {
                "first_name": "Amaka",
                "last_name": "Chioma",
                "role": "closer",
                "closer_code": "CLS-NOVA-001",
                "client_id": CLIENT_COMPANY_ID,
            },
        },
        {
            "role_title": "Field Delivery Agent / Rider",
            "primary_email": "rider.emeka@novaxpress.com",
            "alias_emails": ["emeka.rider@novaxpress.ng", "rider.emeka@novaexpress.com"],
            "first_name": "Emeka",
            "last_name": "Rider",
            "phone": "+2348012345678",
            "role": "delivery_agent",
            "fixed_id": "b1111111-1111-4111-8111-111111111111",
            "agent_code": "PDA-7000",
            "dc_id": DC_WUSE_ID,
            "metadata": {
                "first_name": "Emeka",
                "last_name": "Rider",
                "role": "delivery_agent",
                "personnel_type": "pda",
                "agent_code": "PDA-7000",
            },
        },
    ]

    for acc in accounts:
        print(f"\nSetting up [{acc['role_title']}]...", flush=True)
        # 1. Primary Email in Auth
        auth_id = get_or_create_auth_user(acc["primary_email"], PASSWORD, acc["metadata"])

        # 2. Alias Emails in Auth (so all quick-select variations work)
        for alias in acc["alias_emails"]:
            get_or_create_auth_user(alias, PASSWORD, acc["metadata"])

        # 3. public.users row
        user_row = {
            "id": acc["fixed_id"],
            "auth_user_id": auth_id,
            "company_id": COMPANY_HQ_ID,
            "role": acc["role"],
            "first_name": acc["first_name"],
            "last_name": acc["last_name"],
            "email": acc["primary_email"],
            "phone": acc["phone"],
            "phone_number": acc["phone"],
            "is_active": True,
            "operating_state": "Abuja (FCT)",
            "operating_city": "Abuja",
        }
        if "dc_id" in acc:
            user_row["distribution_center_id"] = acc["dc_id"]
            user_row["distribution_center_name"] = acc.get("dc_name", "Wuse Central Hub")
        if "client_id" in acc:
            user_row["client_id"] = acc["client_id"]

        actual_user_id = upsert_public_user(user_row)

        # 4. Role-Specific Linked Tables
        if acc["role"] == "closer":
            closer_check = api_call(f"{SUPABASE_URL}/rest/v1/client_closers?user_id=eq.{actual_user_id}&select=id")
            closer_row = {
                "client_id": acc["client_id"],
                "user_id": actual_user_id,
                "closer_code": acc["closer_code"],
                "full_name": f"{acc['first_name']} {acc['last_name']}",
                "closer_name": f"{acc['first_name']} {acc['last_name']}",
                "email": acc["primary_email"],
                "phone": acc["phone"],
                "is_active": True,
            }
            if closer_check and len(closer_check) > 0:
                cid = closer_check[0]["id"]
                api_call(f"{SUPABASE_URL}/rest/v1/client_closers?id=eq.{cid}", closer_row, method="PATCH")
            else:
                closer_row["id"] = acc["fixed_id"]
                api_call(f"{SUPABASE_URL}/rest/v1/client_closers", [closer_row], method="POST")
            print(f"  ✓ client_closers synced: {acc['closer_code']}", flush=True)

        elif acc["role"] == "delivery_agent":
            da_check = api_call(f"{SUPABASE_URL}/rest/v1/delivery_agents?user_id=eq.{actual_user_id}&select=id")
            agent_row = {
                "user_id": actual_user_id,
                "agent_code": acc["agent_code"],
                "agent_type": "independent_rider",
                "personnel_type": "pda",
                "coverage_states": ["Abuja (FCT)", "Lagos", "Ogun"],
                "current_cod_balance": 0.0,
                "max_cod_credit_limit": 500000.0,
                "distribution_center_id": acc["dc_id"],
                "is_active": True,
                "full_name": f"{acc['first_name']} {acc['last_name']}",
                "operating_state": "Abuja (FCT)",
                "operating_city": "Abuja",
                "vehicle_type": "motorcycle",
                "vehicle_plate_number": "ABJ-778-XY",
            }
            if da_check and len(da_check) > 0:
                da_id = da_check[0]["id"]
                api_call(f"{SUPABASE_URL}/rest/v1/delivery_agents?id=eq.{da_id}", agent_row, method="PATCH")
            else:
                agent_row["id"] = acc["fixed_id"]
                api_call(f"{SUPABASE_URL}/rest/v1/delivery_agents", [agent_row], method="POST")
            print(f"  ✓ delivery_agents synced: {acc['agent_code']}", flush=True)

def test_authentications():
    print("\n--- 4. LIVE VERIFICATION (ANON SIGN-IN TEST) ---", flush=True)
    test_emails = [
        ("DC Supervisor", "dc.supervisor@novaxpress.ng"),
        ("DC Supervisor (Legacy Alias)", "dc.supervisor@novaexpress.ng"),
        ("Novacare Merchant", "merchant@novacare.com"),
        ("Novacare Merchant (Alt)", "client@novaxpress.ng"),
        ("Telesales Closer", "closer@novacare.com"),
        ("Telesales Closer (Alt)", "closer.amaka@novacale.ng"),
        ("Field Rider (PDA)", "rider.emeka@novaxpress.com"),
        ("Field Rider (Alt)", "emeka.rider@novaxpress.ng"),
    ]

    all_passed = True
    for role, email in test_emails:
        login_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
        login_headers = {
            "apikey": ANON_KEY,
            "Content-Type": "application/json",
        }
        login_payload = {
            "email": email,
            "password": PASSWORD,
        }
        res = api_call(login_url, login_payload, method="POST", headers=login_headers)
        if res and res.get("access_token"):
            uid = res.get("user", {}).get("id")
            print(f"  ✅ [PASS] {role} ({email}) -> Authenticated successfully! (Auth ID: {uid})", flush=True)
        else:
            print(f"  ❌ [FAIL] {role} ({email}) -> Failed login!", flush=True)
            all_passed = False

    return all_passed

def main():
    print("================================================================", flush=True)
    print("🚀 NOVAXPRESS: DATABASE CLEANSE & TEST ACCOUNT PROVISIONING", flush=True)
    print("================================================================", flush=True)
    wipe_transactional_data()
    ensure_infrastructure()
    seed_test_accounts()
    success = test_authentications()
    print("\n================================================================", flush=True)
    if success:
        print("🎉 ALL TEST ACCOUNTS SUCCESSFULLY PROVISIONED & VERIFIED!", flush=True)
        print(f"   Password for all test accounts: {PASSWORD}", flush=True)
    else:
        print("⚠️ Some authentications failed. Check logs above.", flush=True)
    print("================================================================", flush=True)

if __name__ == "__main__":
    main()
