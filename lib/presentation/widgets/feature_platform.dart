import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../config/theme.dart';
import '../controllers/ecosystem_controller.dart';
import '../controllers/transform_controller.dart';
import '../models/feature_item.dart';
import '../models/spatial_node.dart';

/// Reusable 3D Feature Platform component driven by configuration.
/// Section 6 of docs/presentation.md.
class FeaturePlatform extends StatelessWidget {
  final FeatureItem feature;
  final SpatialNode node;
  final EcosystemState state;
  final double floatAnimationValue;
  final Size viewportSize;
  final ValueChanged<String?> onHoverChanged;
  final ValueChanged<String> onSelect;

  const FeaturePlatform({
    super.key,
    required this.feature,
    required this.node,
    required this.state,
    required this.floatAnimationValue,
    required this.viewportSize,
    required this.onHoverChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final String id = feature.id;
    final bool isHovered = state.hoveredFeatureId == id;
    final bool isSelected = state.selectedFeatureId == id;

    final transform = FeatureTransformController.compute(
      node: node,
      state: state,
      floatAnimationValue: floatAnimationValue,
      viewportSize: viewportSize,
    );

    // Responsive platform diameter
    final double platformWidth = (viewportSize.shortestSide * 0.22).clamp(140.0, 200.0);
    final double platformHeight = platformWidth * 0.92;

    return Positioned(
      left: transform.translationX - (platformWidth / 2),
      top: transform.translationY - (platformHeight / 2),
      child: Transform(
        transform: transform.transformMatrix,
        alignment: Alignment.center,
        child: Opacity(
          opacity: transform.opacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: transform.blurAmount,
              sigmaY: transform.blurAmount,
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHoverChanged(id),
              onExit: (_) => onHoverChanged(null),
              child: GestureDetector(
                onTap: () => onSelect(id),
                child: SizedBox(
                  width: platformWidth,
                  height: platformHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Ambient Glow Underneath Platform (Active/Hovered state)
                      if (transform.glowIntensity > 0.0)
                        Positioned(
                          bottom: -15,
                          child: Opacity(
                            opacity: transform.glowIntensity.clamp(0.0, 1.0),
                            child: Image.asset(
                              AppAssets.hoverGlow,
                              width: platformWidth * 1.35,
                              height: platformHeight * 0.65,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),

                      // 2. 3D Platform Base Image
                      Positioned(
                        bottom: 0,
                        child: RepaintBoundary(
                          child: Image.asset(
                            AppAssets.featurePlatform,
                            width: platformWidth,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              // Elegant fallback if base asset is missing
                              return Container(
                                width: platformWidth,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: PresentationTheme.primaryNavy,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: PresentationTheme.novaOrange, width: 1.5),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 3. Floating 3D Feature Icon (Rises slightly on hover - Section 10)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        top: isHovered ? 6 : 16,
                        child: RepaintBoundary(
                          child: _buildFeatureIcon(platformWidth * 0.58),
                        ),
                      ),

                      // 4. Feature Title Label (Underneath platform with glow when active)
                      Positioned(
                        bottom: -4,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: PresentationTheme.labelFeatureThemed(state.isLightMode).copyWith(
                            color: state.isLightMode
                                ? (isHovered ? PresentationTheme.novaOrange : const Color(0xFF0F172A))
                                : (isHovered ? Colors.white : const Color(0xFFE2E8F0)),
                            fontWeight: isHovered ? FontWeight.w800 : FontWeight.w700,
                            shadows: state.isLightMode
                                ? [
                                    Shadow(
                                      color: isHovered ? feature.accentColor.withValues(alpha: 0.5) : Colors.white,
                                      blurRadius: isHovered ? 8 : 3,
                                    ),
                                  ]
                                : isHovered
                                    ? [
                                        Shadow(
                                          color: feature.accentColor.withValues(alpha: 0.9),
                                          blurRadius: 14,
                                        ),
                                        const Shadow(
                                          color: Colors.black,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [
                                        const Shadow(
                                          color: Colors.black,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                          ),
                          child: Text(
                            feature.id == 'sock' ? 'Stock & Custodies' : feature.title,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      // 5. Active Selection Indicator Ring
                      if (isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: PresentationTheme.brightOrange, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: PresentationTheme.brightOrange.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 3D feature icon, or displays an explicit developer placeholder
  /// if the raster asset has not yet been supplied (Section 8 & 29).
  Widget _buildFeatureIcon(double size) {
    if (AppAssets.isAvailable(feature.iconAsset)) {
      return Image.asset(
        feature.iconAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(size),
      );
    }
    return _buildPlaceholderIcon(size);
  }

  Widget _buildPlaceholderIcon(double size) {
    // Per Section 8 & 29: clearly indicate missing asset with exact expected filename
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PresentationTheme.deepNavy.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: feature.accentColor.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: feature.accentColor.withValues(alpha: 0.25),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(feature.fallbackIcon, size: size * 0.44, color: feature.accentColor),
          const SizedBox(height: 2),
          Text(
            'ASSET PENDING',
            style: PresentationTheme.codeMono.copyWith(fontSize: 7.5, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
