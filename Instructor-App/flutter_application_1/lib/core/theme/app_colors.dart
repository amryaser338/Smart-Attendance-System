import 'package:flutter/material.dart';

/// Raw brand palette for the Smart Attendance Instructor Portal.
///
/// These are the *only* place hard-coded brand hex values live. Everything in
/// the app resolves colors through the adaptive [AppPalette] theme extension or
/// `Theme.of(context).colorScheme`, never by referencing these constants
/// directly in widgets.
class AppColors {
  AppColors._();

  // ── Brand palette ─────────────────────────────────────────────────────
  static const Color primaryRed = Color(0xFF6C1317);
  static const Color black = Color(0xFF050606);
  static const Color darkGray = Color(0xFF2E2F2E);
  static const Color silver = Color(0xFFA5A5A5);
  static const Color lightGray = Color(0xFFD2D2D2);
  static const Color white = Color(0xFFFFFFFF);

  // ── Derived red tints (for containers, hovers, active states) ─────────
  static const Color redTint = Color(0xFFF5E7E8); // very light red wash
  static const Color redTintDark = Color(0xFF3A1416); // deep red surface
  static const Color redHover = Color(0xFF821820); // lighter than primary
  static const Color redPressed = Color(0xFF540E11); // darker than primary

  // ── Light surfaces ────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF7F7F8); // app canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // cards
  static const Color lightSurfaceAlt = Color(0xFFFAFAFB); // subtle elevated
  static const Color lightBorder = Color(0xFFE5E5E7);

  // ── Dark surfaces ─────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0B0C0B); // app canvas
  static const Color darkSurface = Color(0xFF1A1B1A); // cards
  static const Color darkSurfaceAlt = Color(0xFF222322); // elevated
  static const Color darkBorder = Color(0xFF333433);

  // ── Sidebar (intentionally dark in BOTH light & dark modes) ───────────
  static const Color sidebarLight = darkGray; // #2E2F2E
  static const Color sidebarDark = Color(0xFF111211);

  // ── Semantic accents (kept distinct from brand red) ───────────────────
  static const Color success = Color(0xFF1E8E3E);
  static const Color successTint = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFB26A00);
  static const Color warningTint = Color(0xFFFCEFD9);
  static const Color danger = Color(0xFFC5221F);
  static const Color dangerTint = Color(0xFFFCE8E6);
  static const Color info = Color(0xFF1A56DB);
}
