with open("lib/features/orders/domain/entities/order.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines[:50]):
    if "status" in l.lower():
        print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
