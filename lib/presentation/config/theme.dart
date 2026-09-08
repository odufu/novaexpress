import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Authoritative Design System for the NovaXpress 3D Presentation Experience
/// Supports both dark mode and meticulously crafted light mode.
/// Section 3 of docs/presentation.md.
class PresentationTheme {
  PresentationTheme._();

  // Core Brand Colors
  static const Color primaryNavy = Color(0xFF071A3D);
  static const Color deepNavy = Color(0xFF031126);
  static const Color backgroundBlack = Color(0xFF020917);
  static const Color novaOrange = Color(0xFFFF7A00);
  static const Color brightOrange = Color(0xFFFF9800);
  static const Color ambientCyan = Color(0xFF00E5FF);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Monochromatic Dark & Grey Palette (Projector Optimized)
  static const Color monoBlack = Color(0xFF090D16);
  static const Color monoDark = Color(0xFF0F172A); // Slate 900 / Deep Charcoal
  static const Color monoDarkElevated = Color(0xFF1E293B); // Slate 800
  static const Color monoGrey = Color(0xFF334155); // Slate 700
  static const Color monoGreyMedium = Color(0xFF475569); // Slate 600
  static const Color monoGreyMuted = Color(0xFF64748B); // Slate 500
  static const Color monoGreyLight = Color(0xFF94A3B8); // Slate 400
  static const Color monoBorder = Color(0xFFCBD5E1); // Slate 300
  static const Color monoBorderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color monoSurfaceLight = Color(0xFFF8FAFC); // Slate 50
  static const Color monoSurfaceElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color monoWhite = Color(0xFFFFFFFF);
  static const Color monoAccent = Color(0xFFEA580C); // Brand Theme Orange

  // Light Mode Specific Design Tokens
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Card
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFCBD5E1); // Slate 300 (Crisp for Projector)
  static const Color lightBorderHover = Color(0xFF94A3B8); // Slate 400
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900 (Bold Charcoal)
  static const Color lightTextSecondary = Color(0xFF334155); // Slate 700 (High Contrast)
  static const Color lightTextMuted = Color(0xFF475569); // Slate 600 (Clear Legibility)
  static const Color lightCodeMono = Color(0xFF0F172A); // High Contrast Dark Charcoal for Mono

  // Glassmorphic Surface Colors
  static final Color coolGlass = const Color(0xFFFFFFFF).withValues(alpha: 0.08);
  static final Color darkGlass = const Color(0xFF071A3D).withValues(alpha: 0.65);
  static final Color lightGlass = const Color(0xFFFFFFFF).withValues(alpha: 0.92);
  static final Color glassBorder = const Color(0xFFFFFFFF).withValues(alpha: 0.14);
  static final Color glassBorderActive = const Color(0xFFEA580C).withValues(alpha: 0.45);
  static final Color orangeGlow = const Color(0xFFEA580C).withValues(alpha: 0.35);

  // Gradients
  static const RadialGradient coreGlowGradient = RadialGradient(
    colors: [
      Color(0x55FF7A00),
      Color(0x15FF7A00),
      Colors.transparent,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient platformHighlightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x28FF7A00),
      Color(0x05071A3D),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCC071A3D),
      Color(0xEE031126),
    ],
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
  );

  // Dynamic Theme Helpers
  static Color bg(bool isLight) => isLight ? lightBackground : backgroundBlack;
  static Color surface(bool isLight) => isLight ? lightSurface : deepNavy;
  static Color surfaceElevated(bool isLight) => isLight ? lightSurfaceElevated : primaryNavy;
  static Color border(bool isLight) => isLight ? lightBorder : Colors.white.withValues(alpha: 0.1);
  static Color textPrimary(bool isLight) => isLight ? lightTextPrimary : pureWhite;
  static Color textSecondary(bool isLight) => isLight ? lightTextSecondary : const Color(0xFFCBD5E1);
  static Color textMuted(bool isLight) => isLight ? lightTextMuted : const Color(0xFF94A3B8);
  static Color codeAccent(bool isLight) => isLight ? lightCodeMono : brightOrange;

  // Typography (Inter & JetBrains Mono) - Default (Dark)
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: pureWhite,
    letterSpacing: -0.8,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: pureWhite,
    letterSpacing: -0.4,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: const Color(0xFFCBD5E1),
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF94A3B8),
  );

  static TextStyle get codeMono => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: brightOrange,
    letterSpacing: 0.5,
  );

  static TextStyle get labelFeature => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: pureWhite,
    letterSpacing: 0.6,
  );

  // Theme-Aware Typography Getters
  static TextStyle titleLargeThemed(bool isLight) => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: textPrimary(isLight),
    letterSpacing: -0.8,
  );

  static TextStyle titleMediumThemed(bool isLight) => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary(isLight),
    letterSpacing: -0.4,
  );

  static TextStyle bodyMediumThemed(bool isLight) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary(isLight),
    height: 1.5,
  );

  static TextStyle bodySmallThemed(bool isLight) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textMuted(isLight),
  );

  static TextStyle codeMonoThemed(bool isLight) => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: codeAccent(isLight),
    letterSpacing: 0.5,
  );

  static TextStyle labelFeatureThemed(bool isLight) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textPrimary(isLight),
    letterSpacing: 0.6,
  );
}
