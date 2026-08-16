import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Industrial Operational System Color Palette matching DESIGN.md
  static const Color surface = Color(0xFFF7FAFC);
  static const Color surfaceDim = Color(0xFFD7DADC);
  static const Color surfaceBright = Color(0xFFF7FAFC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F4F6);
  static const Color surfaceContainer = Color(0xFFEBEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE5E9EB);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);

  static const Color onSurface = Color(0xFF181C1E);
  static const Color onSurfaceVariant = Color(0xFF44474D);
  static const Color inverseSurface = Color(0xFF2D3133);
  static const Color inverseOnSurface = Color(0xFFEEF1F3);
  static const Color outline = Color(0xFF75777E);
  static const Color outlineVariant = Color(0xFFC5C6CE);

  // Primary: Deep Navy (#031632)
  static const Color primary = Color(0xFF031632);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1A2B48);
  static const Color onPrimaryContainer = Color(0xFF8293B5);

  // High-Visibility Accent: Orange (#F37021 / #FF8928)
  static const Color orange = Color(0xFFF37021);
  static const Color secondary = Color(0xFF964900);
  static const Color secondaryContainer = Color(0xFFFF8928);
  static const Color onSecondaryContainer = Color(0xFF642F00);

  // Status & Tertiary (Green, Red, Blue)
  static const Color tertiaryContainer = Color(0xFF003318);
  static const Color onTertiaryContainer = Color(0xFF4EA36B);
  static const Color success = Color(0xFF00522A);
  
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color primaryFixed = Color(0xFFD7E2FF);
  static const Color onPrimaryFixed = Color(0xFF081B38);

  // Dark Palette Tokens (DESIGN.md Industrial Dark)
  static const Color backgroundDark = Color(0xFF0B1021);
  static const Color surfaceDark = Color(0xFF151D36);
  static const Color cardDark = Color(0xFF1E294A);
  static const Color borderDark = Color(0xFF2E3D6B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Backward compatibility aliases
  static const Color navy = primary;
  static const Color backgroundLight = surface;
  static const Color surfaceLight = surfaceContainerLowest;
  static const Color borderLight = surfaceContainerHighest;

  static const Color danger = error;
  static const Color warning = secondary;
  static const Color info = onPrimaryFixed;
}

class AppTheme {
  // Light Theme Configuration
  static ThemeData get lightTheme {
    final baseInter = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      primaryColor: AppColors.primary,
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.orange,
        surface: AppColors.surfaceContainerLowest,
        surfaceContainer: AppColors.surfaceContainer,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0.5,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: AppColors.outline.withValues(alpha: 0.8)),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.onSurface),
        bodyMedium: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
        labelLarge: GoogleFonts.jetBrainsMono(color: AppColors.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Industrial Dark Theme Configuration
  static ThemeData get darkTheme {
    final baseInter = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.orange,
      cardColor: AppColors.surfaceDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.primaryFixed,
        surface: AppColors.surfaceDark,
        surfaceContainer: AppColors.cardDark,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.95),
        elevation: 0.5,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: GoogleFonts.inter(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimaryDark),
        bodyMedium: GoogleFonts.inter(color: AppColors.textSecondaryDark),
        labelLarge: GoogleFonts.jetBrainsMono(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
      ),
    );
  }
}
