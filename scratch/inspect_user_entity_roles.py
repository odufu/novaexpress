with open("lib/features/auth/domain/entities/user.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(80, min(140, len(lines))):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
