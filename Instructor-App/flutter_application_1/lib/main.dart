import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/state_widgets.dart';
import 'features/auth/application/auth_notifier.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/courses/presentation/courses_sections_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartAttendanceInstructorApp()));
}

class SmartAttendanceInstructorApp extends StatelessWidget {
  const SmartAttendanceInstructorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Attendance - Instructor',
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(body: LoadingWidget());
    }

    if (auth.isLoggedIn) {
      return const CoursesSectionsPage();
    }

    return const LoginPage();
  }
}
