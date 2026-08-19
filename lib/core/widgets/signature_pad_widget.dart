import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SignaturePadWidget extends StatefulWidget {
  final ValueChanged<bool>? onSignatureChanged;
  final VoidCallback? onClear;
  final double height;

  const SignaturePadWidget({
    super.key,
    this.onSignatureChanged,
    this.onClear,
    this.height = 180,
  });

  @override
  State<SignaturePadWidget> createState() => SignaturePadWidgetState();
}

class SignaturePadWidgetState extends State<SignaturePadWidget> {
  final List<Offset?> _points = [];
  bool _hasSignature = false;

  bool get hasSignature => _hasSignature;

  void clear() {
    setState(() {
      _points.clear();
      _hasSignature = false;
    });
    widget.onSignatureChanged?.call(false);
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasSignature
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: _hasSignature ? 1.8 : 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // Baseline guide line
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 40,
                  child: Container(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 22,
                  child: Text(
                    'Sign on the line above',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                // Interactive Gesture Drawing Canvas
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      final renderBox = context.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        _points.add(details.localPosition);
                        _hasSignature = true;
                      }
                    });
                    widget.onSignatureChanged?.call(true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      points: _points,
                      strokeColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (!_hasSignature)
                  Center(
                    child: IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.draw_outlined,
                            size: 28,
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Customer / Receiver Digital Signature',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _hasSignature ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: _hasSignature ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  _hasSignature ? 'Signature Captured' : 'Touch canvas to draw',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: _hasSignature ? FontWeight.bold : FontWeight.normal,
                    color: _hasSignature ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (_hasSignature)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: clear,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFEF4444)),
                label: Text(
                  'Clear Signature',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;

  _SignaturePainter({required this.points, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
