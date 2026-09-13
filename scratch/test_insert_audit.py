import urllib.request
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU'
headers = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

base_url = 'https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1'

def post(endpoint, data):
    req = urllib.request.Request(f'{base_url}/{endpoint}', data=json.dumps(data).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 500, str(e)

test_audit = {
    'audit_number': 'AUD-TEST-001',
    'total_physical_counted': 10,
    'total_system_expected': 10,
    'discrepancy_count': 0,
    'distribution_center_id': '00000000-0000-4000-8000-788825051520',
    'delivery_agent_id': 'efcf71a2-486c-455d-bf38-66f088f443c6',
    'status': 'reconciled',
    'notes': 'Test inventory audit verification'
}

status, res = post('inventory_audits', test_audit)
with open('scratch/audit_test_result.txt', 'w', encoding='utf-8') as f:
    f.write(f'Status: {status}\nResult: {res}\n')
print(f"Status: {status}, Result: {res}")
