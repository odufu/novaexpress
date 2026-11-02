with open("lib/features/auth/data/models/user_model.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if "is_supervisor" in l or "isSupervisor" in l:
        print(f"{i+1}: {l.strip()}".encode("ascii", errors="replace").decode("ascii"))
