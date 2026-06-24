import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  // ── Color schemes (built manually from the brand palette) ─────────────────

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandRed,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandRedLightContainer,
    onPrimaryContainer: AppColors.brandRed,
    secondary: AppColors.darkGray,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE3E3E3),
    onSecondaryContainer: AppColors.black,
    tertiary: AppColors.silverGray,
    onTertiary: AppColors.black,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFADAD8),
    onErrorContainer: Color(0xFF7A1F1C),
    surface: Colors.white,
    onSurface: AppColors.black,
    onSurfaceVariant: Color(0xFF6B7280),
    surfaceContainerHighest: AppColors.lightGray,
    outline: AppColors.silverGray,
    outlineVariant: Color(0xFFD9D9D9),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brandRed,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandRedDarkContainer,
    onPrimaryContainer: AppColors.brandRedLightContainer,
    secondary: AppColors.silverGray,
    onSecondary: AppColors.black,
    secondaryContainer: AppColors.darkSurfaceElevated,
    onSecondaryContainer: AppColors.lightGray,
    tertiary: AppColors.silverGray,
    onTertiary: AppColors.black,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFF5C1A18),
    onErrorContainer: Color(0xFFFADAD8),
    surface: AppColors.darkGray,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.silverGray,
    surfaceContainerHighest: AppColors.darkGray,
    outline: AppColors.silverGray,
    outlineVariant: Color(0xFF4A4B4A),
  );

  static ThemeData _build(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark
          ? AppColors.black
          : AppColors.lightBackground,
      // Cards: flat (elevation via shadow handled per-widget), 16-radius
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Inputs: filled style, no visible border at rest, primary ring on focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),
      // Buttons: 14-radius, full-width minimum
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      // AppBar: no elevation, surface background
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
    );
  }
}
