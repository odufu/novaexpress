with open("lib/features/client_portal/domain/entities/customer_lead.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines[:35]):
    print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
