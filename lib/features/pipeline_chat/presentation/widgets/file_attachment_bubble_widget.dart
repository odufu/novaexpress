import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/order_conversation_message.dart';
import 'image_viewer_modal.dart';

class FileAttachmentBubbleWidget extends StatelessWidget {
  final OrderConversationMessageEntity msg;
  final bool isMyMessage;
  final bool isDark;

  const FileAttachmentBubbleWidget({
    super.key,
    required this.msg,
    required this.isMyMessage,
    required this.isDark,
  });

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'File';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openOrDownload(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (msg.isImage && msg.fileUrl != null) {
      return _buildImageCard(context);
    } else {
      return _buildDocumentCard(context);
    }
  }

  Widget _buildImageCard(BuildContext context) {
    final caption = msg.metadata['caption']?.toString();
    final fileName = msg.fileName ?? 'Image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => ImageViewerModal.show(
                  context,
                  imageUrl: msg.fileUrl!,
                  title: fileName,
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 260,
                    maxHeight: 220,
                  ),
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  child: Image.network(
                    msg.fileUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: isMyMessage ? Colors.white : const Color(0xFF0284C7),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Container(
                        height: 120,
                        width: 200,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF94A3B8)),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Zoom / Expand overlay hint button
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Optional Caption text
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isMyMessage ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentCard(BuildContext context) {
    final fileName = msg.fileName ?? 'Document';
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'file';
    final sizeStr = _formatFileSize(msg.fileSize);
    final caption = msg.metadata['caption']?.toString();

    Color iconBg = const Color(0xFF0284C7);
    IconData fileIcon = Icons.insert_drive_file_rounded;

    if (ext == 'pdf') {
      iconBg = const Color(0xFFEF4444); // Red PDF
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (ext == 'csv' || ext == 'xlsx' || ext == 'xls') {
      iconBg = const Color(0xFF10B981); // Green Excel/Sheets
      fileIcon = Icons.table_chart_rounded;
    } else if (ext == 'doc' || ext == 'docx') {
      iconBg = const Color(0xFF3B82F6); // Blue Word
      fileIcon = Icons.description_rounded;
    } else if (ext == 'zip' || ext == 'rar') {
      iconBg = const Color(0xFFF59E0B);
      fileIcon = Icons.folder_zip_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _openOrDownload(msg.fileUrl),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMyMessage
                  ? Colors.white.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMyMessage
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                // File Type Badge Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(fileIcon, color: iconBg, size: 22),
                  ),
                ),
                const SizedBox(width: 10),

                // Name and Size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isMyMessage
                              ? Colors.white
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$sizeStr • ${ext.toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isMyMessage
                              ? Colors.white.withValues(alpha: 0.75)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Download Action Circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isMyMessage
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: isMyMessage
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Optional Caption text
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isMyMessage ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
