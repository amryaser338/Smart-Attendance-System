import 'package:flutter/material.dart';
import '../../core/widgets/app_background.dart';
import '../auth/local_auth_service.dart';
import '../auth/login_page.dart';
import '../home/presentation/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.80,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();
    _init();
  }

  Future<void> _init() async {
    // Start minimum display timer and credential check simultaneously.
    // This way loading feels intentional but never waits longer than needed.
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 950));

    final creds = await LocalAuthService.getSavedCredentials();

    // Always wait for the minimum display time so the splash isn't a flash.
    await minDelay;

    if (!mounted) return;

    // Fade transition out of the splash into the next screen.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => creds != null
            ? HomePage(
                studentId: LocalAuthService.extractStudentId(creds.email),
              )
            : const LoginPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo ──────────────────────────────────────────────
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 160,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────────────
                  Text(
                    'Smart Attendance',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: cs.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Student App',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 52),

                  // ── Loading indicator ─────────────────────────────────
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
