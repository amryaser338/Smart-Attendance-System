import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/adaptive_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/course_card.dart';
import '../../../core/widgets/page_title.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/stats_card.dart';
import '../../auth/application/auth_notifier.dart';
import '../../doctor/application/doctor_notifier.dart';
import '../application/courses_notifier.dart';
import '../domain/course_models.dart';
import '../../section/presentation/section_dashboard_page.dart';

class CoursesSectionsPage extends ConsumerStatefulWidget {
  const CoursesSectionsPage({super.key});

  @override
  ConsumerState<CoursesSectionsPage> createState() =>
      _CoursesSectionsPageState();
}

class _CoursesSectionsPageState extends ConsumerState<CoursesSectionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final doctorId = ref.read(doctorProvider).doctorId;
      ref.read(coursesProvider.notifier).loadForDoctor(doctorId);
    });
  }

  Future<void> _logout() async {
    // Just clear auth state — the declarative _AuthGate in main.dart will
    // react to isLoggedIn becoming false and show the LoginPage. Doing a
    // manual pushAndRemoveUntil here would tear out the _AuthGate root and
    // break subsequent logins.
    await ref.read(authProvider.notifier).logout();
  }

  void _reload() {
    final id = ref.read(doctorProvider).doctorId;
    ref.read(coursesProvider.notifier).loadForDoctor(id);
  }

  /// Resolves the full weekday name from the backend `today` value (which may
  /// be an abbreviation like "MON", a full name, or an ISO date) and falls
  /// back to the device's current weekday. Presentation-only.
  String _dayName(String? today) {
    const full = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const abbrev = {
      'MON': 'Monday',
      'TUE': 'Tuesday',
      'WED': 'Wednesday',
      'THU': 'Thursday',
      'FRI': 'Friday',
      'SAT': 'Saturday',
      'SUN': 'Sunday',
    };
    final t = today?.trim() ?? '';
    if (t.isNotEmpty) {
      final parsed = DateTime.tryParse(t);
      if (parsed != null) return full[parsed.weekday - 1];
      final key = t.toUpperCase();
      if (key.length >= 3 && abbrev.containsKey(key.substring(0, 3))) {
        return abbrev[key.substring(0, 3)]!;
      }
    }
    return full[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coursesProvider);
    final email = ref.watch(authProvider).email ?? '';
    final doctorId = ref.watch(doctorProvider).doctorId;
    final data = state.data;
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _BrandHeader(onLogout: _logout),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (state.isLoading) {
                    return const LoadingWidget(message: 'Loading your classes…');
                  }
                  if (state.error != null) {
                    return AppErrorWidget(
                      title: 'Could not load courses',
                      detail: state.error,
                      onRetry: _reload,
                    );
                  }
                  return _DashboardBody(
                    dayName: _dayName(data?.today),
                    doctorId: doctorId,
                    email: email,
                    data: data,
                    onSection: (courseId, courseName, sectionId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SectionDashboardPage(
                            courseId: courseId,
                            courseName: courseName,
                            sectionId: sectionId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top branding header: logo (left), title block (center), logout (right).
class _BrandHeader extends StatelessWidget {
  final VoidCallback onLogout;
  const _BrandHeader({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: p.border),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.school_rounded, color: AppColors.primaryRed),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Smart Attendance',
                  style: context.tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Instructor Portal',
                  style:
                      context.tt.labelSmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.brand,
              side: BorderSide(color: p.brand.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String dayName;
  final String doctorId;
  final String email;
  final DoctorCoursesResponse? data;
  final void Function(String courseId, String courseName, String sectionId)
      onSection;

  const _DashboardBody({
    required this.dayName,
    required this.doctorId,
    required this.email,
    required this.data,
    required this.onSection,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final List<CourseItem> courses = data?.courses ?? const [];
    final int courseCount = data?.count ?? courses.length;
    int sectionTotal = 0;
    for (final c in courses) {
      sectionTotal += c.sections.length;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
          children: [
            // Instructor profile card (top of the page)
            _InstructorCard(
              doctorId: doctorId,
              email: email,
            ),
            const SizedBox(height: 24),

            // Heading
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Classes",
                  style: context.tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  dayName,
                  style: context.tt.titleMedium?.copyWith(
                    color: p.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stat cards
            _StatGrid(children: [
              StatsCard(
                icon: Icons.class_rounded,
                label: 'Courses Today',
                value: '$courseCount',
                accent: AppColors.primaryRed,
              ),
              StatsCard(
                icon: Icons.layers_rounded,
                label: 'Total Sections',
                value: '$sectionTotal',
                accent: AppColors.info,
              ),
              StatsCard(
                icon: Icons.groups_rounded,
                label: 'Sections / Course',
                value: courseCount == 0
                    ? '0'
                    : (sectionTotal / courseCount).round().toString(),
                accent: AppColors.success,
              ),
            ]),
            const SizedBox(height: 28),

            PageTitle(
              title: 'Your Courses',
              subtitle: courses.isEmpty
                  ? null
                  : '$courseCount ${courseCount == 1 ? 'course' : 'courses'} scheduled',
            ),
            const SizedBox(height: 16),

            if (courses.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: p.border),
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const EmptyStateWidget(
                  icon: Icons.event_available_rounded,
                  title: 'No classes today',
                  message: 'Enjoy your day — nothing is scheduled.',
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final cols =
                      c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 720 ? 2 : 1);
                  const gap = 16.0;
                  final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final course in courses)
                        SizedBox(
                          width: cardW,
                          child: CourseCard(
                            courseId: course.courseId,
                            courseName: course.courseName,
                            sections: List<String>.from(course.sections),
                            onSectionTap: (sec) => onSection(
                                course.courseId, course.courseName, sec),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InstructorCard extends StatelessWidget {
  final String doctorId;
  final String email;

  const _InstructorCard({
    required this.doctorId,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initial = doctorId.isNotEmpty ? doctorId[0].toUpperCase() : 'D';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: p.brand,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. $doctorId',
                  style: context.tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: context.tt.bodyMedium?.copyWith(color: p.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<Widget> children;
  const _StatGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
        const gap = 16.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
