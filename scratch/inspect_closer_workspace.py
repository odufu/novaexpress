with open("lib/features/client_portal/presentation/pages/client_closer_workspace_page.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
print(f"Total lines in closer workspace: {len(lines)}")
for i in range(min(80, len(lines))):
    print(f"{i+1}: {lines[i]}", end="")
