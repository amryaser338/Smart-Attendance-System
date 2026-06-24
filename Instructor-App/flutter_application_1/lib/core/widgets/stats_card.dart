import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';
import '../theme/app_theme.dart';

/// Premium dashboard metric card: tinted icon chip, large value, caption.
///
/// Doubles as the generic [DashboardCard] surface used across the portal.
class StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? hint;

  const StatsCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              if (hint != null)
                Text(hint!,
                    style:
                        context.tt.labelSmall?.copyWith(color: p.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: context.tt.headlineMedium?.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.tt.bodyMedium
                ?.copyWith(color: p.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Generic elevated container matching the portal card aesthetic.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: p.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
