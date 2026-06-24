import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/adaptive_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/modern_input.dart';
import '../application/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final success = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text, _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      final error = ref.read(authProvider).error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock_reset_rounded, color: ctx.palette.brand),
        title: const Text('Reset your password'),
        content: const Text(
          'Your portal password is managed by MIU IT. Please contact the IT '
          'Service Desk to reset the password for your @miuegypt.edu.eg account.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      body: _BrandBackdrop(
        child: isWide
            ? Row(
                children: [
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(
                    flex: 5,
                    child: Center(child: _formArea(context, padded: true)),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: _formArea(context, padded: false),
                ),
              ),
      ),
    );
  }

  Widget _formArea(BuildContext context, {required bool padded}) {
    final p = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: padded
            ? const EdgeInsets.symmetric(horizontal: 48, vertical: 40)
            : EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact brand lockup (shown prominently on narrow screens)
            Center(
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      color: AppColors.primaryRed,
                      size: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Smart Attendance',
              textAlign: TextAlign.center,
              style: context.tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Instructor Portal',
              textAlign: TextAlign.center,
              style: context.tt.titleMedium?.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: 32),

            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in to your account',
                      style: context.tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back. Please enter your credentials.',
                      style: context.tt.bodySmall
                          ?.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: 24),

                    ModernInput(
                      controller: _emailCtrl,
                      label: 'MIU Email',
                      hint: 'ahmed@miuegypt.edu.eg',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final val = (v ?? '').trim().toLowerCase();
                        if (val.isEmpty) return 'Email is required';
                        if (!val.endsWith('@miuegypt.edu.eg')) {
                          return 'Must be a @miuegypt.edu.eg email';
                        }
                        if (val.split('@')[0].isEmpty) {
                          return 'Email address is invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    ModernInput(
                      controller: _passwordCtrl,
                      label: 'Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text('Remember me',
                                      style: context.tt.bodySmall
                                          ?.copyWith(color: p.textSecondary)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _showForgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    PrimaryButton(
                      label: 'Sign In',
                      icon: Icons.arrow_forward_rounded,
                      loading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: p.textMuted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Use your @miuegypt.edu.eg email address',
                    style: context.tt.bodySmall?.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adaptive page background: soft tinted gradient (light) / deep elegant
/// gradient (dark), with subtle decorative academic motifs.
class _BrandBackdrop extends StatelessWidget {
  final Widget child;
  const _BrandBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF7F7), Color(0xFFF2EAEA)],
        ),
      ),
      child: child,
    );
  }
}

/// Left-hand marketing panel shown on wide screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2F2E), Color(0xFF6C1317)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative academic motif
          Positioned(
            right: -40,
            top: -30,
            child: Icon(Icons.school_rounded,
                size: 320, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Positioned(
            left: -50,
            bottom: -50,
            child: Icon(Icons.qr_code_2_rounded,
                size: 280, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Image.asset('assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_rounded,
                          color: AppColors.primaryRed)),
                ),
                const SizedBox(height: 32),
                Text(
                  'Attendance, reimagined\nfor the modern classroom.',
                  style: context.tt.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generate secure QR sessions, track presence in real time, '
                  'and finalize records — all from one premium instructor '
                  'portal.',
                  style: context.tt.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                const _PanelFeature(
                    icon: Icons.qr_code_scanner_rounded,
                    text: 'Secure QR attendance sessions'),
                const SizedBox(height: 16),
                const _PanelFeature(
                    icon: Icons.verified_user_rounded,
                    text: 'Automatic fraud-flag detection'),
                const SizedBox(height: 16),
                const _PanelFeature(
                    icon: Icons.insights_rounded,
                    text: 'Live presence statistics'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PanelFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: context.tt.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
