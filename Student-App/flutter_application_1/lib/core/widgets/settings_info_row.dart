import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// One labelled info row used inside the Settings profile / about glass cards.
///
/// Icon sits in a circular red-tinted container; label uses muted text and the
/// value uses primary text. Optional [trailing] (e.g. a visual copy icon) and a
/// [mono] flag for IDs.
class SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;

  const SettingsInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular red-tinted icon container.
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandRed.withValues(alpha: c.isDark ? 0.30 : 0.12),
            border: Border.all(
              color: AppColors.brandRed.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(icon, size: 19, color: c.primaryRed),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: mono ? 12 : 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
