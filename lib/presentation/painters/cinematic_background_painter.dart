import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Paints cinematic tech logistics background grid, ambient radial lighting,
/// and perspective guidelines. Supports both dark and light modes.
/// Section 2 & 3 of docs/presentation.md.
class CinematicBackgroundPainter extends CustomPainter {
  final double transitionProgress;
  final bool isLightMode;

  CinematicBackgroundPainter({
    this.transitionProgress = 0.0,
    this.isLightMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 1. Base gradient fill
    final Paint bgPaint = Paint();
    if (isLightMode) {
      bgPaint.shader = const RadialGradient(
        center: Alignment(0.0, -0.1),
        radius: 1.25,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF1F5F9),
          PresentationTheme.lightBackground,
          Color(0xFFE2E8F0),
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    } else {
      bgPaint.shader = const RadialGradient(
        center: Alignment(0.0, 0.0),
        radius: 1.15,
        colors: [
          Color(0xFF09224E),
          PresentationTheme.primaryNavy,
          PresentationTheme.deepNavy,
          PresentationTheme.backgroundBlack,
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    }
    canvas.drawRect(rect, bgPaint);

    // 2. Subtle central amber/orange ambient flare
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          PresentationTheme.novaOrange.withValues(
            alpha: (isLightMode ? 0.07 : 0.12) * (1.0 - transitionProgress * 0.5),
          ),
          const Color(0x00FF7A00),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    // 3. Subtle perspective technical grid lines
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = isLightMode
          ? const Color(0xFF0F172A).withValues(alpha: 0.045)
          : const Color(0xFF00E5FF).withValues(alpha: 0.04);

    const double gridSize = 64.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 4. Subtle crosshair and technical grid corner coordinates
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isLightMode
          ? PresentationTheme.novaOrange.withValues(alpha: 0.3)
          : const Color(0xFF00E5FF).withValues(alpha: 0.15);

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    // Tiny center coordinate tick marks
    canvas.drawLine(Offset(cx - 16, cy), Offset(cx - 8, cy), accentPaint);
    canvas.drawLine(Offset(cx + 8, cy), Offset(cx + 16, cy), accentPaint);
    canvas.drawLine(Offset(cx, cy - 16), Offset(cx, cy - 8), accentPaint);
    canvas.drawLine(Offset(cx, cy + 8), Offset(cx, cy + 16), accentPaint);
  }

  @override
  bool shouldRepaint(covariant CinematicBackgroundPainter oldDelegate) {
    return oldDelegate.transitionProgress != transitionProgress ||
        oldDelegate.isLightMode != isLightMode;
  }
}
