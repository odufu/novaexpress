import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 4: No Internet State
/// Never leaves users staring at a blank screen. Displays clear offline notification,
/// preserves cached local data, and provides seamless retry options.
class NovaNoInternetState extends StatelessWidget {
  final String? title;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final int pendingSyncCount;
  final int? pendingActionsCount;
  final String? customMessage;

  const NovaNoInternetState({
    super.key,
    this.title,
    this.onRetry,
    this.isRetrying = false,
    this.pendingSyncCount = 0,
    this.pendingActionsCount,
    this.customMessage,
  });

  int get effectivePendingCount => pendingActionsCount ?? pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const offlineColor = Color(0xFFF59E0B);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: offlineColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: offlineColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 38,
                    color: offlineColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title ?? 'You Are Offline',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                customMessage ??
                    'Your connection to the network was interrupted. All current form drafts and customer data are preserved locally so you can continue operations safely.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),

              // Offline Sync Status Banner
              if (effectivePendingCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$effectivePendingCount Pending Offline Actions Queued',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Retry Button
              ElevatedButton.icon(
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                label: Text(
                  isRetrying ? 'Connecting...' : 'Retry Connection',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: offlineColor,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

