import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Adaptive circular/rounded glass icon button.
///
/// Used for the settings button and screen back arrows so they sit naturally
/// over the background image in both light and dark mode.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = c.isDark ? Colors.white : AppColors.black;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: tint.withValues(alpha: 0.06),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withValues(alpha: 0.14)),
              ),
              child: Tooltip(
                message: tooltip,
                child: Icon(icon, color: c.textPrimary, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
