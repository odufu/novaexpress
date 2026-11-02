path = "lib/features/client_portal/presentation/providers/sales_supervisor_provider.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add OrderModel import
text = text.replace(
    "import '../../../orders/domain/entities/order.dart';",
    "import '../../../orders/domain/entities/order.dart';\nimport '../../../orders/data/models/order_model.dart';"
)

# Fix OrderEntity.fromJson
text = text.replace(
    "OrderEntity.fromJson(Map<String, dynamic>.from(item as Map))",
    "OrderModel.fromJson(Map<String, dynamic>.from(item as Map)).toEntity()"
)

# Fix nullable status check
text = text.replace(
    "final candidateOrders = ordersList.where((o) => o.status != 'delivered').take(3).toList();",
    "final candidateOrders = ordersList.where((o) => o.status?.toLowerCase() != 'delivered').take(3).toList();"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Fixed sales_supervisor_provider.dart")
