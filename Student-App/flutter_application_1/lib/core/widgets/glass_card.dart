import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Adaptive glassmorphism card.
///
/// Light mode  → soft white translucent fill with a light-gray border.
/// Dark mode   → dark translucent fill with a subtle silver/red border.
/// [emphasized] adds a soft brand-red wash + red border (used for primary
/// surfaces like the Scan QR action and the student hero card).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool emphasized;
  final VoidCallback? onTap;

  /// Optional explicit gradient (overrides the adaptive default).
  final Gradient? gradient;

  /// Optional explicit border color (overrides the adaptive default).
  final Color? borderColor;

  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.emphasized = false,
    this.onTap,
    this.gradient,
    this.borderColor,
    this.blur = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final effectiveGradient =
        gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: emphasized
              ? [
                  AppColors.brandRed.withValues(alpha: c.isDark ? 0.30 : 0.14),
                  c.surface,
                ]
              : [c.surface, c.surface],
        );

    final effectiveBorder =
        borderColor ??
        (emphasized ? AppColors.brandRed.withValues(alpha: 0.40) : c.border);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: emphasized && c.isDark
                ? AppColors.darkRed.withValues(alpha: 0.40)
                : c.shadow,
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}
