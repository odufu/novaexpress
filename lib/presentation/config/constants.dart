import 'package:flutter/animation.dart';

/// Animation timings, curves, and depth factors for the presentation
class PresentationConstants {
  PresentationConstants._();

  // Hover animations
  static const Duration hoverDuration = Duration(milliseconds: 320);
  static const Curve hoverCurve = Curves.easeOutCubic;

  // Selection & Camera Zoom transition
  static const Duration selectionTransitionDuration = Duration(milliseconds: 950);
  static const Curve selectionTransitionCurve = Curves.easeInOutCubic;

  // Continuous floating & breathing loops
  static const Duration coreBreathingDuration = Duration(milliseconds: 3800);
  static const Duration platformFloatDuration = Duration(milliseconds: 4400);

  // Presentation screen entrance
  static const Duration presentationEntranceDuration = Duration(milliseconds: 650);

  // Depth & Perspective
  static const double perspectiveFactor = 0.0012;
  static const double maxHoverDepthZ = 24.0;
  static const double unhoveredDepthScale = 0.94;
  static const double hoveredDepthScale = 1.15;
}
