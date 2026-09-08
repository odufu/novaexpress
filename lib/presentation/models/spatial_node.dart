import 'package:flutter/material.dart';

/// Represents the spatial layout node of a feature platform in responsive 3D space.
/// Section 4 of docs/presentation.md.
class SpatialNode {
  final String featureId;
  final double normalizedX; // -1.0 (left) to 1.0 (right)
  final double normalizedY; // -1.0 (top) to 1.0 (bottom)
  final double depthOffsetZ; // Initial depth perception offset
  final double floatPhase; // Phase offset for asynchronous floating animation

  const SpatialNode({
    required this.featureId,
    required this.normalizedX,
    required this.normalizedY,
    this.depthOffsetZ = 0.0,
    this.floatPhase = 0.0,
  });

  /// Canonical layout coordinates corresponding to Section 4 diagram:
  ///                 ORDERS
  ///         SCALING         STRUCTURE
  ///                  CORE
  ///         PAYMENTS       REMITANCE
  ///                   SOCK
  static const List<SpatialNode> defaultNodes = [
    SpatialNode(
      featureId: 'orders',
      normalizedX: 0.0,
      normalizedY: -0.80,
      depthOffsetZ: 5.0,
      floatPhase: 0.0,
    ),
    SpatialNode(
      featureId: 'scaling',
      normalizedX: -0.66,
      normalizedY: -0.38,
      depthOffsetZ: 2.0,
      floatPhase: 1.2,
    ),
    SpatialNode(
      featureId: 'structure',
      normalizedX: 0.66,
      normalizedY: -0.38,
      depthOffsetZ: 2.0,
      floatPhase: 2.4,
    ),
    SpatialNode(
      featureId: 'payments',
      normalizedX: -0.66,
      normalizedY: 0.38,
      depthOffsetZ: 8.0,
      floatPhase: 3.6,
    ),
    SpatialNode(
      featureId: 'remitance',
      normalizedX: 0.66,
      normalizedY: 0.38,
      depthOffsetZ: 8.0,
      floatPhase: 4.8,
    ),
    SpatialNode(
      featureId: 'sock',
      normalizedX: 0.0,
      normalizedY: 0.80,
      depthOffsetZ: 12.0,
      floatPhase: 5.5,
    ),
  ];

  /// Resolves absolute center position within a given viewport size
  Offset resolvePosition(Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Responsive radii that adapt to aspect ratios and preserve visual balance
    final double radiusX = (size.width * 0.36).clamp(160.0, 520.0);
    final double radiusY = (size.height * 0.36).clamp(140.0, 360.0);

    return Offset(
      centerX + normalizedX * radiusX,
      centerY + normalizedY * radiusY,
    );
  }
}
