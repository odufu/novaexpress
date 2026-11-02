with open("lib/features/client_portal/presentation/pages/client_closer_workspace_page.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(25, min(200, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
