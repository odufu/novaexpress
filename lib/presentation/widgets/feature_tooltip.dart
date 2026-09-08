import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/feature_item.dart';

/// Native Glassmorphic Hover Card HUD for feature inspection.
/// Supports both dark and light modes.
/// Section 11 of docs/presentation.md.
class FeatureTooltip extends StatelessWidget {
  final FeatureItem feature;
  final Offset platformCenter;
  final Size viewportSize;
  final VoidCallback? onExploreTap;
  final bool isLightMode;

  const FeatureTooltip({
    super.key,
    required this.feature,
    required this.platformCenter,
    required this.viewportSize,
    this.onExploreTap,
    this.isLightMode = false,
  });

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 320.0;
    const double cardEstimatedHeight = 220.0;

    // Dynamically calculate tooltip offset to prevent viewport edge overflow
    double left = platformCenter.dx - (cardWidth / 2);
    // If platform is in upper half of screen, place tooltip below; if in lower half, place above
    final bool placeBelow = platformCenter.dy < viewportSize.height * 0.52;
    double top = placeBelow ? platformCenter.dy + 85.0 : platformCenter.dy - cardEstimatedHeight - 75.0;

    // Clamp within viewport margins
    left = left.clamp(16.0, viewportSize.width - cardWidth - 16.0);
    top = top.clamp(70.0, viewportSize.height - cardEstimatedHeight - 20.0);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        ignoring: false,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0.0, (1.0 - val) * (placeBelow ? -12.0 : 12.0)),
              child: Transform.scale(
                scale: 0.92 + (val * 0.08),
                alignment: placeBelow ? Alignment.topCenter : Alignment.bottomCenter,
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isLightMode
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFF8FAFC),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PresentationTheme.primaryNavy.withValues(alpha: 0.85),
                            PresentationTheme.deepNavy.withValues(alpha: 0.92),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: feature.accentColor.withValues(alpha: isLightMode ? 0.55 : 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isLightMode
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: feature.accentColor.withValues(alpha: isLightMode ? 0.12 : 0.15),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Metric Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: feature.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: feature.accentColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              feature.category,
                              style: PresentationTheme.codeMonoThemed(isLightMode).copyWith(
                                fontSize: 9,
                                color: feature.accentColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              feature.keyMetric,
                              style: PresentationTheme.codeMonoThemed(isLightMode).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLightMode ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Feature Title
                    Text(
                      feature.id == 'sock'
                          ? 'Stock Movements & Custodies'
                          : feature.title,
                      style: PresentationTheme.titleMediumThemed(isLightMode).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle / Description
                    Text(
                      feature.description,
                      style: PresentationTheme.bodyMediumThemed(isLightMode).copyWith(
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Key Benefit Chips (first 2)
                    ...feature.benefits.take(2).map((benefit) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: feature.accentColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                benefit,
                                style: PresentationTheme.bodySmallThemed(isLightMode).copyWith(
                                  fontSize: 11,
                                  color: isLightMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),

                    // Interactive Hint / Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Click to enter showcase',
                            style: PresentationTheme.bodySmallThemed(isLightMode).copyWith(
                              fontSize: 10.5,
                              color: isLightMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'OPEN',
                              style: PresentationTheme.codeMonoThemed(isLightMode).copyWith(
                                fontSize: 11,
                                color: feature.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12, color: feature.accentColor),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
