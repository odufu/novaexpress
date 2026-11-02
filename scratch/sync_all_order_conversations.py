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
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
    },
    {
        "name": "Testing (hwyqqjilcifxajruusoa)",
        "url": "https://hwyqqjilcifxajruusoa.supabase.co",
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
    }
]

for p in projects:
    print(f"\n==========================================")
    print(f"SYNCING CONVERSATIONS FOR: {p['name']}")
    print(f"==========================================")
    headers = {
        "apikey": p["key"],
        "Authorization": f"Bearer {p['key']}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    # 1. Fetch DCs map
    dc_map = {}
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/distribution_centers?select=id,name", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            dcs = json.loads(resp.read().decode())
            for d in dcs:
                dc_map[d['id']] = d['name']
    except Exception as e:
        print("Error fetching DCs:", e)

    # 2. Fetch Agents map
    agent_map = {}
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/delivery_agents?select=id,agent_code,bank_account_name,users(first_name,last_name)", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            agents = json.loads(resp.read().decode())
            for a in agents:
                u = a.get('users')
                name = None
                if isinstance(u, dict):
                    name = f"{u.get('first_name', '')} {u.get('last_name', '')}".strip()
                elif isinstance(u, list) and len(u) > 0:
                    name = f"{u[0].get('first_name', '')} {u[0].get('last_name', '')}".strip()
                name = name or a.get('bank_account_name') or a.get('agent_code')
                agent_map[a['id']] = name
    except Exception as e:
        print("Error fetching agents:", e)

    # 3. Fetch all orders
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/orders?select=id,order_number,customer_name,customer_phone,client_id,client_name,distribution_center_id,delivery_agent_id,product_name,package_deal_name,total_amount,status,closer_id,closer_name,marketer_id,form_id", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            orders = json.loads(resp.read().decode())
            print(f"Found {len(orders)} orders in orders table.")
    except Exception as e:
        print("Error fetching orders:", e)
        continue

    # 4. Fetch existing conversations
    existing_conv_order_ids = set()
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/order_conversations?select=id,order_id", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            convs = json.loads(resp.read().decode())
            for c in convs:
                if c.get('order_id'):
                    existing_conv_order_ids.add(c['order_id'])
            print(f"Existing conversations: {len(existing_conv_order_ids)}")
    except Exception as e:
        print("Error fetching existing conversations:", e)

    # 5. Insert missing conversations or update DC / Rider info
    synced = 0
    for o in orders:
        order_id = o['id']
        dc_id = o.get('distribution_center_id') or '22222222-2222-4222-8222-222222222222'
        dc_name = dc_map.get(dc_id, 'Central Command Distribution Center')
        rider_id = o.get('delivery_agent_id')
        rider_name = agent_map.get(rider_id) if rider_id else None

        conv_payload = {
            "order_id": order_id,
            "order_number": o.get('order_number') or f"ORD-{order_id[:8]}",
            "customer_name": o.get('customer_name') or 'Customer',
            "customer_phone": o.get('customer_phone'),
            "client_id": o.get('client_id') or '00000000-0000-4000-8000-791731264594',
            "client_name": o.get('client_name') or 'NOVACARE LIMITED',
            "distribution_center_id": dc_id,
            "distribution_center_name": dc_name,
            "delivery_agent_id": rider_id,
            "delivery_agent_name": rider_name,
            "closer_id": o.get('closer_id'),
            "closer_name": o.get('closer_name'),
            "marketer_id": o.get('marketer_id'),
            "form_id": o.get('form_id'),
            "order_status": o.get('status') or 'pending',
            "current_product_name": o.get('product_name'),
            "current_package_name": o.get('package_deal_name'),
            "current_total_amount": o.get('total_amount') or 0.0,
            "last_message_text": "Order chat pipeline active. DC Ops, courier & merchant connected.",
            "last_message_sender_name": "System",
            "last_message_at": now_iso,
            "created_at": now_iso,
            "updated_at": now_iso
        }

        try:
            req = urllib.request.Request(
                f"{p['url']}/rest/v1/order_conversations",
                data=json.dumps(conv_payload).encode('utf-8'),
                headers=headers,
                method="POST"
            )
            with urllib.request.urlopen(req, context=ctx) as resp:
                synced += 1
        except Exception as e:
            # Maybe already exists or constraint
            pass

    print(f"Synced {synced} order conversations for {p['name']}.")

