import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/presentation/pages/cash_page.dart';
import '../../../orders/presentation/pages/orders_list_page.dart';
import '../../../stock/presentation/pages/stock_page.dart';
import '../../../users/presentation/pages/user_profile_page.dart';
import 'pda_home_page.dart';

class MainBottomNavShell extends ConsumerStatefulWidget {
  const MainBottomNavShell({super.key});

  @override
  ConsumerState<MainBottomNavShell> createState() => _MainBottomNavShellState();
}

class _MainBottomNavShellState extends ConsumerState<MainBottomNavShell>
    with SingleTickerProviderStateMixin {
  static const List<Widget> _pages = [
    PdaHomePage(),
    StockPage(),
    OrdersListPage(),
    CashPage(),
    UserProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // Responsive theme styling for the curved floating bar
    final barBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final borderColor = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.8)
        : const Color(0xFF334155).withValues(alpha: 0.4);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : const Color(0xFF0F172A).withValues(alpha: 0.25);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // 1. Custom Curved Hump Background Painter
            CustomPaint(
              size: const Size(double.infinity, 64),
              painter: _CurvedHumpPainter(
                color: barBgColor,
                borderColor: borderColor,
                shadowColor: shadowColor,
              ),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      // Tab 0: Home
                      Expanded(
                        child: _AnimatedNavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          isSelected: currentIndex == 0,
                          onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
                        ),
                      ),
                      // Tab 1: Inventory
                      Expanded(
                        child: _AnimatedNavItem(
                          icon: Icons.inventory_2_rounded,
                          label: 'Inventory',
                          isSelected: currentIndex == 1,
                          onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 1,
                        ),
                      ),
                      // Spacer for the center raised Deliveries button
                      const SizedBox(width: 72),
                      // Tab 3: Remittance
                      Expanded(
                        child: _AnimatedNavItem(
                          icon: Icons.payments_rounded,
                          label: 'Remittance',
                          isSelected: currentIndex == 3,
                          onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 3,
                        ),
                      ),
                      // Tab 4: More
                      Expanded(
                        child: _AnimatedNavItem(
                          icon: Icons.person_rounded,
                          label: 'More',
                          isSelected: currentIndex == 4,
                          onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Elevated Center Convex Deliveries Button with Animated Glow
            Positioned(
              top: 0,
              child: _CenterDeliveriesHumpButton(
                isSelected: currentIndex == 2,
                onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterDeliveriesHumpButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterDeliveriesHumpButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.orange;
    const accentColor = Color(0xFFFB923C);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: isSelected ? 52 : 46,
            height: isSelected ? 52 : 46,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : const Color(0xFF64748B).withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 0.95,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  size: isSelected ? 26 : 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? accentColor : const Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
            child: const Text('Deliveries'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.orange;
    const inactiveColor = Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Glowing Indicator Pill above icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isSelected ? 16 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),

            // Animated Icon with Scale Effect
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),

            // Animated Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvedHumpPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  _CurvedHumpPainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = _buildPath(size);

    // Draw ambient shadow
    canvas.drawShadow(path, shadowColor, 10, true);

    // Draw main background
    canvas.drawPath(path, paint);

    // Draw clean border
    canvas.drawPath(path, borderPaint);
  }

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    const r = 24.0; // corner radius
    final cx = w / 2;
    const humpWidth = 84.0;
    const humpHeight = 18.0; // height of convex bulge

    final path = Path();

    // Start at top-left after corner radius
    path.moveTo(r, 0);

    // Flat line towards center hump
    path.lineTo(cx - humpWidth / 2, 0);

    // Smooth organic cubic bezier curve UP into center hump
    path.cubicTo(
      cx - humpWidth / 3.2, 0,
      cx - humpWidth / 3.5, -humpHeight,
      cx, -humpHeight,
    );

    // Smooth organic cubic bezier curve DOWN from center hump
    path.cubicTo(
      cx + humpWidth / 3.5, -humpHeight,
      cx + humpWidth / 3.2, 0,
      cx + humpWidth / 2, 0,
    );

    // Flat line to top-right corner
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: const Radius.circular(r));

    // Right edge
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));

    // Bottom edge
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));

    // Left edge
    path.lineTo(0, r);
    path.arcToPoint(const Offset(r, 0), radius: const Radius.circular(r));

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _CurvedHumpPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
