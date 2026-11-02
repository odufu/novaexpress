with open("lib/features/client_portal/presentation/pages/client_closers_page.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines in client_closers_page: {len(lines)}")
for i in range(min(100, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
