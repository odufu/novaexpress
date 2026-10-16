#!/usr/bin/env python3
import urllib.request
import json

TGT_URL = "https://hwyqqjilcifxajruusoa.supabase.co"
TGT_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3eXFxamlsY2lmeGFqcnV1c29hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEwMTQ3MiwiZXhwIjoyMTA3Njc3NDcyfQ.ow0xtvrgq3wUXKlGeIDgRtBrKeirzy9XHN_8s8TCAiI"

headers = {
    'apikey': TGT_KEY,
    'Authorization': f'Bearer {TGT_KEY}',
    'Content-Type': 'application/json'
}

accounts_to_sync = [
    {
        "email": "novacare@novaxpress.net",
        "password": "novacare@novaxpress.net",
        "role": "client",
        "first_name": "Novacare",
        "last_name": "Merchant",
        "phone": "+2348000000001",
    },
    {
        "email": "prestige.godwin@novaxpress.net",
        "password": "Closer123!",
        "role": "closer",
        "first_name": "Prestige",
        "last_name": "Godwin",
        "phone": "+2348000000002",
    },
    {
        "email": "abigail.kooyon@novaxpress.net",
        "password": "CDV8pRxC#b",
        "role": "operations",
        "first_name": "Abigail",
        "last_name": "Kooyon",
        "phone": "+2348000000003",
    },
    {
        "email": "oladele.omowaye@novaxpress.ng",
        "password": "omowaye123456",
        "role": "delivery_agent",
        "first_name": "Oladele",
        "last_name": "Omowaye",
        "phone": "+2348000000004",
    },
    {
        "email": "ojo.modupeolami@novaxpress.ng",
        "password": "ojo.modupeolami@novaxpress.ng",
        "role": "closer",
        "first_name": "Ojo",
        "last_name": "Modupeolami",
        "phone": "+2348000000005",
    },
    {
        "email": "adewole.ibukun@novaxpress.ng",
        "password": "Closer123!",
        "role": "closer",
        "first_name": "Adewole",
        "last_name": "Ibukun",
        "phone": "+2348000000006",
    },
]

# Fetch clients to get Novacare client ID
req = urllib.request.Request(f"{TGT_URL}/rest/v1/clients?select=id,company_name&order=created_at.desc", headers=headers)
with urllib.request.urlopen(req) as resp:
    clients = json.loads(resp.read().decode())
    novacare = next((c for c in clients if c.get('company_name') == 'NOVACARE LIMITED'), clients[0] if clients else None)
    novacare_id = novacare['id'] if novacare else None
    print(f"Using Novacare Client ID: {novacare_id}")

# Fetch DC
req = urllib.request.Request(f"{TGT_URL}/rest/v1/distribution_centers?select=id,name", headers=headers)
with urllib.request.urlopen(req) as resp:
    dcs = json.loads(resp.read().decode())
    wuse_dc = next((d for d in dcs if 'Wuse' in d.get('name', '')), dcs[0] if dcs else None)
    wuse_dc_id = wuse_dc['id'] if wuse_dc else None
    print(f"Using Wuse DC ID: {wuse_dc_id}")

# Fetch all existing auth users
req = urllib.request.Request(f"{TGT_URL}/auth/v1/admin/users?per_page=100", headers=headers)
with urllib.request.urlopen(req) as resp:
    existing_auth = json.loads(resp.read().decode()).get("users", [])
    auth_map = {u["email"].lower(): u for u in existing_auth}

for acc in accounts_to_sync:
    email = acc["email"].lower()
    pw = acc["password"]
    role = acc["role"]
    fn = acc["first_name"]
    ln = acc["last_name"]
    
    uid = auth_map[email]["id"]
    # Check if exists in public.users
    req = urllib.request.Request(f"{TGT_URL}/rest/v1/users?id=eq.{uid}", headers=headers)
    with urllib.request.urlopen(req) as resp:
        found_users = json.loads(resp.read().decode())
    
    if found_users:
        # Patch
        patch_payload = {
            "first_name": fn,
            "last_name": ln,
            "role": role,
        }
        if role == "client" and novacare_id:
            patch_payload["client_id"] = novacare_id
        if wuse_dc_id:
            patch_payload["distribution_center_id"] = wuse_dc_id
        patch_req = urllib.request.Request(
            f"{TGT_URL}/rest/v1/users?id=eq.{uid}",
            data=json.dumps(patch_payload).encode(),
            headers=headers,
            method="PATCH"
        )
        with urllib.request.urlopen(patch_req) as resp:
            print(f"Patched public.users for {email}")
    else:
        # Insert
        insert_payload = {
            "id": uid,
            "email": email,
            "first_name": fn,
            "last_name": ln,
            "role": role,
            "phone_number": acc["phone"],
        }
        if role == "client" and novacare_id:
            insert_payload["client_id"] = novacare_id
        if wuse_dc_id:
            insert_payload["distribution_center_id"] = wuse_dc_id
        insert_req = urllib.request.Request(
            f"{TGT_URL}/rest/v1/users",
            data=json.dumps(insert_payload).encode(),
            headers=headers,
            method="POST"
        )
        with urllib.request.urlopen(insert_req) as resp:
            print(f"Inserted into public.users: {email}")

print("Sync completed flawlessly!")
