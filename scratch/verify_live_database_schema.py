import urllib.request
import json

ENVS = {
    "Testing / Active (hwyqqjilcifxajruusoa)": {
        "url": "https://hwyqqjilcifxajruusoa.supabase.co",
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
    },
    "Original Production (oygtaeriljuelhshfvkv)": {
        "url": "https://oygtaeriljuelhshfvkv.supabase.co",
        "key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
    }
}

def check_env(name, cfg):
    print("=" * 60)
    print(f"CHECKING: {name}")
    print("=" * 60)
    base_url = cfg["url"]
    key = cfg["key"]
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    }

    # 1. Check orders columns
    try:
        url = f"{base_url}/rest/v1/orders?select=*&limit=1"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data:
                keys = set(data[0].keys())
                print(f"[OK] Table 'orders' accessible. Total cols: {len(keys)}")
                order_needed = ['paid_quantity', 'free_quantity', 'base_price', 'package_deal_id', 'package_deal_name', 'delivery_notes', 'payment_type']
                for col in order_needed:
                    has_col = col in keys
                    print(f"   - Column '{col}': {'[YES]' if has_col else '[MISSING]'}")
            else:
                print("[WARN] Table 'orders' is empty.")
    except Exception as e:
        print(f"[ERROR] orders: {e}")

    # 2. Check business_expenditures
    try:
        url = f"{base_url}/rest/v1/business_expenditures?select=*&limit=1"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data:
                keys = set(data[0].keys())
                print(f"[OK] Table 'business_expenditures' accessible. Cols: {len(keys)}")
                exp_needed = ['invoice_number', 'vendor_name', 'payment_method', 'status', 'distribution_center_id', 'receipt_url', 'category', 'amount']
                for col in exp_needed:
                    has_col = col in keys
                    print(f"   - Column '{col}': {'[YES]' if has_col else '[MISSING]'}")
            else:
                print("[WARN] Table 'business_expenditures' is empty. Testing column query...")
                url2 = f"{base_url}/rest/v1/business_expenditures?select=invoice_number,vendor_name,payment_method,status,distribution_center_id,receipt_url&limit=0"
                req2 = urllib.request.Request(url2, headers=headers)
                with urllib.request.urlopen(req2) as resp2:
                    print("   [OK] Columns exist in empty table!")
    except Exception as e:
        print(f"[ERROR] business_expenditures: {e}")

    # 3. Check product_packages
    try:
        url = f"{base_url}/rest/v1/product_packages?select=*&limit=5"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"[OK] Table 'product_packages' accessible. Rows: {len(data)}")
    except Exception as e:
        print(f"[ERROR] product_packages: {e}")

    # 4. Check buckets
    try:
        url = f"{base_url}/storage/v1/bucket"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            buckets = json.loads(resp.read().decode('utf-8'))
            bucket_ids = [b.get('id') for b in buckets]
            print(f"[OK] Storage buckets: {bucket_ids}")
            has_receipts = 'expenditure-receipts' in bucket_ids
            print(f"   - Bucket 'expenditure-receipts': {'[EXISTS]' if has_receipts else '[MISSING]'}")
    except Exception as e:
        print(f"[ERROR] storage buckets: {e}")

for name, cfg in ENVS.items():
    check_env(name, cfg)
