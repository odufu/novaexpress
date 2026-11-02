import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 3: Error State
/// Clearly explains what went wrong in logistics context and provides actionable
/// recovery paths (Retry, Diagnostics, Support).
class NovaErrorState extends StatefulWidget {
  final String title;
  final String message;
  final String? errorCode;
  final dynamic technicalDetails;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData icon;

  const NovaErrorState({
    super.key,
    this.title = 'Operation Encountered an Issue',
    required this.message,
    this.errorCode,
    this.technicalDetails,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.icon = Icons.error_outline_rounded,
  });

  /// Factory for failed shipment dispatch/booking
  factory NovaErrorState.shipmentFailed({
    String? message,
    String? title,
    VoidCallback? onRetry,
    dynamic errorDetails,
  }) {
    return NovaErrorState(
      title: title ?? 'Shipment Creation Failed',
      message: message ?? 'Unable to complete shipment booking. Please check your delivery input details.',
      errorCode: 'ERR-SHIPMENT-FAIL',
      technicalDetails: errorDetails,
      onRetry: onRetry,
      retryLabel: 'Retry Shipment',
      icon: Icons.local_shipping_outlined,
    );
  }

  /// Factory for failed remittance / payment settlement
  factory NovaErrorState.remittanceFailed({
    String? message,
    String? title,
    VoidCallback? onRetry,
    dynamic errorDetails,
  }) {
    return NovaErrorState(
      title: title ?? 'Remittance Submission Failed',
      message: message ?? 'Unable to record remittance transaction at this time.',
      errorCode: 'ERR-SETTLEMENT-RECONCILE',
      technicalDetails: errorDetails,
      onRetry: onRetry,
      retryLabel: 'Re-sync Settlements',
      icon: Icons.receipt_long_outlined,
    );
  }

  /// Factory for database / server communication failure
  factory NovaErrorState.serverError({
    VoidCallback? onRetry,
    String? customMessage,
    String? errorMessage,
    String? title,
    dynamic errorDetails,
  }) {
    return NovaErrorState(
      title: title ?? 'System Connection Issue',
      message: errorMessage ??
          customMessage ??
          'Could not synchronize with the central dispatch database. Please verify your connection or try again shortly.',
      errorCode: 'ERR-LOGISTICS-503',
      technicalDetails: errorDetails,
      onRetry: onRetry,
      retryLabel: 'Reconnect',
      icon: Icons.cloud_off_rounded,
    );
  }

  @override
  State<NovaErrorState> createState() => _NovaErrorStateState();
}

class _NovaErrorStateState extends State<NovaErrorState> {
  bool _showDiagnostics = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const errorColor = Color(0xFFEF4444);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: errorColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 34,
                    color: errorColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Explanation Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),

              // Error Code Tag
              if (widget.errorCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    widget.errorCode!,
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (widget.onRetry != null)
                    ElevatedButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                      label: Text(
                        widget.retryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  if (widget.onSecondaryAction != null && widget.secondaryActionLabel != null)
                    OutlinedButton(
                      onPressed: widget.onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        widget.secondaryActionLabel!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                ],
              ),

              // Technical Diagnostics Disclosure
              if (widget.technicalDetails != null) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _showDiagnostics = !_showDiagnostics),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showDiagnostics ? 'Hide Technical Details' : 'View Technical Details',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showDiagnostics ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16,
                        color: const Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
                if (_showDiagnostics) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DIAGNOSTIC LOG',
                              style: GoogleFonts.firaCode(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: widget.technicalDetails.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Diagnostics copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy Error',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.technicalDetails.toString(),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

