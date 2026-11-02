import urllib.request
import json

url = "https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/rpc/"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json"
}

try:
    req = urllib.request.Request("https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/?apikey=" + key, headers=headers)
    with urllib.request.urlopen(req) as resp:
        spec = json.loads(resp.read().decode('utf-8'))
        rpcs = [p.replace('/rpc/', '') for p in spec.get('paths', {}).keys() if p.startswith('/rpc/')]
        print(f"Total RPCs on active backend: {len(rpcs)}")
        for r in rpcs[:15]:
            print(f"  - {r}")
except Exception as e:
    print(f"Error: {e}")
