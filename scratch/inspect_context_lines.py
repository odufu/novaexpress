with open("lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(650, 750):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
