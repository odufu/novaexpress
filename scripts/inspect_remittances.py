import io
import sys
import os
import json
import urllib.request

os.environ['no_proxy'] = '*'

URL = "https://oygtaeriljuelhshfvkv.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json"
}

req = urllib.request.Request(f"{URL}/rest/v1/cash_remittances?select=*&order=created_at.desc&limit=5", headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        print("Remittances count:", len(data))
        for r in data:
            print(json.dumps(r, indent=2))
except Exception as e:
    print("Error:", e)
