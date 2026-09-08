import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../config/theme.dart';
import '../models/feature_item.dart';

/// 3D Presentation Hero asset showcase widget with staggered entrance animations.
/// Section 16 & 17 of docs/presentation.md.
class HeroScene extends StatelessWidget {
  final FeatureItem feature;
  final Animation<double> entranceAnimation;

  const HeroScene({
    super.key,
    required this.feature,
    required this.entranceAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entranceAnimation,
      builder: (context, child) {
        final double curveVal = Curves.easeOutCubic.transform(entranceAnimation.value);

        return Transform.translate(
          offset: Offset((1.0 - curveVal) * 40.0, (1.0 - curveVal) * 20.0),
          child: Transform.scale(
            scale: 0.88 + (curveVal * 0.12),
            child: Opacity(
              opacity: curveVal.clamp(0.0, 1.0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient radial color halo behind hero
                    Container(
                      width: 440,
                      height: 440,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            feature.accentColor.withValues(alpha: 0.25),
                            PresentationTheme.primaryNavy.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),

                    // Hero Asset or Semantic Placeholder (Section 29)
                    if (AppAssets.isAvailable(feature.heroAsset))
                      Image.asset(
                        feature.heroAsset,
                        width: 520,
                        height: 380,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildHeroPlaceholder(),
                      )
                    else
                      _buildHeroPlaceholder(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// High-fidelity developer placeholder clearly identifying the missing semantic asset (Section 8 & 29)
  Widget _buildHeroPlaceholder() {
    return Container(
      width: 460,
      height: 320,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: PresentationTheme.deepNavy.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feature.accentColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: feature.accentColor.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: feature.accentColor.withValues(alpha: 0.15),
              border: Border.all(color: feature.accentColor.withValues(alpha: 0.4)),
            ),
            child: Icon(feature.fallbackIcon, size: 48, color: feature.accentColor),
          ),
          const SizedBox(height: 12),

          Text(
            '3D HERO ASSET PENDING',
            style: PresentationTheme.titleMedium.copyWith(fontSize: 16, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              feature.heroAsset,
              style: PresentationTheme.codeMono.copyWith(fontSize: 11, color: const Color(0xFFE2E8F0)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Drop raster file into /docs/presentation_elements to load automatically.',
            style: PresentationTheme.bodySmall.copyWith(fontSize: 11, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
