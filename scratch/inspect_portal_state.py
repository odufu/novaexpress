with open("lib/features/client_portal/presentation/providers/client_portal_provider.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if "class ClientPortalState" in l:
        for j in range(i, min(len(lines), i+60)):
            print(f"{j+1}: {lines[j].strip()}".encode("ascii", errors="replace").decode("ascii"))
        break
