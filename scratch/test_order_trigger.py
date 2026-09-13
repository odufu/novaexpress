import json
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

# Let's test calling curl with PATCH on an order or querying trigger
cmd = [
    "curl.exe", "--ipv4", "-s", "-X", "PATCH",
    "https://qpcafevjsrbauweuiiyq.supabase.co/rest/v1/orders?order_number=eq.TRK-7954",
    "-H", "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU",
    "-H", "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU",
    "-H", "Content-Type: application/json",
    "-H", "Prefer: return=representation",
    "-d", "{\"delivery_agent_id\": \"efcf71a2-486c-455d-bf38-66f088f443c6\"}"
]

res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
print("Returncode:", res.returncode)
print("Stdout:", res.stdout)
print("Stderr:", res.stderr)
