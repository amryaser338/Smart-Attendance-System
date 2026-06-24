import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Paints the adaptive brand background image (light or dark variant) plus a
/// subtle readability overlay behind [child].
///
/// Wrap a `Scaffold` whose `backgroundColor` is `Colors.transparent`, or use
/// it as the first layer of a `Stack`. The correct asset and overlay are chosen
/// from the active theme brightness, so it reacts to light/dark switches.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = c.isDark ? AppColors.black : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        image: DecorationImage(
          image: AssetImage(c.backgroundAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              overlay.withValues(alpha: c.isDark ? 0.20 : 0.08),
              overlay.withValues(alpha: c.isDark ? 0.55 : 0.28),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
