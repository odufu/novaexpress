import urllib.request
import json
import ssl
import sys
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding='utf-8')
ctx = ssl.create_default_context()

now_iso = datetime.now(timezone.utc).isoformat()

projects = [
    {
        "name": "Production (oygtaeriljuelhshfvkv)",
        "url": "https://oygtaeriljuelhshfvkv.supabase.co",
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM",
        "client_id": "00000000-0000-4000-8000-791731264594",
        "client_name": "NOVACARE LIMITED"
    },
    {
        "name": "Testing (hwyqqjilcifxajruusoa)",
        "url": "https://hwyqqjilcifxajruusoa.supabase.co",
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI",
        "client_id": "00000000-0000-4000-8000-791731264594",
        "client_name": "NOVACARE LIMITED"
    }
]

RIDER_AGENT_ID = "842bc86e-ada4-4ddb-9e96-2db063c84ba5"
RIDER_USER_ID = "4086b7c3-b273-4efa-8587-a1e78faee3c0"
RIDER_NAME = "Oladele Omowaye"
RIDER_CODE = "RDR-501"

DC_ID = "22222222-2222-4222-8222-222222222222"
COMPANY_ID = "11111111-1111-4111-8111-111111111111"

PROD_GRAZER = {
    "id": "e05b6c38-cc3e-4553-b556-52ebbb50c18b",
    "name": "Grazer Herbal Detox Tea",
    "sku": "SKU-PRD-8309",
    "price": 23500.0
}

PROD_URA = {
    "id": "e7f8f4ec-66fe-4830-83eb-60b4e4d84103",
    "name": "URA Clear",
    "sku": "SKU-PRD-6731",
    "price": 24500.0
}

seed_orders = [
    {
        "id": "71010000-0000-4000-8000-000000007101",
        "order_number": "NOV-2026-7101",
        "customer_name": "Alhaji Ibrahim Usman",
        "customer_phone": "08034567890",
        "customer_phone_normalized": "08034567890",
        "delivery_state": "Abuja (FCT)",
        "delivery_city": "Garki Area 11",
        "delivery_address": "Plot 422, Ahmadu Bello Way, Area 11, Garki, Abuja",
        "landmark": "Beside Federal Ministry of Finance",
        "product": PROD_GRAZER,
        "quantity": 2,
        "base_price": 47000.0,
        "total_amount": 47000.0,
        "status": "assigned",
        "assignment_status": "assigned",
        "payment_status": "pending",
        "delivery_otp": "5812",
        "delivery_notes": "Gate PIN: 5812. Customer requested call 15 mins before arrival. Cash on delivery.",
        "delivered_at": None
    },
    {
        "id": "71020000-0000-4000-8000-000000007102",
        "order_number": "NOV-2026-7102",
        "customer_name": "Dr. Chioma Nwachukwu",
        "customer_phone": "08023456789",
        "customer_phone_normalized": "08023456789",
        "delivery_state": "Abuja (FCT)",
        "delivery_city": "Gwarinpa Estate",
        "delivery_address": "House 14, 4th Avenue, Gwarinpa Estate, Abuja",
        "landmark": "Opposite Charly Boy Bus Stop",
        "product": PROD_URA,
        "quantity": 1,
        "base_price": 24500.0,
        "total_amount": 24500.0,
        "status": "in_transit",
        "assignment_status": "in_transit",
        "payment_status": "pending",
        "delivery_otp": "9341",
        "delivery_notes": "Gate PIN: 9341. Call security at main gate if barrier is down. Exact change ready.",
        "delivered_at": None
    },
    {
        "id": "71030000-0000-4000-8000-000000007103",
        "order_number": "NOV-2026-7103",
        "customer_name": "Mr. Tunde Bakare",
        "customer_phone": "08189876543",
        "customer_phone_normalized": "08189876543",
        "delivery_state": "Abuja (FCT)",
        "delivery_city": "Utako District",
        "delivery_address": "Block C, Flat 4, CBN Quarters, Utako, Abuja",
        "landmark": "Near Utako Modern Market",
        "product": PROD_GRAZER,
        "quantity": 1,
        "base_price": 23500.0,
        "total_amount": 23500.0,
        "status": "in_transit",
        "assignment_status": "in_transit",
        "payment_status": "pending",
        "delivery_otp": "3178",
        "delivery_notes": "Gate PIN: 3178. Office delivery, ask for receptionist on 2nd floor.",
        "delivered_at": None
    },
    {
        "id": "71040000-0000-4000-8000-000000007104",
        "order_number": "NOV-2026-7104",
        "customer_name": "Barrister Kenneth Opara",
        "customer_phone": "09051234567",
        "customer_phone_normalized": "09051234567",
        "delivery_state": "Abuja (FCT)",
        "delivery_city": "Maitama",
        "delivery_address": "No 8, Danube Street, Maitama, Abuja",
        "landmark": "Near Maitama General Hospital",
        "product": PROD_GRAZER,
        "quantity": 1,
        "base_price": 23500.0,
        "total_amount": 23500.0,
        "status": "delivered",
        "assignment_status": "delivered",
        "payment_status": "collected",
        "remittance_status": "unremitted",
        "delivery_otp": "7264",
        "delivery_notes": "Delivered to security personnel per customer instruction. POD signed.",
        "delivered_at": now_iso
    }
]

for p in projects:
    print(f"\n==========================================")
    print(f"SEEDING INTO: {p['name']}")
    print(f"==========================================")
    headers = {
        "apikey": p["key"],
        "Authorization": f"Bearer {p['key']}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    client_id = p["client_id"]
    client_name = p["client_name"]

    for item in seed_orders:
        payload = {
            "id": item["id"],
            "order_number": item["order_number"],
            "company_id": COMPANY_ID,
            "client_id": client_id,
            "client_name": client_name,
            "client_company": client_name,
            "distribution_center_id": DC_ID,
            "delivery_agent_id": RIDER_AGENT_ID,
            "assigned_agent_id": RIDER_AGENT_ID,
            "product_id": item["product"]["id"],
            "product_name": item["product"]["name"],
            "product_sku": item["product"]["sku"],
            "customer_name": item["customer_name"],
            "customer_phone": item["customer_phone"],
            "customer_phone_normalized": item["customer_phone_normalized"],
            "delivery_state": item["delivery_state"],
            "delivery_city": item["delivery_city"],
            "delivery_address": item["delivery_address"],
            "landmark": item["landmark"],
            "quantity": item["quantity"],
            "paid_quantity": item["quantity"],
            "free_quantity": 0,
            "base_price": item["base_price"],
            "upsell_amount": 0.0,
            "total_amount": item["total_amount"],
            "payment_type": "pay_on_delivery",
            "payment_method": "cash",
            "payment_status": item["payment_status"],
            "status": item["status"],
            "assignment_status": item["assignment_status"],
            "fulfillment_type": "distributed_inventory",
            "client_delivery_fee": 5000.0,
            "agent_entitlement": 2500.0,
            "delivery_notes": item["delivery_notes"],
            "delivery_otp": item["delivery_otp"],
            "is_pod": True,
            "created_at": now_iso,
            "updated_at": now_iso
        }
        if item.get("delivered_at"):
            payload["delivered_at"] = item["delivered_at"]
        if item.get("remittance_status"):
            payload["remittance_status"] = item["remittance_status"]

        # Upsert order using merge-duplicates
        try:
            req = urllib.request.Request(
                f"{p['url']}/rest/v1/orders",
                data=json.dumps(payload).encode("utf-8"),
                headers=headers,
                method="POST"
            )
            with urllib.request.urlopen(req, context=ctx) as resp:
                print(f"  [SUCCESS] Order: {item['order_number']} [{item['status']}] - {item['customer_name']} (N{item['total_amount']:,.0f})")
        except urllib.error.HTTPError as e:
            err_msg = e.read().decode()
            print(f"  [ERROR] {item['order_number']}: {e.code} - {err_msg}")
        except Exception as e:
            print(f"  [EXCEPTION] {item['order_number']}: {e}")

    # Seed Notifications for Rider Oladele
    print("  --- Seeding In-App Notifications for Rider Oladele ---")
    notifications = [
        {
            "id": "71010000-0000-4000-8000-000000000001",
            "company_id": COMPANY_ID,
            "delivery_agent_id": RIDER_AGENT_ID,
            "title": "New Order Assigned",
            "message": "Order #NOV-2026-7101 (Alhaji Ibrahim Usman - Area 11 Garki) has been assigned to you from Central Command DC.",
            "category": "delivery",
            "action_route": "/orders",
            "is_read": False,
            "created_at": now_iso
        },
        {
            "id": "71010000-0000-4000-8000-000000000002",
            "company_id": COMPANY_ID,
            "delivery_agent_id": RIDER_AGENT_ID,
            "title": "Novacare Run Ready",
            "message": "You have 3 active delivery orders from Novacare Limited in your run today.",
            "category": "delivery",
            "action_route": "/orders",
            "is_read": False,
            "created_at": now_iso
        }
    ]
    for n in notifications:
        try:
            req = urllib.request.Request(
                f"{p['url']}/rest/v1/notifications",
                data=json.dumps(n).encode("utf-8"),
                headers=headers,
                method="POST"
            )
            with urllib.request.urlopen(req, context=ctx) as resp:
                print(f"  [NOTIFICATION] {n['title']}")
        except Exception as e:
            print(f"  Notification notice: {e}")

print("\n--- Seeding Process Complete ---")
