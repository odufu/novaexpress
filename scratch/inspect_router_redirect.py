with open("lib/core/router/app_router.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(70, 160):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
