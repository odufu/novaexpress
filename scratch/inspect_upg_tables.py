import urllib.request, json

SUPABASE_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
SR_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    "apikey": SR_KEY,
    "Authorization": f"Bearer {SR_KEY}",
    "Content-Type": "application/json"
}

for t in ["upg_requests", "order_upgrades", "upsell_requests", "order_modifications"]:
    try:
        url = f"{SUPABASE_URL}/rest/v1/{t}?select=*&limit=1"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"Table {t}: EXISTS ({len(data)} rows)")
    except urllib.error.HTTPError as e:
        print(f"Table {t}: {e.code} ({e.reason})")
