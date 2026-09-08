import 'dart:math' as math;
import 'package:flutter/material.dart';

class AmbientParticle {
  final double xRatio; // 0.0 to 1.0
  final double yRatio; // 0.0 to 1.0
  final double speed;
  final double radius;
  final double opacity;
  final bool isOrange;
  final double phase;

  const AmbientParticle({
    required this.xRatio,
    required this.yRatio,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.isOrange,
    required this.phase,
  });
}

/// Paints ambient floating particles with depth-of-field simulation
/// Supports both dark and light modes.
/// Section 2 of docs/presentation.md.
class ParticlePainter extends CustomPainter {
  final double animationValue; // 0.0 - 1.0 continuous loop
  final List<AmbientParticle> particles;
  final bool isLightMode;

  ParticlePainter({
    required this.animationValue,
    required this.particles,
    this.isLightMode = false,
  });

  static List<AmbientParticle> generate(int count) {
    final random = math.Random(42); // Deterministic seed
    return List.generate(count, (i) {
      return AmbientParticle(
        xRatio: random.nextDouble(),
        yRatio: random.nextDouble(),
        speed: 0.02 + random.nextDouble() * 0.05,
        radius: 1.0 + random.nextDouble() * 2.2,
        opacity: 0.15 + random.nextDouble() * 0.45,
        isOrange: random.nextDouble() > 0.4,
        phase: random.nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()..style = PaintingStyle.fill;
    final cyanPaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final double progress = (animationValue * p.speed + p.phase) % 1.0;
      final double x = (p.xRatio * size.width) + math.sin(progress * 2 * math.pi) * 15.0;
      final double y = (size.height - (progress * size.height)) % size.height;

      final double pulse = 0.6 + (math.sin(progress * 2 * math.pi) * 0.4);
      final double alpha = (p.opacity * pulse).clamp(0.0, 1.0);

      if (p.isOrange) {
        orangePaint.color = (isLightMode ? const Color(0xFFEA580C) : const Color(0xFFFF7A00))
            .withValues(alpha: isLightMode ? alpha * 0.85 : alpha);
        canvas.drawCircle(Offset(x, y), p.radius, orangePaint);
      } else {
        cyanPaint.color = (isLightMode ? const Color(0xFF0284C7) : const Color(0xFF00E5FF))
            .withValues(alpha: isLightMode ? alpha * 0.75 : alpha * 0.8);
        canvas.drawCircle(Offset(x, y), p.radius * 0.8, cyanPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isLightMode != isLightMode;
  }
}
