with open("lib/features/client_portal/presentation/widgets/client_closer_detail_modal.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines in client_closer_detail_modal: {len(lines)}")
for i in range(min(70, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
