import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')
ctx = ssl.create_default_context()

url = "https://oygtaeriljuelhshfvkv.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json"
}

req = urllib.request.Request(f"{url}/rest/v1/order_conversations?select=id,order_number,distribution_center_id,distribution_center_name,delivery_agent_id,delivery_agent_name", headers=headers)
with urllib.request.urlopen(req, context=ctx) as resp:
    convs = json.loads(resp.read().decode())
    null_dc = [c for c in convs if not c.get('distribution_center_id')]
    print(f"Total conversations: {len(convs)}, missing distribution_center_id: {len(null_dc)}")
    for c in convs[:5]:
        print("Sample:", c)

