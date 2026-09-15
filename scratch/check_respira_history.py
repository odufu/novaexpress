import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
req = urllib.request.Request(
    'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/stock_transfer_items?product_id=eq.f4530a12-5ea4-4332-a19c-75ad1348e43b&select=*,stock_transfers(*)', 
    headers={
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU'
    }
)
data = json.loads(urllib.request.urlopen(req, context=ctx).read().decode())
for item in data:
    t = item.get('stock_transfers')
    if t:
        print(f"WB: {t.get('waybill_number')} | Type: {t.get('transfer_type')} | Status: {t.get('status')} | Ship: {item.get('quantity_shipped')} | Rec: {item.get('quantity_received')} | Dest: {t.get('destination_dc_id')} | Created: {t.get('created_at')}")
