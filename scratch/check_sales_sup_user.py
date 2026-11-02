import urllib.request, json

key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}

email = "sales.supervisor@novaxpress.ng"
url = f"https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/users?email=eq.{email}&select=*"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    print(f"User in public.users: {len(data)}")
    if data:
        print(data[0])
