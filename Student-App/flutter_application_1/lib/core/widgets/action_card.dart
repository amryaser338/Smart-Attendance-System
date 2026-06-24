import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// Large tappable action card: icon container on the left, title + subtitle in
/// the middle, circular arrow button on the right. Built on [GlassCard] so it
/// adapts to light/dark mode. [emphasized] gives the brand-red treatment.
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = c.isDark ? Colors.white : AppColors.black;

    return GlassCard(
      onTap: onTap,
      emphasized: emphasized,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // ── Icon container ─────────────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: emphasized
                    ? const [AppColors.brandRed, AppColors.darkRed]
                    : [c.solidSurface, c.background],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              color: emphasized ? Colors.white : c.textPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // ── Title + subtitle ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Circular arrow button ──────────────────────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emphasized
                  ? AppColors.brandRed.withValues(alpha: 0.85)
                  : tint.withValues(alpha: 0.08),
              border: Border.all(color: tint.withValues(alpha: 0.16)),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: emphasized ? Colors.white : c.textPrimary,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}
