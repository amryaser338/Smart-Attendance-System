import 'package:flutter/material.dart';
import '../auth/local_auth_service.dart';
import '../../core/services/app_id_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/custom_screen_header.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/settings_info_row.dart';

class SettingsPage extends StatefulWidget {
  final String studentId;

  /// Logout callback owned by HomePage so this page needs no auth imports.
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.studentId,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _email;
  String? _appId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await LocalAuthService.getSavedCredentials();
    final appId = await AppIdService.getAppId();
    if (mounted) {
      setState(() {
        _email = creds?.email;
        _appId = appId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const CustomScreenHeader(title: 'Settings'),
                  const SizedBox(height: 24),

                  // ── Profile ──────────────────────────────────────────────
                  const SectionTitle('Profile'),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SettingsInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _email ?? '—',
                        ),
                        _rowDivider(c.border),
                        SettingsInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Student ID',
                          value: widget.studentId,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Appearance ───────────────────────────────────────────
                  const SectionTitle('Appearance'),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: ListenableBuilder(
                      listenable: ThemeController.instance,
                      builder: (_, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 18,
                                color: c.primaryRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Theme',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ThemeSelector(palette: c),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── About ────────────────────────────────────────────────
                  const SectionTitle('About'),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SettingsInfoRow(
                          icon: Icons.school_rounded,
                          label: 'Application',
                          value: 'Smart Attendance — Student App',
                        ),
                        _rowDivider(c.border),
                        const SettingsInfoRow(
                          icon: Icons.tag_rounded,
                          label: 'Version',
                          value: '1.0.0',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: c.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This app is used by MIU students to scan attendance '
                            'QR codes and view their attendance history. '
                            'Credentials are stored locally — this is a '
                            'prototype application.',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Logout ───────────────────────────────────────────────
                  _LogoutButton(onLogout: widget.onLogout),

                  const SizedBox(height: 28),

                  // ── Device App ID footer ──────────────────────────────────
                  _AppIdFooter(appId: _appId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _rowDivider(Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: color.withValues(alpha: 0.5)),
  );
}

// ── Device App ID footer ──────────────────────────────────────────────────────

class _AppIdFooter extends StatelessWidget {
  final String? appId;
  const _AppIdFooter({required this.appId});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint_rounded, size: 14, color: c.textMuted),
            const SizedBox(width: 6),
            Text(
              'DEVICE APP ID',
              style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            appId ?? 'Loading…',
            key: ValueKey(appId),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              color: c.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Theme segmented selector ──────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final AppPalette palette;
  const _ThemeSelector({required this.palette});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;

    return SegmentedButton<ThemeMode>(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(46)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brandRed
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : palette.textSecondary,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: palette.border.withValues(alpha: 0.8)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {tc.mode},
      onSelectionChanged: (modes) => tc.setMode(modes.first),
    );
  }
}

// ── Logout button (red glass) ─────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onLogout,
      emphasized: true,
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderColor: AppColors.brandRed.withValues(alpha: 0.5),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 20, color: AppColors.brandRed),
          SizedBox(width: 8),
          Text(
            'Logout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brandRed,
            ),
          ),
        ],
      ),
    );
  }
}
