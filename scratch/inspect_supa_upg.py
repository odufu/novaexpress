with open("lib/core/constants/supabase_constants.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if "upg" in l.lower():
        print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
