import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')
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

    try:
        req = urllib.request.Request(f"{p['url']}/rest/v1/order_conversations?select=id,order_id,order_number,customer_name,distribution_center_id,distribution_center_name,delivery_agent_id,delivery_agent_name,client_name&limit=10", headers=headers)
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode())
            print(f"Order conversations count in sample: {len(data)}")
            for c in data:
                print(f"  -> {c.get('order_number')} | DC: {c.get('distribution_center_name')} ({c.get('distribution_center_id')}) | Rider: {c.get('delivery_agent_name')} ({c.get('delivery_agent_id')}) | Client: {c.get('client_name')}")
    except Exception as e:
        print("Error reading order_conversations:", e)

