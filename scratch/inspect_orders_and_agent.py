import urllib.request
import json
import ssl

ctx = ssl.create_default_context()

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
    print(f"DATABASE: {p['name']}")
    print(f"==========================================")
    headers = {
        "apikey": p["key"],
        "Authorization": f"Bearer {p['key']}",
        "Content-Type": "application/json"
    }

    # 1. Delivery agent record
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/delivery_agents?id=eq.842bc86e-ada4-4ddb-9e96-2db063c84ba5&select=*", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode())
            print("Delivery agent for Oladele:", json.dumps(data, indent=2))
    except Exception as e:
        print("Error fetching delivery agent:", e)

    # 2. Existing orders sample (to inspect exact schema)
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/orders?select=*&limit=1", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode())
            if data:
                print(f"Sample order columns ({len(data[0].keys())}):")
                print(list(data[0].keys()))
                print("Sample order data:", json.dumps(data[0], indent=2))
            else:
                print("No orders found in table.")
    except Exception as e:
        print("Error fetching orders:", e)

    # 3. Existing orders for Oladele
    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/orders?delivery_agent_id=eq.842bc86e-ada4-4ddb-9e96-2db063c84ba5&select=id,order_number,status,customer_name,delivery_address,amount", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode())
            print(f"Orders currently assigned to Oladele ({len(data)}):", data)
    except Exception as e:
        print("Error fetching Oladele orders:", e)

