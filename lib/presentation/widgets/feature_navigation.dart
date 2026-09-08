import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../config/features.dart';
import '../config/theme.dart';
import '../models/feature_item.dart';

/// Top navigation bar for the Feature Presentation Screen with hover highlight cards
/// and light/dark theme switcher. Section 15 of docs/presentation.md.
class FeatureNavigation extends StatefulWidget {
  final FeatureItem currentFeature;
  final ValueChanged<FeatureItem> onFeatureSelect;
  final VoidCallback onBackToEcosystem;
  final bool isLightMode;
  final VoidCallback? onToggleTheme;

  const FeatureNavigation({
    super.key,
    required this.currentFeature,
    required this.onFeatureSelect,
    required this.onBackToEcosystem,
    this.isLightMode = false,
    this.onToggleTheme,
  });

  @override
  State<FeatureNavigation> createState() => _FeatureNavigationState();
}

class _FeatureNavigationState extends State<FeatureNavigation> {
  String? _hoveredFeatureId;

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLightMode;
    final hoveredFeature = _hoveredFeatureId != null
        ? PresentationFeatures.findById(_hoveredFeatureId!)
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Navigation Bar
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.94)
                : PresentationTheme.deepNavy.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: isLight
                    ? const Color(0xFFE2E8F0)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              // 1. Authoritative Brand Logo + Back Button (Section 1)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onBackToEcosystem,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFFF1F5F9)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLight
                                ? const Color(0xFFCBD5E1)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Icon(Icons.grid_view_rounded, size: 16, color: PresentationTheme.brightOrange),
                      ),
                      const SizedBox(width: 14),
                      Image.asset(
                        AppAssets.logo,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'NovaXpress',
                          style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: PresentationTheme.novaOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 2. Feature Tabs (Orders, Scaling, Structure, Payments, Remitance, Stock & Custodies)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PresentationFeatures.all.map((feature) {
                    final bool isActive = feature.id == widget.currentFeature.id;
                    final bool isHovered = feature.id == _hoveredFeatureId;

                    // Visible label: clarify "Stock & Custodies" when id is 'sock'
                    final String displayLabel = feature.id == 'sock'
                        ? 'Stock & Custodies'
                        : feature.title;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredFeatureId = feature.id),
                      onExit: (_) => setState(() {
                        if (_hoveredFeatureId == feature.id) {
                          _hoveredFeatureId = null;
                        }
                      }),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _hoveredFeatureId = null);
                          widget.onFeatureSelect(feature);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? feature.accentColor.withValues(alpha: isLight ? 0.12 : 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              bottom: BorderSide(
                                color: isActive ? PresentationTheme.brightOrange : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isActive) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: PresentationTheme.brightOrange,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                displayLabel,
                                style: PresentationTheme.labelFeatureThemed(isLight).copyWith(
                                  fontSize: 13.5,
                                  color: isActive
                                      ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                                      : (isHovered
                                          ? feature.accentColor
                                          : (isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                                  fontWeight: isActive || isHovered ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(width: 16),

              // 3. Theme Toggle Button (Light / Dark)
              if (widget.onToggleTheme != null)
                IconButton(
                  onPressed: widget.onToggleTheme,
                  tooltip: isLight ? 'Switch to Dark Mode (T)' : 'Switch to Light Mode (T)',
                  style: IconButton.styleFrom(
                    backgroundColor: isLight
                        ? const Color(0xFFF1F5F9)
                        : Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: isLight
                          ? const Color(0xFFCBD5E1)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: Icon(
                    isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 16,
                    color: isLight ? const Color(0xFF334155) : PresentationTheme.brightOrange,
                  ),
                ),

              const SizedBox(width: 10),

              // 4. Return to Ecosystem Command Center CTA
              OutlinedButton.icon(
                onPressed: widget.onBackToEcosystem,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: isLight ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
                label: Text(
                  'Ecosystem (Esc)',
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 11,
                    color: isLight ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.2),
                  ),
                  backgroundColor: isLight ? Colors.white : Colors.white.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Hover Highlight Card Dropdown Overlay
        if (hoveredFeature != null)
          Positioned(
            top: 72,
            right: 220,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoveredFeatureId = hoveredFeature.id),
              onExit: (_) => setState(() => _hoveredFeatureId = null),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.97)
                          : PresentationTheme.deepNavy.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hoveredFeature.accentColor.withValues(alpha: isLight ? 0.6 : 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.6),
                          blurRadius: isLight ? 20 : 28,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: hoveredFeature.accentColor.withValues(alpha: isLight ? 0.1 : 0.15),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category & Key Metric
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: hoveredFeature.accentColor.withValues(alpha: isLight ? 0.15 : 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hoveredFeature.category,
                                style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                  fontSize: 9,
                                  color: hoveredFeature.accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              hoveredFeature.keyMetric,
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          hoveredFeature.id == 'sock'
                              ? 'Stock Movements & Custodies'
                              : hoveredFeature.title,
                          style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Description
                        Text(
                          hoveredFeature.description,
                          style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                            fontSize: 11.5,
                            color: isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Key Benefit Pills
                        ...hoveredFeature.benefits.take(2).map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 3.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 11, color: hoveredFeature.accentColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      b,
                                      style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                                        fontSize: 10.5,
                                        color: isLight ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 8),

                        // Click to Open Hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Click to open workflow',
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 9.5,
                                color: hoveredFeature.accentColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 10, color: hoveredFeature.accentColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
