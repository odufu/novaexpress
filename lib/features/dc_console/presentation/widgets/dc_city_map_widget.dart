import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/dc_fleet_driver.dart';

class DCCityMapWidget extends StatelessWidget {
  final List<DCFleetDriver> drivers;
  final double onScheduleRate;
  final double idleCapacityRate;
  final Function(DCFleetDriver driver)? onDriverSelected;

  const DCCityMapWidget({
    super.key,
    required this.drivers,
    this.onScheduleRate = 88.0,
    this.idleCapacityRate = 12.0,
    this.onDriverSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Custom Canvas Map Background
          CustomPaint(
            size: Size.infinite,
            painter: _CityMapPainter(isDark: isDark),
          ),

          // Live GPS Rider Pins
          ..._buildDriverPins(context),

          // Top-Left Floating Badge: LIVE ACTIVE UNITS
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE: ${drivers.where((d) => d.isActive).length * 35 + 2} Active Units',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom-Left Floating Card: NETWORK PULSE
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B192C).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E3A8A), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NETWORK PULSE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ON SCHEDULE',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${onScheduleRate.toInt()}%',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: onScheduleRate / 100.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFF1E293B),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IDLE CAPACITY',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${idleCapacityRate.toInt()}%',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: idleCapacityRate / 100.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFF1E293B),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDriverPins(BuildContext context) {
    // Relative mock positions on city canvas
    final pinOffsets = [
      const Offset(0.48, 0.35), // Central Wuse
      const Offset(0.72, 0.45), // Maitama
      const Offset(0.32, 0.60), // Garki
      const Offset(0.60, 0.70), // Asokoro
      const Offset(0.40, 0.25), // Utako
    ];

    List<Widget> pinWidgets = [];
    for (int i = 0; i < drivers.length && i < pinOffsets.length; i++) {
      final driver = drivers[i];
      final offset = pinOffsets[i];
      Color pinColor = const Color(0xFF10B981);
      IconData pinIcon = Icons.local_shipping_rounded;

      if (driver.isDelayed) {
        pinColor = const Color(0xFFEF4444);
        pinIcon = Icons.warning_rounded;
      } else if (driver.isAtRest) {
        pinColor = const Color(0xFF0B192C);
        pinIcon = Icons.directions_boat_rounded;
      }

      pinWidgets.add(
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment(
              (offset.dx * 2) - 1,
              (offset.dy * 2) - 1,
            ),
            child: GestureDetector(
              onTap: () => onDriverSelected?.call(driver),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: pinColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: pinColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(pinIcon, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return pinWidgets;
  }
}

class _CityMapPainter extends CustomPainter {
  final bool isDark;

  _CityMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F1A2A) : const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final zonePaint = Paint()
      ..color = isDark ? const Color(0xFFD97706).withOpacity(0.35) : const Color(0xFFFDBA74).withOpacity(0.75)
      ..style = PaintingStyle.fill;

    // Draw stylized metro landmass
    final center = Offset(size.width * 0.52, size.height * 0.48);
    final radius = size.height * 0.40;

    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, zonePaint);

    // Draw arterial network lines
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final roadPaintMinor = Paint()
      ..color = isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Rings
    canvas.drawCircle(center, radius * 0.3, roadPaint);
    canvas.drawCircle(center, radius * 0.6, roadPaintMinor);
    canvas.drawCircle(center, radius * 0.85, roadPaint);

    // Radials
    for (int i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final start = center;
      final end = Offset(
        center.dx + radius * 1.1 * 1.2 * (angle == 0 ? 1 : (angle == 3.14159 ? -1 : 0.7)),
        center.dy + radius * 1.1 * 1.2 * (angle == 1.57079 ? 1 : (angle == 4.71238 ? -1 : 0.7)),
      );
      canvas.drawLine(start, end, roadPaintMinor);
    }
  }

  @override
  bool shouldRepaint(covariant _CityMapPainter oldDelegate) => oldDelegate.isDark != isDark;
}
