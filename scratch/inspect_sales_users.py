import urllib.request, json

key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}

url = f"https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/users?select=id,first_name,last_name,email,role,is_supervisor,client_id&or=(role.ilike.*closer*,role.ilike.*sales*,is_supervisor.eq.true)"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    print(f"Matching users ({len(data)}):")
    for u in data:
        print(u)
