import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';
import '../theme/app_theme.dart';

/// Frosted-glass surface used for the login card and other floating panels.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.radius = AppTheme.radiusXl,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: p.glassFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
