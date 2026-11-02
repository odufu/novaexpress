path = "lib/core/router/app_router.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add import
import_stmt = "import '../../features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart';"
if import_stmt not in text:
    text = text.replace(
        "import '../../features/client_portal/presentation/pages/closer_mobile_portal_page.dart';",
        "import '../../features/client_portal/presentation/pages/closer_mobile_portal_page.dart';\n" + import_stmt
    )

# Add route
route_stmt = """      GoRoute(
        path: '/sales-supervisor',
        builder: (context, state) => const MerchantSalesSupervisorPage(),
      ),"""

if "path: '/sales-supervisor'" not in text:
    text = text.replace(
        "      GoRoute(\n        path: '/closer',",
        route_stmt + "\n      GoRoute(\n        path: '/closer',"
    )

# Add isolation in redirect
iso_stmt = """    // Sales Supervisor Console (/sales-supervisor/**)
    if (matchedLocation.startsWith('/sales-supervisor')) {
      if (!user.isCloserSupervisor && !user.isClientAdmin) {
        return homePath;
      }
    }
    if (user.isCloserSupervisor && !matchedLocation.startsWith('/sales-supervisor') && !matchedLocation.startsWith('/closer')) {
      return '/sales-supervisor';
    }
"""

if "user.isCloserSupervisor" not in text:
    text = text.replace(
        "    // Finance Admin Console (/finance-ops/**)",
        iso_stmt + "    // Finance Admin Console (/finance-ops/**)"
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated app_router.dart")
