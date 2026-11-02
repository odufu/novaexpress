with open("lib/features/auth/presentation/widgets/login_form.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(40, min(120, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
