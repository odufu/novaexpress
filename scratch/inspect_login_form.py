with open("lib/features/auth/presentation/widgets/login_form.dart", "r", encoding="utf-8") as f:
    text = f.read()

import re
emails = re.findall(r"[\w\.-]+@[\w\.-]+\.\w+", text)
print(f"Emails found in login_form.dart ({len(emails)}):")
for e in set(emails):
    print(f"  {e}")
