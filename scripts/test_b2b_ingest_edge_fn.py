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
FN_URL = f"{URL}/functions/v1/ingest-client-package"
BEARER_TOKEN = "nx_live_comfortcare_sec_994821049"

headers = {
    "Authorization": f"Bearer {BEARER_TOKEN}",
    "X-Client-Id": "comfortcare-abuja-01",
    "Content-Type": "application/json"
}

payload = {
    "client_id": "comfortcare-abuja-01",
    "order_reference": "CC-TEST-001",
    "fulfillment_type": "client_package",
    "pickup_stops": [
        {
            "stop_number": 1,
            "location_id": "ph-medplus-lifecamp",
            "location_name": "MedPlus Pharmacy (Life Camp Branch)",
            "pickup_address": "Suite 4, Life Camp Commercial Complex, Life Camp, Abuja",
            "city": "Abuja",
            "state": "Federal Capital Territory",
            "lga": "Abuja Municipal (AMAC)",
            "landmark": "Near Life Camp Roundabout",
            "contact_person": "Pharm. Kenneth Okafor",
            "contact_phone": "+2348031112233",
            "contact_whatsapp": "+2348031112233",
            "items_to_collect": [
                {
                    "item_name": "Coartem 80/480mg",
                    "quantity": 2,
                    "requires_cold_chain": False
                }
            ],
            "sealed_bag_ref": "BAG-CC-TEST001-A"
        },
        {
            "stop_number": 2,
            "location_id": "ph-hmedix-wuse",
            "location_name": "H-Medix Pharmacy (Wuse 2 Branch)",
            "pickup_address": "Plot 42, Aminu Kano Crescent, Wuse 2, Abuja",
            "city": "Abuja",
            "state": "Federal Capital Territory",
            "lga": "Abuja Municipal (AMAC)",
            "landmark": "Opposite Banex Plaza Corridor",
            "contact_person": "Pharm. Fatima Bello",
            "contact_phone": "+2348024445566",
            "contact_whatsapp": "+2348024445566",
            "items_to_collect": [
                {
                    "item_name": "Augmentin 625mg",
                    "quantity": 1,
                    "requires_cold_chain": False
                }
            ],
            "sealed_bag_ref": "BAG-CC-TEST001-B"
        }
    ],
    "receiver": {
        "name": "Dr. Farouk Al-Mansur",
        "phone_number": "+2348032651505",
        "whatsapp_number": "+2348032651505",
        "address": "Plot 1044, Adetokunbo Ademola Crescent, Wuse 2, Abuja",
        "city": "Abuja",
        "state": "Federal Capital Territory",
        "lga": "Abuja Municipal (AMAC)",
        "landmark": "Near Banex / Wuse 2 Corridor"
    },
    "payment_receipt": {
        "gateway": "Paystack",
        "receipt_number": "CC-PAYSTACK-99014",
        "transaction_reference": "CC-TXN-8492048",
        "amount_paid": 19200.0,
        "currency": "NGN",
        "payment_status": "prepaid"
    }
}

print("=" * 60)
print(f"TESTING LIVE EDGE FUNCTION: {FN_URL}")
print("=" * 60)

req = urllib.request.Request(FN_URL, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"✅ Status {resp.status} Created!")
        print("Response JSON:")
        print(json.dumps(res, indent=2))
except urllib.error.HTTPError as e:
    print(f"❌ HTTP {e.code} Error: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"❌ Error: {e}")
