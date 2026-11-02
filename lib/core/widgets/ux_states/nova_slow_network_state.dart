import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 5: Slow Network State
/// Communicates progress and reassures users during poor connectivity,
/// preventing accidental duplicate submissions or panic exits.
class NovaSlowNetworkState extends StatefulWidget {
  final String title;
  final String message;
  final String actionContext; // e.g. "Creating shipment", "Processing payment"
  final int? elapsedSeconds;
  final VoidCallback? onCancel;

  const NovaSlowNetworkState({
    super.key,
    this.title = 'Slow Network Connection',
    this.message = 'We are still processing your logistics request. Do not refresh or submit again to avoid duplicate bookings.',
    this.actionContext = 'Processing transaction',
    this.elapsedSeconds,
    this.onCancel,
  });

  @override
  State<NovaSlowNetworkState> createState() => _NovaSlowNetworkStateState();
}

class _NovaSlowNetworkStateState extends State<NovaSlowNetworkState> {
  late int _secondsElapsed;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsElapsed = widget.elapsedSeconds ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const slowColor = Color(0xFFF37021);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Pulsing Network Pulse
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(slowColor),
                      backgroundColor: slowColor.withValues(alpha: 0.2),
                    ),
                  ),
                  const Icon(
                    Icons.network_check_rounded,
                    size: 28,
                    color: slowColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),

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

              // Reassurance Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),

              // Action Context & Elapsed Timer Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: slowColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.actionContext} (${_secondsElapsed} seconds elapsed)',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.onCancel != null) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel Request',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating Banner for Slow Network
class NovaSlowNetworkBanner extends StatelessWidget {
  final String text;
  final String? message;

  const NovaSlowNetworkBanner({
    super.key,
    this.text = 'Network latency is high. Dispatch updates may take a few seconds to reflect.',
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveText = message ?? text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFFBEB),
      child: Row(
        children: [
          const Icon(
            Icons.network_check_rounded,
            size: 16,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              effectiveText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

