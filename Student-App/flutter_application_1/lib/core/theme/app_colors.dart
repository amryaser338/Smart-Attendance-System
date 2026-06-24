import 'package:flutter/material.dart';

/// Raw brand palette for the Smart Attendance student app.
///
/// These are the fixed brand values. For anything that must adapt to light /
/// dark mode, prefer [AppPalette] via `context.colors` instead of reaching for
/// these constants directly inside widgets.
class AppColors {
  AppColors._();

  // ── Brand palette ───────────────────────────────────────────────────────
  static const Color black = Color(0xFF050606);
  static const Color lightGray = Color(0xFFD2D2D2);
  static const Color silverGray = Color(0xFFA5A5A5);
  static const Color darkGray = Color(0xFF2E2F2E);
  static const Color brandRed = Color(0xFF6C1317);

  /// Deeper, less-saturated red used for gradients and glass accents.
  static const Color darkRed = Color(0xFF4F0D10);

  // ── Semantic / status colors ─────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFF5A623);
  static const Color info = Color(0xFF00629E);

  // ── Derived container tints (used by ColorScheme roles) ───────────────────
  static const Color brandRedLightContainer = Color(0xFFF6DDDE);
  static const Color brandRedDarkContainer = Color(0xFF4A0C0F);
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color darkSurfaceElevated = Color(0xFF3A3B3A);
}

/// App font families.
class AppFonts {
  AppFonts._();

  /// Academic serif used for display titles / headers.
  static const String serif = 'Georgia';
}

/// Brightness-aware color set resolved once per build via [AppPalette.of].
///
/// Centralizes every adaptive decision so widgets never branch on brightness
/// themselves — they just read `context.colors.textPrimary`, etc.
class AppPalette {
  final bool isDark;

  /// Whole-screen background fill (behind the background image).
  final Color background;

  /// Translucent glass surface fill for cards.
  final Color surface;

  /// Solid (opaque) surface — for places where translucency hurts contrast.
  final Color solidSurface;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Hairline border for glass surfaces.
  final Color border;

  /// Brand red (constant across modes, kept soft).
  final Color primaryRed;

  /// Soft red wash for emphasized surfaces / tinted icon chips.
  final Color redOverlay;

  /// Subtle card shadow color.
  final Color shadow;

  const AppPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.solidSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primaryRed,
    required this.redOverlay,
    required this.shadow,
  });

  static const AppPalette light = AppPalette(
    isDark: false,
    background: AppColors.lightBackground,
    surface: Color(0xB3FFFFFF), // white @ 70%
    solidSurface: Colors.white,
    textPrimary: AppColors.black,
    textSecondary: AppColors.darkGray,
    textMuted: Color(0xFF6B7280),
    border: AppColors.lightGray,
    primaryRed: AppColors.brandRed,
    redOverlay: Color(0x1F6C1317), // ~12% brand red
    shadow: Color(0x1A2E2F2E), // soft gray shadow
  );

  static const AppPalette dark = AppPalette(
    isDark: true,
    background: AppColors.black,
    surface: Color(0x8C2E2F2E), // dark gray @ ~55%
    solidSurface: AppColors.darkGray,
    textPrimary: Colors.white,
    textSecondary: AppColors.lightGray,
    textMuted: AppColors.silverGray,
    border: Color(0x40A5A5A5), // silver @ 25%
    primaryRed: AppColors.brandRed,
    redOverlay: Color(0x476C1317), // ~28% brand red
    shadow: Color(0x66050606), // soft black shadow
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The background image asset for the current brightness.
  String get backgroundAsset =>
      isDark ? 'assets/images/dark_bground.png' : 'assets/images/light_bg.png';
}

/// Convenience accessor: `context.colors.textPrimary`.
extension AppPaletteX on BuildContext {
  AppPalette get colors => AppPalette.of(this);
}
