path = "lib/features/auth/presentation/widgets/quick_account_dropdown.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add Sales Supervisor to secondaryAccounts
target = "static const List<QuickAccountOption> secondaryAccounts = ["
replacement = """static const List<QuickAccountOption> secondaryAccounts = [
    QuickAccountOption(
      roleKey: 'sales_supervisor',
      title: 'Merchant Sales Rep Supervisor',
      personName: 'Amaka Chioma (Supervisor)',
      badge: 'Supervisor (/sales-supervisor)',
      email: 'sales.supervisor@novaxpress.ng',
      password: 'Password123!',
      icon: Icons.verified_user_rounded,
      themeColor: Color(0xFFF37021),
      isSecondary: true,
    ),"""

if "roleKey: 'sales_supervisor'" not in text:
    text = text.replace(target, replacement)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("Added sales_supervisor to quick_account_dropdown.dart")
else:
    print("Already present in quick_account_dropdown.dart")
