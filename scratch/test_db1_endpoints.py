import urllib.request, json, time

k_anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0.o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc'
k_service = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM'
url = 'https://oygtaeriljuelhshfvkv.supabase.co'
cid = '00000000-0000-4000-8000-791731264594'

endpoints = [
    ('clients', f'clients?id=eq.{cid}&select=*'),
    ('client_closers', f'client_closers?client_id=eq.{cid}&select=*'),
    ('customer_leads', f'customer_leads?client_id=eq.{cid}&select=*'),
    ('client_settlements', f'client_settlements?client_id=eq.{cid}&select=*'),
    ('client_suppliers', f'client_suppliers?client_id=eq.{cid}&select=*'),
    ('client_stock_invoices', f'client_stock_invoices?client_id=eq.{cid}&select=*'),
    ('client_stock_balances', f'client_stock_balances?client_id=eq.{cid}&select=*'),
    ('client_closer_payouts', f'client_closer_payouts?client_id=eq.{cid}&select=*'),
    ('client_marketers', f'client_marketers?client_id=eq.{cid}&select=*'),
    ('client_lead_forms', f'client_lead_forms?client_id=eq.{cid}&select=*'),
    ('client_marketer_payouts', f'client_marketer_payouts?client_id=eq.{cid}&select=*'),
    ('client_accountants', f'client_accountants?client_id=eq.{cid}&select=*'),
    ('rpc:custody', 'rpc/fn_calculate_merchant_asset_custody'),
    ('rpc:period_stock', 'rpc/fn_get_client_stock_balance_period')
]

print("=== TESTING WITH SERVICE ROLE KEY ===")
for name, ep in endpoints:
    full_url = f'{url}/rest/v1/{ep}'
    t0 = time.time()
    try:
        if name.startswith('rpc:'):
            req = urllib.request.Request(full_url, data=json.dumps({'p_client_id': cid}).encode(), headers={'apikey': k_service, 'Authorization': f'Bearer {k_service}', 'Content-Type': 'application/json'})
        else:
            req = urllib.request.Request(full_url, headers={'apikey': k_service, 'Authorization': f'Bearer {k_service}'})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            dur = time.time() - t0
            print(f"  {name:25} -> OK ({dur:.2f}s) count={len(data) if isinstance(data, list) else type(data)}")
    except Exception as e:
        dur = time.time() - t0
        print(f"  {name:25} -> ERR ({dur:.2f}s): {e}")

print("\n=== TESTING WITH ANON KEY ===")
for name, ep in endpoints:
    full_url = f'{url}/rest/v1/{ep}'
    t0 = time.time()
    try:
        if name.startswith('rpc:'):
            req = urllib.request.Request(full_url, data=json.dumps({'p_client_id': cid}).encode(), headers={'apikey': k_anon, 'Authorization': f'Bearer {k_anon}', 'Content-Type': 'application/json'})
        else:
            req = urllib.request.Request(full_url, headers={'apikey': k_anon, 'Authorization': f'Bearer {k_anon}'})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            dur = time.time() - t0
            print(f"  {name:25} -> OK ({dur:.2f}s) count={len(data) if isinstance(data, list) else type(data)}")
    except Exception as e:
        dur = time.time() - t0
        print(f"  {name:25} -> ERR ({dur:.2f}s): {e}")

