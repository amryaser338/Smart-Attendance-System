import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Adaptive, semantic colors that resolve correctly for light & dark mode.
///
/// Registered as a [ThemeExtension] on both themes so widgets can read them via
/// `Theme.of(context).extension<AppPalette>()!` — or, more ergonomically,
/// `context.palette`. This keeps every widget free of hard-coded hex values
/// while still expressing intent (sidebar background, card border, etc.).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color canvas; // app background behind everything
  final Color surface; // card / panel background
  final Color surfaceAlt; // subtly elevated surface
  final Color border; // hairline borders & dividers
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Sidebar (dark in both modes for the premium SaaS look)
  final Color sidebarBg;
  final Color sidebarText;
  final Color sidebarMutedText;
  final Color sidebarActiveBg;
  final Color sidebarHoverBg;

  // Brand
  final Color brand;
  final Color brandHover;
  final Color brandPressed;
  final Color brandContainer; // tinted surface for badges/headers
  final Color onBrandContainer;

  // Status accents
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;

  // Glassmorphism
  final Color glassFill;
  final Color glassBorder;

  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.sidebarBg,
    required this.sidebarText,
    required this.sidebarMutedText,
    required this.sidebarActiveBg,
    required this.sidebarHoverBg,
    required this.brand,
    required this.brandHover,
    required this.brandPressed,
    required this.brandContainer,
    required this.onBrandContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.glassFill,
    required this.glassBorder,
  });

  static const AppPalette light = AppPalette(
    canvas: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    textPrimary: AppColors.black,
    textSecondary: AppColors.darkGray,
    textMuted: Color(0xFF8A8A8C),
    sidebarBg: AppColors.sidebarLight,
    sidebarText: AppColors.white,
    sidebarMutedText: AppColors.silver,
    sidebarActiveBg: AppColors.primaryRed,
    sidebarHoverBg: Color(0xFF3C3D3C),
    brand: AppColors.primaryRed,
    brandHover: AppColors.redHover,
    brandPressed: AppColors.redPressed,
    brandContainer: AppColors.redTint,
    onBrandContainer: AppColors.primaryRed,
    success: AppColors.success,
    successContainer: AppColors.successTint,
    warning: AppColors.warning,
    warningContainer: AppColors.warningTint,
    danger: AppColors.danger,
    dangerContainer: AppColors.dangerTint,
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33FFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? sidebarBg,
    Color? sidebarText,
    Color? sidebarMutedText,
    Color? sidebarActiveBg,
    Color? sidebarHoverBg,
    Color? brand,
    Color? brandHover,
    Color? brandPressed,
    Color? brandContainer,
    Color? onBrandContainer,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? glassFill,
    Color? glassBorder,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarMutedText: sidebarMutedText ?? this.sidebarMutedText,
      sidebarActiveBg: sidebarActiveBg ?? this.sidebarActiveBg,
      sidebarHoverBg: sidebarHoverBg ?? this.sidebarHoverBg,
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      brandPressed: brandPressed ?? this.brandPressed,
      brandContainer: brandContainer ?? this.brandContainer,
      onBrandContainer: onBrandContainer ?? this.onBrandContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarMutedText: Color.lerp(sidebarMutedText, other.sidebarMutedText, t)!,
      sidebarActiveBg: Color.lerp(sidebarActiveBg, other.sidebarActiveBg, t)!,
      sidebarHoverBg: Color.lerp(sidebarHoverBg, other.sidebarHoverBg, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      brandPressed: Color.lerp(brandPressed, other.brandPressed, t)!,
      brandContainer: Color.lerp(brandContainer, other.brandContainer, t)!,
      onBrandContainer: Color.lerp(onBrandContainer, other.onBrandContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}

/// Ergonomic access: `context.palette.brand`, `context.cs`, `context.tt`.
extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}
