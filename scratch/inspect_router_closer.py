with open("lib/core/router/app_router.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i in range(250, 290):
    print(f"{i+1}: {lines[i]}".encode("ascii", errors="replace").decode("ascii"), end="")
