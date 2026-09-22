import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable Transfer Receipt & Proof of Payment Preview Dialog
/// Supports zoomable interactive image inspection (HTTPS & base64) and external PDF/document opening.
class PayoutReceiptPreviewDialog extends StatelessWidget {
  final String receiptUrl;
  final String title;
  final String? subtitle;
  final String? amountFormatted;

  const PayoutReceiptPreviewDialog({
    super.key,
    required this.receiptUrl,
    this.title = 'Transfer Receipt Proof',
    this.subtitle,
    this.amountFormatted,
  });

  static Future<void> show(
    BuildContext context, {
    required String receiptUrl,
    String title = 'Transfer Receipt Proof',
    String? subtitle,
    String? amountFormatted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PayoutReceiptPreviewDialog(
        receiptUrl: receiptUrl,
        title: title,
        subtitle: subtitle,
        amountFormatted: amountFormatted,
      ),
    );
  }

  bool get _isPdf {
    final lower = receiptUrl.toLowerCase();
    return lower.contains('.pdf') || receiptUrl.startsWith('data:application/pdf');
  }

  Future<void> _openExternal(BuildContext context) async {
    final uri = Uri.tryParse(receiptUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('Could not open document link: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDataUri = receiptUrl.startsWith('data:image');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (amountFormatted != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        amountFormatted!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isDataUri)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                      tooltip: 'Open in Browser / Fullscreen',
                      onPressed: () => _openExternal(context),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area
            Flexible(
              child: _isPdf
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'PDF Transfer Receipt Document',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This settlement proof is a digital PDF statement or bank transfer voucher.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _openExternal(context),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: Text(
                              'Open PDF Receipt',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    )
                  : InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(24),
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: isDataUri
                            ? Image.memory(
                                Uri.parse(receiptUrl).data!.contentAsBytes(),
                                fit: BoxFit.contain,
                              )
                            : Image.network(
                                receiptUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  final total = progress.expectedTotalBytes;
                                  final loaded = progress.cumulativeBytesLoaded;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: (total != null && total > 0) ? loaded / total : null,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFFEF4444)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Unable to display image preview',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () => _openExternal(context),
                                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                        label: const Text('Try opening external link'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
