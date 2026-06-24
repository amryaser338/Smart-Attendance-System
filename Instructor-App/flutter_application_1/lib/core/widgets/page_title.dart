import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';

/// Section / page heading with optional subtitle and trailing action area.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.tt.headlineSmall?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.tt.bodyMedium?.copyWith(color: p.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
