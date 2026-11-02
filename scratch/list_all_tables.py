import urllib.request, json

key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
url = f"https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/?apikey={key}"
headers = {"apikey": key, "Authorization": f"Bearer {key}"}

req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode("utf-8"))
    tables = [p.replace("/", "") for p in spec.get("paths", {}).keys() if not p.startswith("/rpc/")]
    print(f"Total Tables ({len(tables)}):")
    for t in sorted(tables):
        print(f"  {t}")
