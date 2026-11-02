with open("lib/features/auth/presentation/widgets/quick_account_dropdown.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(25, min(100, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
