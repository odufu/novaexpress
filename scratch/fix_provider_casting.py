path = "lib/features/client_portal/presentation/providers/sales_supervisor_provider.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    ".map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item as Map)).toEntity())",
    ".map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item as Map))).cast<OrderEntity>()"
)

text = text.replace(
    "final candidateOrders = ordersList.where((o) => o.status?.toLowerCase() != 'delivered').take(3).toList();",
    "final candidateOrders = ordersList.where((o) => o.status.toLowerCase() != 'delivered').take(3).toList();"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated sales_supervisor_provider.dart")
