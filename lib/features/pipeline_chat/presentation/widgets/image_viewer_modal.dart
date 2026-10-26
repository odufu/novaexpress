import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageViewerModal extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ImageViewerModal({
    super.key,
    required this.imageUrl,
    this.title = 'Image',
  });

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String title = 'Image',
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => ImageViewerModal(imageUrl: imageUrl, title: title),
    );
  }

  Future<void> _downloadOrOpen(BuildContext context) async {
    final uri = Uri.parse(imageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Zoomable Image
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF0284C7),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load image',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Open / Download Full Image',
                    onPressed: () => _downloadOrOpen(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
