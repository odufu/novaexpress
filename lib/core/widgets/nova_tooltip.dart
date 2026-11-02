import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// App-wide standardized modern tooltip with glassmorphic styling,
/// clean typography, and instant responsiveness for both web hover and mobile tap.
class NovaTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final String? heading;
  final Duration waitDuration;
  final Duration showDuration;
  final AxisDirection preferDirection;

  const NovaTooltip({
    super.key,
    required this.child,
    String? message,
    String? tooltip,
    this.heading,
    this.waitDuration = const Duration(milliseconds: 150),
    this.showDuration = const Duration(seconds: 4),
    this.preferDirection = AxisDirection.down,
  }) : message = message ?? tooltip ?? '';

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return child;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      waitDuration: waitDuration,
      showDuration: showDuration,
      preferBelow: preferDirection == AxisDirection.down,
      verticalOffset: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      richMessage: TextSpan(
        children: [
          if (heading != null && heading!.isNotEmpty) ...[
            TextSpan(
              text: '$heading\n',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
                height: 1.3,
              ),
            ),
          ],
          TextSpan(
            text: message,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFE2E8F0),
              height: 1.35,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A compact, elegant circular info icon with built-in [NovaTooltip].
/// Perfect for embedding in table headers, form field labels, and metric counters.
class NovaInfoIcon extends StatelessWidget {
  final String message;
  final String? heading;
  final double size;
  final Color? color;

  const NovaInfoIcon({
    super.key,
    String? message,
    String? tooltip,
    this.heading,
    this.size = 14,
    this.color,
  }) : message = message ?? tooltip ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return NovaTooltip(
      message: message,
      heading: heading,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Icon(
            Icons.info_outline_rounded,
            size: size,
            color: color ?? defaultColor,
          ),
        ),
      ),
    );
  }
}
