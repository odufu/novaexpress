with open("lib/features/client_portal/presentation/providers/client_portal_provider.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines in client_portal_provider: {len(lines)}")
for i, l in enumerate(lines[:80]):
    print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
