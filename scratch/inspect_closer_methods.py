with open("lib/features/client_portal/presentation/pages/client_closer_workspace_page.dart", "r", encoding="utf-8") as f:
    text = f.read()

import re
methods = re.findall(r"Widget _build\w+\(.*?\)", text)
print("Build methods in closer workspace:")
for m in methods:
    print(" ", m)
