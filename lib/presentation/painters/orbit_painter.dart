import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Paints glowing orbital connection rings and photon energy lines connecting
/// the Central Core to the 6 feature platforms. Supports both dark and light modes.
/// Section 2 and Section 10 of docs/presentation.md.
class OrbitPainter extends CustomPainter {
  final Map<String, Offset> platformCenters;
  final Offset coreCenter;
  final String? hoveredFeatureId;
  final String? selectedFeatureId;
  final double pulseValue; // 0.0 - 1.0 continuous animation for energy pulse
  final double transitionProgress;
  final bool isLightMode;

  OrbitPainter({
    required this.platformCenters,
    required this.coreCenter,
    required this.hoveredFeatureId,
    required this.selectedFeatureId,
    required this.pulseValue,
    required this.transitionProgress,
    this.isLightMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double overallOpacity = (1.0 - (transitionProgress * 1.5)).clamp(0.0, 1.0);
    if (overallOpacity <= 0.0) return;

    // 1. Draw subtle ambient concentric orbital rings around core
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isLightMode
          ? const Color(0xFF0F172A).withValues(alpha: 0.1 * overallOpacity)
          : const Color(0xFF00E5FF).withValues(alpha: 0.08 * overallOpacity);

    final double maxRadius = math.min(size.width, size.height) * 0.38;
    canvas.drawCircle(coreCenter, maxRadius * 0.55, ringPaint);
    canvas.drawCircle(coreCenter, maxRadius * 0.85, ringPaint);
    canvas.drawCircle(coreCenter, maxRadius * 1.15, ringPaint);

    // 2. Draw connector lines from Central Core to each Feature Platform
    for (final entry in platformCenters.entries) {
      final String featureId = entry.key;
      final Offset target = entry.value;
      final bool isHovered = featureId == hoveredFeatureId;
      final bool isSelected = featureId == selectedFeatureId;

      final double lineOpacity = (isHovered || isSelected)
          ? (isLightMode ? 0.95 : 0.85) * overallOpacity
          : (hoveredFeatureId != null
              ? (isLightMode ? 0.1 : 0.06) * overallOpacity
              : (isLightMode ? 0.3 : 0.22) * overallOpacity);
      final double lineWidth = (isHovered || isSelected) ? 2.5 : 1.2;

      // Gradient path from core to platform
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomRight,
          colors: [
            PresentationTheme.novaOrange.withValues(alpha: lineOpacity * 0.95),
            ((isHovered || isSelected)
                    ? PresentationTheme.brightOrange
                    : (isLightMode ? const Color(0xFF0284C7) : const Color(0xFF00E5FF)))
                .withValues(alpha: lineOpacity * 0.75),
          ],
        ).createShader(Rect.fromPoints(coreCenter, target));

      // Draw curved spline to give a spatial orbital feel
      final Path path = Path();
      path.moveTo(coreCenter.dx, coreCenter.dy);

      final double midX = (coreCenter.dx + target.dx) / 2;
      final double midY = (coreCenter.dy + target.dy) / 2;
      // Slight outward curve
      const double curveFactor = 15.0;
      final double normalX = -(target.dy - coreCenter.dy) / size.height * curveFactor;
      final double normalY = (target.dx - coreCenter.dx) / size.width * curveFactor;

      final Offset controlPoint = Offset(midX + normalX, midY + normalY);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, target.dx, target.dy);

      canvas.drawPath(path, linePaint);

      // 3. Draw energy pulse photon traveling along the connection line when hovered
      if (isHovered || pulseValue > 0.0) {
        final double t = (pulseValue + (featureId.hashCode % 100) / 100.0) % 1.0;
        // Evaluate quadratic bezier position at t
        final double u = 1.0 - t;
        final double px = u * u * coreCenter.dx + 2 * u * t * controlPoint.dx + t * t * target.dx;
        final double py = u * u * coreCenter.dy + 2 * u * t * controlPoint.dy + t * t * target.dy;

        final photonGlow = Paint()
          ..style = PaintingStyle.fill
          ..color = PresentationTheme.brightOrange.withValues(alpha: (isHovered ? 0.9 : 0.4) * overallOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

        final photonCore = Paint()
          ..style = PaintingStyle.fill
          ..color = (isLightMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: overallOpacity);

        canvas.drawCircle(Offset(px, py), isHovered ? 5.0 : 3.0, photonGlow);
        canvas.drawCircle(Offset(px, py), isHovered ? 2.5 : 1.5, photonCore);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) {
    return oldDelegate.hoveredFeatureId != hoveredFeatureId ||
        oldDelegate.selectedFeatureId != selectedFeatureId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.transitionProgress != transitionProgress ||
        oldDelegate.isLightMode != isLightMode;
  }
}
