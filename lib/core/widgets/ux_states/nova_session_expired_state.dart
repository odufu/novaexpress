import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 8: Session Expired State
/// Protects users from unexpected logouts. Preserves unsaved shipment inputs
/// and incomplete dispatch drafts, guiding users through seamless re-authentication.
class NovaSessionExpiredState extends StatelessWidget {
  final bool hasUnsavedDraft;
  final String? preservedDraftSummary;
  final String? unsavedDraftDescription;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignInResume;
  final VoidCallback? onSwitchAccount;

  const NovaSessionExpiredState({
    super.key,
    this.hasUnsavedDraft = true,
    this.preservedDraftSummary,
    this.unsavedDraftDescription,
    this.onSignIn,
    this.onSignInResume,
    this.onSwitchAccount,
  });

  static Future<void> showAsDialog(
    BuildContext context, {
    String? preservedDraftSummary,
    required VoidCallback onSignIn,
    VoidCallback? onSwitchAccount,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: NovaSessionExpiredState(
              preservedDraftSummary: preservedDraftSummary,
              onSignIn: onSignIn,
              onSwitchAccount: onSwitchAccount,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const sessionColor = Color(0xFFF37021);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Badge
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: sessionColor.withValues(alpha: isDark ? 0.2 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: sessionColor.withValues(alpha: isDark ? 0.4 : 0.25),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.lock_clock_rounded,
                size: 34,
                color: sessionColor,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'Session Expired',
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
            'Your login credentials expired. For your protection and compliance with financial audit logs, please authenticate again to continue.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),

          // Preserved Draft Notice
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.save_as_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unsaved Work Preserved',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (unsavedDraftDescription != null)
                            ? 'Unsaved Draft Preserved: $unsavedDraftDescription'
                            : (preservedDraftSummary ?? 'Your current shipment inputs and delivery notes are cached locally and will be restored immediately after sign-in.'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onSignInResume ?? onSignIn,
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Sign In & Resume',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sessionColor,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              if (onSwitchAccount != null)
                TextButton(
                  onPressed: onSwitchAccount,
                  child: Text(
                    'Switch Account',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

