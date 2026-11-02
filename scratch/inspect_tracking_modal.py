with open("lib/features/client_portal/presentation/widgets/client_order_tracking_modal.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines in client_order_tracking_modal: {len(lines)}")
for i in range(min(50, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
