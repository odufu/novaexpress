import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SyncStatus { online, syncing, offline }

class OfflineSyncBanner extends StatelessWidget {
  final SyncStatus status;
  final int pendingQueueCount;
  final VoidCallback? onForceSync;

  const OfflineSyncBanner({
    super.key,
    this.status = SyncStatus.online,
    this.pendingQueueCount = 0,
    this.onForceSync,
  });

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.online && pendingQueueCount == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = status == SyncStatus.offline;
    final isSyncing = status == SyncStatus.syncing;

    final bgColor = isOffline
        ? const Color(0xFFFEF3C7)
        : (isSyncing ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7));
    final borderColor = isOffline
        ? const Color(0xFFFDE68A)
        : (isSyncing ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0));
    final textColor = isOffline
        ? const Color(0xFF92400E)
        : (isSyncing ? const Color(0xFF1E40AF) : const Color(0xFF166534));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: Row(
        children: [
          if (isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            )
          else
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.cloud_done_rounded,
              size: 16,
              color: textColor,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOffline
                  ? (pendingQueueCount > 0
                      ? 'Offline Mode • $pendingQueueCount action${pendingQueueCount > 1 ? "s" : ""} queued for sync'
                      : 'Offline Mode • Local caching active')
                  : (isSyncing
                      ? 'Synchronizing $pendingQueueCount offline record${pendingQueueCount > 1 ? "s" : ""}...'
                      : 'All offline records synced successfully'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (pendingQueueCount > 0 && !isSyncing && onForceSync != null)
            InkWell(
              onTap: onForceSync,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sync Now',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.sync_rounded, size: 13, color: textColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
