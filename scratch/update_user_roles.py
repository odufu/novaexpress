# 1. Update user.dart
path1 = "lib/features/auth/domain/entities/user.dart"
with open(path1, "r", encoding="utf-8") as f:
    text1 = f.read()

old_closer = "bool get isCloser => role == 'closer' || role == 'client_closer';"
new_closer = """bool get isCloserSupervisor =>
      (isCloserRaw && isSupervisor) ||
      role == 'sales_supervisor' ||
      role == 'closer_supervisor' ||
      role == 'sales_rep_supervisor';
  bool get isCloserRaw => role == 'closer' || role == 'client_closer';
  bool get isCloser => isCloserRaw || isCloserSupervisor;"""

text1 = text1.replace(old_closer, new_closer)

old_role_desc = "if (isGeneralAccountant) return 'General Accountant';"
new_role_desc = """if (isCloserSupervisor) return 'Merchant Sales Rep Supervisor';
    if (isGeneralAccountant) return 'General Accountant';"""
text1 = text1.replace(old_role_desc, new_role_desc)

old_route = "if (isGeneralAccountant) return '/accountant';"
new_route = """if (isCloserSupervisor) return '/sales-supervisor';
    if (isGeneralAccountant) return '/accountant';"""
text1 = text1.replace(old_route, new_route)

with open(path1, "w", encoding="utf-8") as f:
    f.write(text1)
print("Updated user.dart")

# 2. Update user_model.dart
path2 = "lib/features/auth/data/models/user_model.dart"
with open(path2, "r", encoding="utf-8") as f:
    text2 = f.read()

old_sup = "json['role'] == 'supervisor_marketer'"
new_sup = "json['role'] == 'supervisor_marketer' || json['role'] == 'sales_supervisor' || json['role'] == 'closer_supervisor' || json['role'] == 'sales_rep_supervisor'"

text2 = text2.replace(old_sup, new_sup)
with open(path2, "w", encoding="utf-8") as f:
    f.write(text2)
print("Updated user_model.dart")
