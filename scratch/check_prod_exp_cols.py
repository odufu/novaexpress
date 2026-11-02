import urllib.request
import json

base_url = "https://oygtaeriljuelhshfvkv.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json"
}

cols = ['id', 'title', 'amount', 'category', 'expenditure_date', 'distribution_center_id', 'receipt_url', 'invoice_number', 'vendor_name', 'payment_method', 'status']

for c in cols:
    try:
        url = f"{base_url}/rest/v1/business_expenditures?select={c}&limit=0"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            print(f"Col '{c}': [EXISTS]")
    except urllib.error.HTTPError as e:
        print(f"Col '{c}': [MISSING] ({e.code})")
    except Exception as e:
        print(f"Col '{c}': {e}")
