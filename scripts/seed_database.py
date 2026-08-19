import io
import urllib.request
import json
import sys
from datetime import datetime, timezone, timedelta

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
    "Prefer": "resolution=merge-duplicates,return=representation",
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

def seed_database():
    print("==================================================")
    print("🚀 NovaExpress Logistics: Seeding Supabase Database")
    print("==================================================")

    # 1. Primary Company
    nova_company_id = "11111111-1111-4111-8111-111111111111"
    novacare_client_id = "22222222-2222-4222-8222-222222222222"

    print("\n[1/7] Ensuring Companies exist...")
    companies = [
        {
            "id": nova_company_id,
            "name": "NovaExpress Logistics HQ",
            "type": "logistics",
            "company_type": "ecommerce",
            "is_active": True,
        },
        {
            "id": novacare_client_id,
            "name": "Novacare Health & Wellness Ltd",
            "type": "logistics",
            "company_type": "ecommerce",
            "is_active": True,
        },
    ]
    for c in companies:
        make_request("companies", [c], method="POST")
    print("✓ Companies seeded.")

    # 2. Warehouses / Distribution Centers (DCs)
    print("\n[2/7] Ensuring Distribution Centers (DCs) exist...")
    dc_lagos_id = "c1111111-1111-4111-8111-111111111111"
    dc_abuja_id = "c2222222-2222-4222-8222-222222222222"

    warehouses = [
        {
            "id": dc_lagos_id,
            "company_id": nova_company_id,
            "name": "Lagos Central Factory Hub",
            "type": "central",
            "location_state": "Lagos",
            "address": "14 Allen Avenue, Ikeja, Lagos State",
            "is_active": True,
        },
        {
            "id": dc_abuja_id,
            "company_id": nova_company_id,
            "name": "Abuja Regional Hub (NovaExpress)",
            "type": "agency_hub",
            "location_state": "Abuja (FCT)",
            "address": "Plot 402 Aminu Kano Crescent, Wuse 2, Abuja",
            "is_active": True,
        },
    ]
    for w in warehouses:
        make_request("warehouses", [w], method="POST")
    print("✓ Distribution Centers seeded.")

    # 3. Delivery Agent & User
    print("\n[3/7] Ensuring Delivery Agent & User Profile exist...")
    agent_id = "b1111111-1111-4111-8111-111111111111"
    agent_user_id = "70000000-0000-4000-8000-000000000007"

    users = [
        {
            "id": agent_user_id,
            "company_id": nova_company_id,
            "role": "rider",
            "first_name": "Joel",
            "last_name": "Odufu",
            "email": "joel.odufu@novexps.com",
            "phone": "+2348034429182",
            "is_active": True,
        }
    ]
    for u in users:
        make_request("users", [u], method="POST")

    delivery_agents = [
        {
            "id": agent_id,
            "user_id": agent_user_id,
            "agent_type": "agency_rider",
            "coverage_states": ["Lagos", "Ogun"],
            "current_cod_balance": 87000.0,
            "max_cod_credit_limit": 250000.0,
            "is_active": True,
        }
    ]
    for a in delivery_agents:
        make_request("delivery_agents", [a], method="POST")
    print("✓ Delivery Agent profile seeded.")

    # 4. Flagship Products
    print("\n[4/7] Ensuring Flagship Products exist...")
    prod_grazer_id = "90000000-0000-4000-8000-000000000001"
    prod_respira_id = "90000000-0000-4000-8000-000000000002"
    prod_alphaman_id = "90000000-0000-4000-8000-000000000003"

    products = [
        {
            "id": prod_grazer_id,
            "company_id": nova_company_id,
            "name": "Grazer Herbal Tea",
            "sku": "SKU-GRAZER-01",
            "description": "Premium organic herbal tea blend formulated for colon detox, digestive health, and metabolism.",
            "base_price": 15000.0,
            "category": "Herbal Detox",
            "is_active": True,
            "rep_commission_per_unit": 1000.0,
            "supervisor_commission_per_unit": 250.0,
            "stock_quantity": 250,
        },
        {
            "id": prod_respira_id,
            "company_id": nova_company_id,
            "name": "Respira Vitality Tonic",
            "sku": "SKU-RESPIRA-02",
            "description": "Natural respiratory wellness tonic formulated for lung function, clear breathing, and stamina.",
            "base_price": 25000.0,
            "category": "Respiratory Care",
            "is_active": True,
            "rep_commission_per_unit": 1500.0,
            "supervisor_commission_per_unit": 350.0,
            "stock_quantity": 180,
        },
        {
            "id": prod_alphaman_id,
            "company_id": nova_company_id,
            "name": "Alpha Man Organic Vitality",
            "sku": "SKU-ALPHAMAN-03",
            "description": "Daily organic vitality supplement for men's physical endurance, energy, and hormonal balance.",
            "base_price": 22000.0,
            "category": "Men's Wellness",
            "is_active": True,
            "rep_commission_per_unit": 1200.0,
            "supervisor_commission_per_unit": 300.0,
            "stock_quantity": 120,
        },
    ]
    for p in products:
        make_request("products", [p], method="POST")
    print("✓ Flagship Products seeded.")

    # 5. Warehouse Inventory
    print("\n[5/7] Ensuring Warehouse & Vehicle Stock levels exist...")
    warehouse_inventory = [
        {
            "id": "e1111111-1111-4111-a111-111111111111",
            "warehouse_id": dc_lagos_id,
            "product_id": prod_grazer_id,
            "quantity_available": 120,
            "quantity_allocated": 24,
            "quantity_in_transit": 12,
            "quantity_damaged": 0,
        },
        {
            "id": "e2222222-2222-4222-a222-222222222222",
            "warehouse_id": dc_lagos_id,
            "product_id": prod_respira_id,
            "quantity_available": 85,
            "quantity_allocated": 18,
            "quantity_in_transit": 6,
            "quantity_damaged": 0,
        },
        {
            "id": "e3333333-3333-4333-a333-333333333333",
            "warehouse_id": dc_lagos_id,
            "product_id": prod_alphaman_id,
            "quantity_available": 60,
            "quantity_allocated": 10,
            "quantity_in_transit": 4,
            "quantity_damaged": 0,
        },
    ]
    for inv in warehouse_inventory:
        make_request("warehouse_inventory", [inv], method="POST")
    print("✓ Warehouse Inventory seeded.")

    # 6. Realistic Manifest Orders (All 4 Quadrants & All Lifecycle States)
    print("\n[6/7] Seeding Manifest Orders with all operational scenarios...")
    now = datetime.now(timezone.utc)

    manifest_orders = [
        # Order 1: Distributed Inventory + POD (In Transit)
        {
            "id": "e0000000-0000-4000-8000-000000000001",
            "order_number": "NX-849201",
            "company_id": nova_company_id,
            "product_id": prod_respira_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Chinedu Okafor",
            "customer_phone": "08031234567",
            "customer_alt_phone": "08099887766",
            "delivery_state": "Lagos",
            "delivery_city": "Lekki Phase 1",
            "delivery_address": "12 Admiralty Way, Lekki Phase 1, Lagos State",
            "status": "in_transit",
            "quantity": 2,
            "base_price": 50000.0,
            "upsell_amount": 2000.0,
            "downsell_discount": 0.0,
            "total_amount": 52000.0,
            "payment_type": "pay_on_delivery",
            "payment_status": "pending",
            "delivery_notes": "Call 10 minutes before arrival. Gate security requires tracking ID.",
            "created_at": (now - timedelta(hours=2)).isoformat(),
        },
        # Order 2: Distributed Inventory + POD (Ready at DC / Accepted)
        {
            "id": "e0000000-0000-4000-8000-000000000002",
            "order_number": "NX-849202",
            "company_id": nova_company_id,
            "product_id": prod_grazer_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Amina Bello",
            "customer_phone": "08129990011",
            "delivery_state": "Lagos",
            "delivery_city": "Ikeja",
            "delivery_address": "14 Allen Avenue, Opposite KFC, Ikeja, Lagos",
            "status": "accepted",
            "quantity": 1,
            "base_price": 15000.0,
            "upsell_amount": 0.0,
            "downsell_discount": 0.0,
            "total_amount": 15000.0,
            "payment_type": "pay_on_delivery",
            "payment_status": "pending",
            "delivery_notes": "Customer requested morning delivery before 12:00 PM.",
            "created_at": (now - timedelta(hours=3)).isoformat(),
        },
        # Order 3: Client Package + Prepaid (Delivered & Verified)
        {
            "id": "e0000000-0000-4000-8000-000000000003",
            "order_number": "NX-849203",
            "company_id": nova_company_id,
            "product_id": prod_alphaman_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Emeka Nwosu",
            "customer_phone": "07065554433",
            "delivery_state": "Lagos",
            "delivery_city": "Victoria Island",
            "delivery_address": "Plot 24 Adeola Odeku Street, Victoria Island, Lagos",
            "status": "delivered",
            "quantity": 2,
            "base_price": 44000.0,
            "upsell_amount": 0.0,
            "downsell_discount": 0.0,
            "total_amount": 44000.0,
            "payment_type": "prepaid",
            "payment_status": "collected",
            "delivery_notes": "Client Package from Novacare. Delivered to office receptionist.",
            "created_at": (now - timedelta(hours=6)).isoformat(),
        },
        # Order 4: Distributed Inventory + POD (In Transit)
        {
            "id": "e0000000-0000-4000-8000-000000000004",
            "order_number": "NX-849204",
            "company_id": nova_company_id,
            "product_id": prod_grazer_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Kelechi Adewale",
            "customer_phone": "08051112233",
            "delivery_state": "Lagos",
            "delivery_city": "Surulere",
            "delivery_address": "45 Bode Thomas Street, Surulere, Lagos",
            "status": "in_transit",
            "quantity": 1,
            "base_price": 15000.0,
            "upsell_amount": 3500.0,
            "downsell_discount": 0.0,
            "total_amount": 18500.0,
            "payment_type": "pay_on_delivery",
            "payment_status": "pending",
            "delivery_notes": "Special promo package (1 Grazer + 1 Free Sample).",
            "created_at": (now - timedelta(hours=4)).isoformat(),
        },
        # Order 5: Client Package + POD (In Transit)
        {
            "id": "e0000000-0000-4000-8000-000000000005",
            "order_number": "NX-849205",
            "company_id": nova_company_id,
            "product_id": prod_respira_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Blessing Okon",
            "customer_phone": "08023334455",
            "delivery_state": "Lagos",
            "delivery_city": "Yaba",
            "delivery_address": "18 Commercial Avenue, Sabo, Yaba, Lagos",
            "status": "in_transit",
            "quantity": 3,
            "base_price": 45000.0,
            "upsell_amount": 0.0,
            "downsell_discount": 0.0,
            "total_amount": 45000.0,
            "payment_type": "pay_on_delivery",
            "payment_status": "pending",
            "delivery_notes": "Client Package (Novacare Custody PKG-9081). Confirm sealed bag.",
            "created_at": (now - timedelta(hours=5)).isoformat(),
        },
        # Order 6: Distributed Inventory + POD (Failed / Callback)
        {
            "id": "e0000000-0000-4000-8000-000000000006",
            "order_number": "NX-849206",
            "company_id": nova_company_id,
            "product_id": prod_alphaman_id,
            "warehouse_id": dc_lagos_id,
            "delivery_agent_id": agent_id,
            "customer_name": "Tunde Bakare",
            "customer_phone": "08187778899",
            "delivery_state": "Lagos",
            "delivery_city": "Magodo Phase 2",
            "delivery_address": "10 Emmanuel Keshi Street, Magodo Phase 2, Lagos",
            "status": "call_back",
            "quantity": 1,
            "base_price": 22000.0,
            "upsell_amount": 0.0,
            "downsell_discount": 0.0,
            "total_amount": 22000.0,
            "payment_type": "pay_on_delivery",
            "payment_status": "pending",
            "delivery_notes": "Customer in meeting. Requested callback at 5:00 PM.",
            "created_at": (now - timedelta(hours=7)).isoformat(),
        },
    ]

    for order in manifest_orders:
        make_request("orders", [order], method="POST")

    print(f"✓ {len(manifest_orders)} Operational Manifest Orders seeded.")

    # 7. Cash Remittances
    print("\n[7/7] Seeding Cash Remittance transactions & history...")
    remittances = [
        {
            "id": "f1111111-1111-4111-9111-111111111111",
            "company_id": nova_company_id,
            "delivery_agent_id": agent_id,
            "amount": 75000.0,
            "deposit_receipt_url": "https://novexps.storage/receipts/rec-88201.jpg",
            "status": "verified",
            "verified_by_finance_user_id": agent_user_id,
            "notes": "Bank Transfer to NovaExpress GTBank (Ref: TRF/NVA/889201). Verified by Lagos DC Finance.",
            "created_at": (now - timedelta(days=2, hours=3)).isoformat(),
            "verified_at": (now - timedelta(days=2, hours=1)).isoformat(),
        },
        {
            "id": "f2222222-2222-4222-9222-222222222222",
            "company_id": nova_company_id,
            "delivery_agent_id": agent_id,
            "amount": 50000.0,
            "deposit_receipt_url": "https://novexps.storage/receipts/rec-88202.jpg",
            "status": "verified",
            "verified_by_finance_user_id": agent_user_id,
            "notes": "Direct Cash Handover at Ikeja DC to DC Supervisor Adekunle.",
            "created_at": (now - timedelta(days=1, hours=4)).isoformat(),
            "verified_at": (now - timedelta(days=1, hours=2)).isoformat(),
        },
        {
            "id": "f3333333-3333-4333-9333-333333333333",
            "company_id": nova_company_id,
            "delivery_agent_id": agent_id,
            "amount": 42000.0,
            "deposit_receipt_url": "https://novexps.storage/receipts/rec-88203.jpg",
            "status": "pending",
            "verified_by_finance_user_id": None,
            "notes": "POS Terminal Settlement Receipt #POS-77821. Pending DC Finance confirmation.",
            "created_at": (now - timedelta(hours=3)).isoformat(),
            "verified_at": None,
        },
    ]
    for rem in remittances:
        make_request("cash_remittances", [rem], method="POST")
    print(f"✓ {len(remittances)} Cash Remittance records seeded.")

    print("\n==================================================")
    print("✅ DATABASE SEEDING COMPLETED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    seed_database()
