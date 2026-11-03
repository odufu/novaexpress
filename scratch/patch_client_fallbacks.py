import re

# 1. Update client_dashboard_page.dart
path1 = 'lib/features/client_portal/presentation/pages/client_dashboard_page.dart'
with open(path1, 'r', encoding='utf-8') as f:
    c1 = f.read()
c1 = c1.replace("'Novacare Limited'", "'NOVACARE LIMITED'")
c1 = c1.replace("'NOVACARE-LTD'", "'CLI-S1-212'")
with open(path1, 'w', encoding='utf-8') as f:
    f.write(c1)
print("Updated client_dashboard_page.dart")

# 2. Update client_portal_provider.dart
path2 = 'lib/features/client_portal/presentation/providers/client_portal_provider.dart'
with open(path2, 'r', encoding='utf-8') as f:
    c2 = f.read()

# Replace initial state
old_initial = """          ClientPortalState(
            clientProfile: const ClientProfile(
              id: '',
              companyName: '',
              contactPerson: '',
              email: '',
              phone: '',
              address: '',
              city: '',
              state: '',
              code: '',
              tier: 'standard',
              closerLimit: 0,
              isEnterprise: false,
            ),
          ),"""

new_initial = """          ClientPortalState(
            clientProfile: const ClientProfile(
              id: '00000000-0000-4000-8000-791731264594',
              companyName: 'NOVACARE LIMITED',
              contactPerson: 'JOEL ODUFU',
              email: 'novacare@novaxpress.ng',
              phone: '08076565456',
              address: 'Abuja Regional DC',
              city: 'Abuja',
              state: 'FCT - Abuja',
              code: 'CLI-S1-212',
              tier: 'enterprise',
              closerLimit: 250,
              isEnterprise: true,
              logoUrl: 'https://oygtaeriljuelhshfvkv.supabase.co/storage/v1/object/public/avatars/client_logos/logo_00000000-0000-4000-8000-791731264594_1791977232075.webp',
            ),
          ),"""

# Handle both \r\n and \n
c2_norm = c2.replace('\r\n', '\n')
old_norm = old_initial.replace('\r\n', '\n')
new_norm = new_initial.replace('\r\n', '\n')
if old_norm in c2_norm:
    c2_norm = c2_norm.replace(old_norm, new_norm)
    print("Replaced initial ClientProfile state in client_portal_provider.dart")
else:
    print("Warning: initial ClientProfile state not found in client_portal_provider.dart")

# Replace 00000000-0000-4000-8000-789382731303 with 00000000-0000-4000-8000-791731264594
c2_norm = c2_norm.replace('00000000-0000-4000-8000-789382731303', '00000000-0000-4000-8000-791731264594')
c2_norm = c2_norm.replace('Novacare Health & Wellness Ltd', 'NOVACARE LIMITED')

with open(path2, 'w', encoding='utf-8') as f:
    f.write(c2_norm)
print("Updated client_portal_provider.dart")

# 3. Update auth_remote_datasource.dart
path3 = 'lib/features/auth/data/datasources/auth_remote_datasource.dart'
with open(path3, 'r', encoding='utf-8') as f:
    c3 = f.read()
c3 = c3.replace('00000000-0000-4000-8000-789382731303', '00000000-0000-4000-8000-791731264594')
c3 = c3.replace('CLI-NOVACARE-01', 'CLI-S1-212')
c3 = c3.replace('Novacare Health & Wellness Ltd', 'NOVACARE LIMITED')
with open(path3, 'w', encoding='utf-8') as f:
    f.write(c3)
print("Updated auth_remote_datasource.dart")

# 4. Update closer_mobile_portal_page.dart and client_add_supplier_modal.dart
for p in [
    'lib/features/client_portal/presentation/pages/closer_mobile_portal_page.dart',
    'lib/features/client_portal/presentation/widgets/client_add_supplier_modal.dart'
]:
    with open(p, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace('00000000-0000-4000-8000-789382731303', '00000000-0000-4000-8000-791731264594')
    c = c.replace('Novacare Health & Wellness Ltd', 'NOVACARE LIMITED')
    with open(p, 'w', encoding='utf-8') as f:
        f.write(c)
    print(f"Updated {p}")

