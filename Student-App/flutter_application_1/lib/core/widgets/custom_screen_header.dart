import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_icon_button.dart';

/// Custom SafeArea-style header that replaces the default AppBar.
///
/// Shows an optional glass back button on the left, a centered serif title, and
/// an optional trailing widget on the right. Keeps the background image fully
/// visible behind it.
class CustomScreenHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final Widget? trailing;

  const CustomScreenHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        if (showBack)
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          )
        else
          const SizedBox(width: 48),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              color: c.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    );
  }
}
