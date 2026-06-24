import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/action_card.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_icon_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/local_auth_service.dart';
import '../../auth/login_page.dart';
import '../../scan/presentation/qr_scan_page.dart';
import '../../history/presentation/history_page.dart';
import '../../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  final String studentId;
  const HomePage({super.key, required this.studentId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Logout logic lives here so SettingsPage needs no auth imports ──────────
  void _handleLogout() async {
    final navigator = Navigator.of(context);
    await LocalAuthService.clearCredentials();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SettingsPage(studentId: widget.studentId, onLogout: _handleLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Custom header (replaces the AppBar) ────────────────
                    _Header(onSettings: _openSettings),

                    const SizedBox(height: 28),

                    // ── Student identity card ──────────────────────────────
                    _StudentCard(studentId: widget.studentId),

                    const SizedBox(height: 28),

                    const SectionTitle('Quick Actions'),

                    // ── Actions ────────────────────────────────────────────
                    ActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan QR Code',
                      subtitle: 'Mark your attendance by scanning the QR',
                      emphasized: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QrScanPage(studentId: widget.studentId),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ActionCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'My Attendance',
                      subtitle: 'View your attendance history',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HistoryPage(studentId: widget.studentId),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back!',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  color: c.textPrimary,
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Attendance',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  color: c.primaryRed,
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Glass circular settings button (keeps existing onTap behavior).
        GlassIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: onSettings,
          size: 52,
        ),
      ],
    );
  }
}

// ── Student identity card ─────────────────────────────────────────────────────
// A rich red "hero" card in both themes — white text reads well on the red
// gradient regardless of light/dark mode.

class _StudentCard extends StatelessWidget {
  final String studentId;
  const _StudentCard({required this.studentId});

  @override
  Widget build(BuildContext context) {
    final isDark = context.colors.isDark;

    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.brandRed.withValues(alpha: 0.45),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.brandRed.withValues(alpha: isDark ? 0.85 : 0.95),
          AppColors.darkRed.withValues(alpha: isDark ? 0.90 : 0.97),
          AppColors.black.withValues(alpha: isDark ? 0.85 : 0.92),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      child: Stack(
        children: [
          // Decorative low-opacity graduation cap — vertically centered and
          // sized to fit the card so it never clips as the card height changes.
          Positioned(
            right: -8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.school_rounded,
                size: 72,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile + Student ID ───────────────────────────────────
              Row(
                children: [
                  // Clean circular student identity avatar.
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brandRed, AppColors.darkRed],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDENT ID',
                          style: TextStyle(
                            color: AppColors.lightGray.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Dominant Student ID.
                        Text(
                          studentId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
