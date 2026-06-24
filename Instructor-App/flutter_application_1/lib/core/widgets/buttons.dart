import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Brand-filled primary action button with built-in loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final double height;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.height = 50,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: color == null
            ? null
            : FilledButton.styleFrom(backgroundColor: color),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Outlined / neutral secondary action button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 9),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
