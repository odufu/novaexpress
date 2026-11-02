path = "lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix in _buildUpgRequestCard
text = text.replace(
    """                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                            content: Text(res['message']?.toString() ?? 'UPG processed.'),
                          ),
                        );
                      }""",
    """                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                          content: Text(res['message']?.toString() ?? 'UPG processed.'),
                        ),
                      );"""
)

# Fix _showRejectPrompt parameter and context
text = text.replace(
    "onPressed: () => _showRejectPrompt(context, req, supervisorName),",
    "onPressed: () => _showRejectPrompt(req, supervisorName),"
)

text = text.replace(
    "void _showRejectPrompt(BuildContext context, UpgRequest req, String supervisorName) {",
    "void _showRejectPrompt(UpgRequest req, String supervisorName) {"
)

text = text.replace(
    """              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFDC2626),
                    content: Text(res['message']?.toString() ?? 'UPG request declined.'),
                  ),
                );
              }""",
    """              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFDC2626),
                  content: Text(res['message']?.toString() ?? 'UPG request declined.'),
                ),
              );"""
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated mounted context check")
