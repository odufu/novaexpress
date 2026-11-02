path = "lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("ScaffoldMessenger.of(this.context)", "ScaffoldMessenger.of(context)")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Removed this.context")
