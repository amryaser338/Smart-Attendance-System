import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'adaptive_colors.dart';

/// Central theme factory for the Smart Attendance Instructor Portal.
///
/// The portal is **light mode only** — there is intentionally no dark theme,
/// no system-theme support, and no theme switcher.
class AppTheme {
  AppTheme._();

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  static ThemeData get light => _build(AppPalette.light);

  static ThemeData _build(AppPalette p) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: p.brand,
      onPrimary: AppColors.white,
      primaryContainer: p.brandContainer,
      onPrimaryContainer: p.onBrandContainer,
      secondary: AppColors.darkGray,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.redTint,
      onSecondaryContainer: p.textPrimary,
      tertiary: AppColors.silver,
      onTertiary: AppColors.black,
      error: p.danger,
      onError: AppColors.white,
      errorContainer: p.dangerContainer,
      onErrorContainer: AppColors.danger,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerLowest: p.canvas,
      surfaceContainerLow: p.surfaceAlt,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceAlt,
      surfaceContainerHighest: p.surfaceAlt,
      onSurfaceVariant: p.textSecondary,
      outline: AppColors.silver,
      outlineVariant: p.border,
      shadow: AppColors.black,
      scrim: AppColors.black,
      inverseSurface: AppColors.darkGray,
      onInverseSurface: AppColors.white,
      inversePrimary: p.brandContainer,
    );

    final baseText = Typography.material2021().black.apply(
          bodyColor: p.textPrimary,
          displayColor: p.textPrimary,
          fontFamily: 'Roboto',
        );

    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: baseText.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: baseText.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.canvas,
      textTheme: textTheme,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: p.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        floatingLabelStyle: TextStyle(color: p.brand),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: p.brand.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.success;
          return Colors.transparent;
        }),
        side: BorderSide(color: p.textMuted, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.border,
        circularTrackColor: p.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGray,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
      ),
    );
  }
}
