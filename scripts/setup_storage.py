import io
import urllib.request
import urllib.error
import json
import sys

# Ensure UTF-8 stdout for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

SUPABASE_BASE = "https://oygtaeriljuelhshfvkv.supabase.co"
STORAGE_URL = f"{SUPABASE_BASE}/storage/v1"
SERVICE_ROLE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ."
    "2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM"
)

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}

def list_buckets():
    url = f"{STORAGE_URL}/bucket"
    req = urllib.request.Request(url, headers=HEADERS, method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"Error listing buckets: {e}")
        return []

def create_or_update_bucket(bucket_id, name=None, public=True, file_size_limit=5242880, allowed_mime_types=None):
    if name is None:
        name = bucket_id
    if allowed_mime_types is None:
        allowed_mime_types = ["image/jpeg", "image/png", "image/webp", "image/gif"]

    payload = {
        "id": bucket_id,
        "name": name,
        "public": public,
        "file_size_limit": file_size_limit,
        "allowed_mime_types": allowed_mime_types
    }

    # First try creating
    url = f"{STORAGE_URL}/bucket"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"✅ Created bucket '{bucket_id}' (Public={public}, MaxSize={file_size_limit//1024//1024}MB, MIMEs={allowed_mime_types})")
            return
    except urllib.error.HTTPError as e:
        # If exists, update it
        update_url = f"{STORAGE_URL}/bucket/{bucket_id}"
        req_update = urllib.request.Request(update_url, data=data, headers=HEADERS, method="PUT")
        try:
            with urllib.request.urlopen(req_update) as resp:
                print(f"✅ Updated existing bucket '{bucket_id}' restrictions (Public={public}, MaxSize={file_size_limit//1024//1024}MB, MIMEs={allowed_mime_types})")
        except Exception as update_err:
            print(f"ℹ️ Bucket notice for '{bucket_id}': {update_err}")

def main():
    print("🚀 Configuring Supabase Storage Buckets & Upload Restrictions...")
    
    # 1. Buckets creation with image-only and size restrictions
    create_or_update_bucket("avatars", "avatars", public=True, file_size_limit=5242880, allowed_mime_types=["image/jpeg", "image/png", "image/webp", "image/gif"])
    create_or_update_bucket("remittance-proofs", "remittance-proofs", public=True, file_size_limit=10485760, allowed_mime_types=["image/jpeg", "image/png", "image/webp", "application/pdf"])
    create_or_update_bucket("pod-proofs", "pod-proofs", public=True, file_size_limit=10485760, allowed_mime_types=["image/jpeg", "image/png", "image/webp"])

    buckets = list_buckets()
    print("\n📦 Active Supabase Storage Buckets:")
    for b in buckets:
        print(f" - Bucket: {b.get('id')} | Public: {b.get('public')} | Size Limit: {b.get('file_size_limit')} bytes | Allowed MIME: {b.get('allowed_mime_types')}")

if __name__ == "__main__":
    main()
