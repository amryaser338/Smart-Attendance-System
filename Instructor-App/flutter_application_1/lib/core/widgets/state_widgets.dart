import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';

/// Centered loading spinner with an optional caption.
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3, color: p.brand),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!,
                style: context.tt.bodyMedium?.copyWith(color: p.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Friendly empty-state with an icon, title, optional subtitle and action.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: (iconColor ?? p.textMuted).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: iconColor ?? p.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.tt.titleMedium
                  ?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium?.copyWith(color: p.textMuted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error-state with a retry affordance.
class AppErrorWidget extends StatelessWidget {
  final String title;
  final String? detail;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.title,
    this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: p.dangerContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 42, color: p.danger),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: context.tt.bodySmall?.copyWith(color: p.textMuted),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
