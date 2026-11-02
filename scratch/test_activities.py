import urllib.request, json

key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"
headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}

# Test reading order_activities
url = "https://hwyqqjilcifxajruusoa.supabase.co/rest/v1/order_activities?select=*&limit=3"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    print(f"order_activities records: {len(data)}")
    for d in data:
        print(f"  activity: {d.get('activity_type')} | notes: {d.get('notes')[:60] if d.get('notes') else ''}")
