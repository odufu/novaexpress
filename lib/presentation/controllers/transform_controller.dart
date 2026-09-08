import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/spatial_node.dart';
import 'ecosystem_controller.dart';

/// Calculated transformation values for a spatial element in 3D perspective space.
class PlatformTransformValues {
  final double scale;
  final double translationX;
  final double translationY;
  final double translationZ;
  final double rotationX;
  final double rotationY;
  final double opacity;
  final double blurAmount;
  final double glowIntensity;
  final Matrix4 transformMatrix;

  const PlatformTransformValues({
    required this.scale,
    required this.translationX,
    required this.translationY,
    required this.translationZ,
    required this.rotationX,
    required this.rotationY,
    required this.opacity,
    required this.blurAmount,
    required this.glowIntensity,
    required this.transformMatrix,
  });
}

/// Centralized 3D transformation controller computing matrix, perspective,
/// depth of field, blur, and lighting states.
/// Section 12 & 13 of docs/presentation.md.
class FeatureTransformController {
  FeatureTransformController._();

  static PlatformTransformValues compute({
    required SpatialNode node,
    required EcosystemState state,
    required double floatAnimationValue, // 0.0 - 1.0 continuous sine
    required Size viewportSize,
  }) {
    final String id = node.featureId;
    final bool isHovered = state.hoveredFeatureId == id;
    final bool isAnyHovered = state.hoveredFeatureId != null;
    final bool isSelected = state.selectedFeatureId == id;
    final bool isTransitioning = state.isTransitioning;
    final double tProgress = state.transitionProgress;

    // 1. Subtle continuous floating offset (vertical sine wave with phase offset)
    final double floatOffset = math.sin((floatAnimationValue * 2 * math.pi) + node.floatPhase) * 6.0;

    // 2. Base 2D position in viewport
    final Offset basePos = node.resolvePosition(viewportSize);

    // 3. Determine depth scale & translation Z
    double targetScale = 1.0;
    double depthZ = node.depthOffsetZ;
    double opacity = 1.0;
    double blur = 0.0;
    double glow = 0.0;
    double rotX = 0.0;
    double rotY = 0.0;

    if (isTransitioning) {
      if (isSelected) {
        // Phase 1 to 4: Selected platform magnifies, surges toward camera and centers
        targetScale = 1.0 + (tProgress * 1.8);
        depthZ = 20.0 + (tProgress * 80.0);
        glow = 0.4 + (tProgress * 0.6);
        opacity = 1.0 - (tProgress * 0.4).clamp(0.0, 1.0);
      } else {
        // Other features recede into background blur and fade out
        targetScale = 1.0 - (tProgress * 0.45);
        depthZ = -20.0 - (tProgress * 60.0);
        opacity = (1.0 - (tProgress * 1.5)).clamp(0.0, 1.0);
        blur = tProgress * 8.0;
      }
    } else if (isHovered) {
      // Hovered platform surges forward, expands, glows vividly
      targetScale = PresentationConstants.hoveredDepthScale;
      depthZ = PresentationConstants.maxHoverDepthZ;
      glow = 1.0;
      opacity = 1.0;
      blur = 0.0;
      // Subtle tilt based on position relative to center
      rotX = -node.normalizedY * 0.08;
      rotY = node.normalizedX * 0.08;
    } else if (isAnyHovered) {
      // Surrounding platforms recede, shrink slightly, soften
      targetScale = PresentationConstants.unhoveredDepthScale;
      depthZ = -10.0;
      glow = 0.0;
      opacity = 0.65;
      blur = 1.5;
    } else {
      // Resting state
      targetScale = 1.0;
      depthZ = node.depthOffsetZ;
      glow = 0.18;
      opacity = 0.95;
      blur = 0.0;
    }

    // 4. Build 3D Matrix with perspective projection
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, PresentationConstants.perspectiveFactor) // Perspective
      ..translate(0.0, floatOffset, depthZ)
      ..rotateX(rotX)
      ..rotateY(rotY)
      ..scale(targetScale, targetScale, 1.0);

    return PlatformTransformValues(
      scale: targetScale,
      translationX: basePos.dx,
      translationY: basePos.dy + floatOffset,
      translationZ: depthZ,
      rotationX: rotX,
      rotationY: rotY,
      opacity: opacity,
      blurAmount: blur,
      glowIntensity: glow,
      transformMatrix: matrix,
    );
  }

  /// Calculates transformation values specifically for the Central Command Core (Section 5)
  static PlatformTransformValues computeCore({
    required EcosystemState state,
    required double breathingValue, // 0.0 - 1.0 continuous loop
    required Size viewportSize,
  }) {
    final bool isAnyHovered = state.hoveredFeatureId != null;
    final bool isTransitioning = state.isTransitioning;
    final double tProgress = state.transitionProgress;

    // Continuous breathing scale (subtle 1.0 -> 1.04 expansion)
    final double breathingScale = 1.0 + (math.sin(breathingValue * 2 * math.pi) * 0.03);
    final double floatY = math.cos(breathingValue * 2 * math.pi) * 4.0;

    double scale = breathingScale;
    double depthZ = 0.0;
    double opacity = 1.0;
    double blur = 0.0;
    double glow = 0.35 + (math.sin(breathingValue * 2 * math.pi) * 0.15);

    if (isTransitioning) {
      // Recedes smoothly into deep space
      scale = breathingScale * (1.0 - (tProgress * 0.4));
      depthZ = -50.0 * tProgress;
      opacity = (1.0 - (tProgress * 1.6)).clamp(0.0, 1.0);
      blur = tProgress * 6.0;
    } else if (isAnyHovered) {
      // Softens slightly so hovered platform dominates hierarchy
      scale = breathingScale * 0.96;
      depthZ = -12.0;
      opacity = 0.72;
      blur = 1.0;
    }

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, PresentationConstants.perspectiveFactor)
      ..translate(0.0, floatY, depthZ)
      ..scale(scale, scale, 1.0);

    return PlatformTransformValues(
      scale: scale,
      translationX: viewportSize.width / 2,
      translationY: (viewportSize.height / 2) + floatY,
      translationZ: depthZ,
      rotationX: 0.0,
      rotationY: 0.0,
      opacity: opacity,
      blurAmount: blur,
      glowIntensity: glow,
      transformMatrix: matrix,
    );
  }
}
