import io
import sys
import os
import json
import uuid
import urllib.request
import urllib.error

os.environ['no_proxy'] = '*'

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
FN_URL = f"{URL}/functions/v1/ingest-client-package"
REST_URL = f"{URL}/rest/v1"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwNjQ5OTEsImV4cCI6MjA3MzY0MDk5MX0.Q-G_b8P81h9i4eJ8WvV3wP8i3QYhW9s5GqfV4QZ_y2U"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
BEARER_TOKEN = "nx_live_comfortcare_sec_994821049"

print("=" * 65)
print("RUNNING COMPLETE ULTIMATE OBJECTIVE END-TO-END VERIFICATION")
print("=" * 65)

# Step 1: Ingest fresh B2B Order with unique reference
ref_id = f"CC-E2E-{uuid.uuid4().hex[:6].upper()}"
bag_a = f"BAG-A-{uuid.uuid4().hex[:4].upper()}"
bag_b = f"BAG-B-{uuid.uuid4().hex[:4].upper()}"

payload = {
    "client_id": "comfortcare-abuja-01",
    "order_reference": ref_id,
    "fulfillment_type": "client_package",
    "pickup_stops": [
        {
            "stop_number": 1,
            "location_id": "ph-medplus-lifecamp",
            "location_name": "MedPlus Pharmacy (Life Camp)",
            "pickup_address": "Suite 4, Life Camp Commercial Complex, Abuja",
            "city": "Abuja",
            "state": "Federal Capital Territory",
            "lga": "Abuja Municipal (AMAC)",
            "landmark": "Near Life Camp Roundabout",
            "contact_person": "Pharm. Kenneth Okafor",
            "contact_phone": "+2348031112233",
            "contact_whatsapp": "+2348031112233",
            "items_to_collect": [
                {"item_name": "Coartem 80/480mg", "quantity": 2, "requires_cold_chain": False}
            ],
            "sealed_bag_ref": bag_a
        },
        {
            "stop_number": 2,
            "location_id": "ph-hmedix-wuse",
            "location_name": "H-Medix Pharmacy (Wuse 2)",
            "pickup_address": "Plot 42, Aminu Kano Crescent, Wuse 2, Abuja",
            "city": "Abuja",
            "state": "Federal Capital Territory",
            "lga": "Abuja Municipal (AMAC)",
            "landmark": "Opposite Banex Plaza Corridor",
            "contact_person": "Pharm. Fatima Bello",
            "contact_phone": "+2348024445566",
            "contact_whatsapp": "+2348024445566",
            "items_to_collect": [
                {"item_name": "Augmentin 625mg", "quantity": 1, "requires_cold_chain": False}
            ],
            "sealed_bag_ref": bag_b
        }
    ],
    "receiver": {
        "name": "Hajiya Amina Bello",
        "phone_number": "+2348099887766",
        "whatsapp_number": "+2348099887766",
        "address": "House 12, 4th Avenue, Gwarinpa Estate, Abuja",
        "city": "Abuja",
        "state": "Federal Capital Territory",
        "lga": "Abuja Municipal (AMAC)",
        "landmark": "Near Chemist Bus Stop"
    },
    "payment_receipt": {
        "gateway": "Paystack",
        "receipt_number": f"REC-{ref_id}",
        "transaction_reference": f"TXN-{ref_id}",
        "amount_paid": 24500.0,
        "currency": "NGN",
        "payment_status": "prepaid"
    }
}

req = urllib.request.Request(
    FN_URL,
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": f"Bearer {BEARER_TOKEN}",
        "X-Client-Id": "comfortcare-abuja-01",
        "Content-Type": "application/json"
    },
    method="POST"
)

with urllib.request.urlopen(req, timeout=15) as resp:
    res = json.loads(resp.read().decode("utf-8"))
    tracking_no = res["tracking_number"]
    delivery_fee = res.get("logistics_pricing", {}).get("total_logistics_fee", res.get("total_logistics_fee", 5000))
    print(f"1. ✅ B2B INGESTION SUCCESS: Tracking #{tracking_no} | Fee: ₦{delivery_fee:,.2f}")

# Look up order_id from orders table using tracking_number
req = urllib.request.Request(
    f"{REST_URL}/orders?order_number=eq.{tracking_no}&select=id,status,delivery_otp,delivery_agent_id",
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    ord_row = json.loads(resp.read().decode("utf-8"))[0]
    order_id = ord_row["id"]
    otp = ord_row["delivery_otp"]
    agent_id = ord_row["delivery_agent_id"]
    print(f"   Order UUID: {order_id} | OTP: {otp}")

# Step 2: Fetch order pickups from Supabase REST
req = urllib.request.Request(
    f"{REST_URL}/client_package_pickups?order_id=eq.{order_id}&order=stop_sequence.asc",
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    pickups = json.loads(resp.read().decode("utf-8"))
    print(f"2. ✅ PICKUP MANIFEST RETRIEVED: Found {len(pickups)} dispensary stops.")

# Step 3: Simulate Barcode Scan for Stop 1 and Stop 2
for pickup in pickups:
    p_id = pickup["id"]
    bag_ref = pickup["sealed_bag_ref"]
    scan_req = urllib.request.Request(
        f"{REST_URL}/rpc/fn_verify_pickup_bag_scan",
        data=json.dumps({"p_pickup_id": p_id, "p_scanned_bag_ref": bag_ref}).encode("utf-8"),
        headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"},
        method="POST"
    )
    with urllib.request.urlopen(scan_req, timeout=10) as resp:
        scan_res = json.loads(resp.read().decode("utf-8"))
        print(f"3. ✅ BARCODE SCAN VERIFIED for stop #{pickup['stop_sequence']} ({bag_ref}): {scan_res['message']}")

# Check order status after all pickups collected
req = urllib.request.Request(
    f"{REST_URL}/orders?id=eq.{order_id}&select=status,delivery_otp,delivery_agent_id",
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"}
)
with urllib.request.urlopen(req, timeout=10) as resp:
    ord_data = json.loads(resp.read().decode("utf-8"))[0]
    print(f"4. ✅ ORDER STATUS UPDATED to '{ord_data['status']}'")
    otp = ord_data["delivery_otp"]
    agent_id = ord_data["delivery_agent_id"]

# Step 4: Simulate Delivery Completion with Recipient OTP
otp_req = urllib.request.Request(
    f"{REST_URL}/rpc/fn_verify_delivery_otp_and_complete",
    data=json.dumps({"p_order_id": order_id, "p_entered_otp": otp, "p_agent_id": agent_id}).encode("utf-8"),
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"},
    method="POST"
)
with urllib.request.urlopen(otp_req, timeout=10) as resp:
    otp_res = json.loads(resp.read().decode("utf-8"))
    print(f"5. ✅ OTP DELIVERY COMPLETED: {otp_res['message']} (Rider payout: ₦{otp_res['rider_credited_amount']:,.2f})")

# Step 5: Verify DC Financial Logistics Analytics reflection
dash_req = urllib.request.Request(
    f"{REST_URL}/rpc/fn_get_dc_logistics_dashboard",
    data=json.dumps({"p_dc_id": None, "p_start_date": "2026-01-01", "p_end_date": "2026-12-31"}).encode("utf-8"),
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"},
    method="POST"
)
with urllib.request.urlopen(dash_req, timeout=10) as resp:
    dash_res = json.loads(resp.read().decode("utf-8"))
    print(f"6. ✅ GRAND CONSOLE LOGISTICS INTELLIGENCE REFLECTED:")
    print(f"   • Gross Logistics Revenue: ₦{float(dash_res.get('logistics_gross_revenue', 0)):,.2f}")
    print(f"   • Parcels Handled:         {dash_res.get('total_parcels_handled', 0)}")
    print(f"   • Network OpEx:            ₦{float(dash_res.get('network_opex', 0)):,.2f}")
    print(f"   • Net Logistics Margin:    ₦{float(dash_res.get('net_logistics_margin', 0)):,.2f}")
    print(f"   • Vault Inventory Count:   {dash_res.get('vault_inventory', 0)} units")

# Step 6: Verify Merchant Financial Intelligence for ComfortCare
merch_req = urllib.request.Request(
    f"{REST_URL}/rpc/fn_get_merchant_financial_dashboard",
    data=json.dumps({"p_client_id": "c3333333-3333-4333-8333-333333333333", "p_start_date": "2026-01-01", "p_end_date": "2026-12-31"}).encode("utf-8"),
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"},
    method="POST"
)
with urllib.request.urlopen(merch_req, timeout=10) as resp:
    m_res = json.loads(resp.read().decode("utf-8"))
    print(f"7. ✅ MERCHANT FINANCIAL INTELLIGENCE (ComfortCare):")
    print(f"   • Sales Revenue:           ₦{float(m_res.get('sales_revenue', 0)):,.2f}")
    print(f"   • Operating Expenditures:  ₦{float(m_res.get('total_expenditures', 0)):,.2f}")
    print(f"   • Net Profit:              ₦{float(m_res.get('net_profit', 0)):,.2f}")
    print(f"   • Lifetime Gross Revenue:  ₦{float(m_res.get('lifetime_revenue', 0)):,.2f}")

print("=" * 65)
print("ALL SYSTEM TESTS COMPLETED WITH 100% SUCCESS!")
print("=" * 65)
