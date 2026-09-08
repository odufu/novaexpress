import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../config/theme.dart';
import '../controllers/ecosystem_controller.dart';
import '../controllers/transform_controller.dart';

/// Dedicated Central Core command center widget.
/// Section 5 of docs/presentation.md.
class CentralCore extends StatelessWidget {
  final EcosystemState state;
  final double breathingValue; // 0.0 - 1.0 continuous loop
  final Size viewportSize;
  final VoidCallback? onTap;

  const CentralCore({
    super.key,
    required this.state,
    required this.breathingValue,
    required this.viewportSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final transform = FeatureTransformController.computeCore(
      state: state,
      breathingValue: breathingValue,
      viewportSize: viewportSize,
    );

    // Responsive core diameter (larger than platforms, ~210-280px)
    final double coreDiameter = (viewportSize.shortestSide * 0.32).clamp(190.0, 290.0);

    return Positioned(
      left: transform.translationX - (coreDiameter / 2),
      top: transform.translationY - (coreDiameter / 2),
      child: Transform(
        transform: transform.transformMatrix,
        alignment: Alignment.center,
        child: Opacity(
          opacity: transform.opacity,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: coreDiameter,
              height: coreDiameter,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Ambient Radial Orange Glow (Section 5)
                  Container(
                    width: coreDiameter * 1.35,
                    height: coreDiameter * 1.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          PresentationTheme.novaOrange.withValues(alpha: transform.glowIntensity * 0.45),
                          const Color(0xFF00E5FF).withValues(alpha: transform.glowIntensity * 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // 2. Core Image Asset
                  RepaintBoundary(
                    child: Image.asset(
                      AppAssets.centralCore,
                      width: coreDiameter,
                      height: coreDiameter,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        // Semantic developer fallback if image asset is missing (Section 29)
                        return Container(
                          width: coreDiameter,
                          height: coreDiameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PresentationTheme.surface(state.isLightMode),
                            border: Border.all(color: PresentationTheme.novaOrange, width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.hub_rounded, size: 64, color: PresentationTheme.novaOrange),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
