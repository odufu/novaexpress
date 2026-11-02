with open("lib/core/router/app_router.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if "GoRoute(" in l or "path:" in l:
        print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
