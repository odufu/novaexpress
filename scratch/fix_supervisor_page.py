path = "lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix productInterest
text = text.replace("lead.productName", "lead.productInterest")

# Clean unused imports
text = text.replace("import '../../../orders/domain/entities/order.dart';\n", "")
text = text.replace("import '../../domain/entities/client_closer.dart';\n", "")
text = text.replace("import '../widgets/client_order_tracking_modal.dart';\n", "")
text = text.replace("import '../widgets/request_upg_modal.dart';\n", "")

# Fix context.mounted check in showRejectPrompt
text = text.replace(
    """            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(salesSupervisorProvider.notifier).rejectUpgRequest(
                upgId: req.id,
                reason: reasonController.text.trim(),
                supervisorName: supervisorName,
              );
              if (context.mounted) {""",
    """            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(salesSupervisorProvider.notifier).rejectUpgRequest(
                upgId: req.id,
                reason: reasonController.text.trim(),
                supervisorName: supervisorName,
              );
              if (mounted) {"""
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated merchant_sales_supervisor_page.dart")
