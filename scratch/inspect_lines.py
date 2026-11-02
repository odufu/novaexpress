with open("lib/features/client_portal/presentation/providers/sales_supervisor_provider.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(220, 280):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
