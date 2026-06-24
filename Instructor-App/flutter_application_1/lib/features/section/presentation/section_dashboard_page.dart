import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/adaptive_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/stats_card.dart';
import '../application/section_notifier.dart';
import '../domain/section_models.dart';
import 'qr_session_page.dart';

class SectionDashboardPage extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final String sectionId;

  const SectionDashboardPage({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.sectionId,
  });

  @override
  ConsumerState<SectionDashboardPage> createState() =>
      _SectionDashboardPageState();
}

class _SectionDashboardPageState extends ConsumerState<SectionDashboardPage> {
  // Display-only roster names (student_id -> name). Fetched from the
  // getStudentsForSection endpoint purely to label rows; it does not affect
  // attendance state, selection, or the save flow.
  Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(sectionProvider.notifier).loadStudents(
            courseId: widget.courseId,
            sectionId: widget.sectionId,
          );
    });
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final json = await ref.read(sectionApiProvider).getStudentsForSection(
            courseId: widget.courseId,
            sectionId: widget.sectionId,
          );
      final resp = StudentsResponse.fromJson(json);
      if (mounted && resp.studentNames.isNotEmpty) {
        setState(() => _names = resp.studentNames);
      }
    } catch (_) {
      // Names are a nicety; ignore failures and fall back to IDs.
    }
  }

  /// Resolve a student's display name: prefer the roster name, then any name
  /// already present in section state, then the raw ID.
  String _displayName(String id, StudentsResponse? students) =>
      _names[id] ?? (students?.displayName(id) ?? id);

  Future<void> _generateQr() async {
    final nav = Navigator.of(context);
    await ref.read(sectionProvider.notifier).generateQr(
          courseId: widget.courseId,
          sectionId: widget.sectionId,
        );
    if (!mounted) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => QrSessionPage(
          courseId: widget.courseId,
          sectionId: widget.sectionId,
        ),
      ),
    );
  }

  Future<void> _saveFinalize() async {
    final res = await ref.read(sectionProvider.notifier).finalize(
          courseId: widget.courseId,
          sectionId: widget.sectionId,
        );
    // res == null means API failed — do not navigate
    if (!mounted || res == null) return;

    // Show success feedback via the app-level ScaffoldMessenger so it
    // persists on the courses page after navigation.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Final attendance saved successfully'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    // Return to the Courses & Sections page
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sectionProvider);
    final notifier = ref.read(sectionProvider.notifier);
    final p = context.palette;

    final students = state.students;
    final studentIds = students?.studentIds ?? <String>[];
    final presentCount = state.presentSelected.length;
    final absentCount = studentIds.length - presentCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.courseName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text(
              '${widget.courseId} · Section ${widget.sectionId}',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: CustomScrollView(
            slivers: [
              // Error banner
              if (state.error != null)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.dangerContainer,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: p.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: p.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(state.error!,
                              style: context.tt.bodySmall
                                  ?.copyWith(color: p.danger)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _StatRow(children: [
                    StatsCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Present',
                      value: '$presentCount',
                      accent: AppColors.success,
                    ),
                    StatsCard(
                      icon: Icons.cancel_rounded,
                      label: 'Absent',
                      value: '$absentCount',
                      accent: AppColors.primaryRed,
                    ),
                    StatsCard(
                      icon: Icons.people_rounded,
                      label: 'Total Students',
                      value: '${studentIds.length}',
                      accent: AppColors.info,
                    ),
                  ]),
                ),
              ),

              // Generate QR button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: PrimaryButton(
                    label: 'Generate QR Session',
                    icon: Icons.qr_code_rounded,
                    onPressed: state.isLoading ? null : _generateQr,
                  ),
                ),
              ),

              // Security flags
              if (state.flags != null && state.flags!.flagsCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _FlagsCard(
                      count: state.flags!.flagsCount,
                      children: state.flags!.flags
                          .map((f) => _FlagTile(
                                reason: f.flagReason,
                                subtitle:
                                    'ID: ${f.studentId} · ${f.message}',
                              ))
                          .toList(),
                    ),
                  ),
                ),

              // Attendance table header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _AttendanceTableHeader(),
                ),
              ),

              // Attendance rows
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: _AttendanceTable(
                  loading: state.isLoading && students == null,
                  studentIds: studentIds,
                  displayName: (id) => _displayName(id, students),
                  isPresent: (id) => state.presentSelected.contains(id),
                  onToggle: notifier.togglePresent,
                ),
              ),

              // Save Final button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: PrimaryButton(
                    label: 'Save Final Attendance',
                    icon: Icons.save_rounded,
                    height: 54,
                    onPressed: state.isLoading ? null : _saveFinalize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<Widget> children;
  const _StatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 1;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Sticky header row for the attendance table.
class _AttendanceTableHeader extends StatelessWidget {
  const _AttendanceTableHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg)),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text('#', style: _hStyle(context)),
            ),
            Expanded(child: Text('STUDENT', style: _hStyle(context))),
            Text('PRESENT', style: _hStyle(context)),
          ],
        ),
      ),
    );
  }

  TextStyle? _hStyle(BuildContext context) =>
      context.tt.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.palette.textMuted,
        letterSpacing: 0.6,
      );
}

/// Sliver version of the attendance table (rows only, no header).
class _AttendanceTable extends StatelessWidget {
  final bool loading;
  final List<String> studentIds;
  final String Function(String id) displayName;
  final bool Function(String id) isPresent;
  final void Function(String id) onToggle;

  const _AttendanceTable({
    required this.loading,
    required this.studentIds,
    required this.displayName,
    required this.isPresent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (loading) {
      return SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusLg)),
            border: Border(
              left: BorderSide(color: p.border),
              right: BorderSide(color: p.border),
              bottom: BorderSide(color: p.border),
            ),
          ),
          height: 200,
          child: const LoadingWidget(),
        ),
      );
    }

    if (studentIds.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusLg)),
            border: Border(
              left: BorderSide(color: p.border),
              right: BorderSide(color: p.border),
              bottom: BorderSide(color: p.border),
            ),
          ),
          height: 200,
          child: const EmptyStateWidget(
            icon: Icons.people_outline_rounded,
            title: 'No students loaded',
            message: 'There are no students in this section yet.',
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          final id = studentIds[index];
          final isLast = index == studentIds.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: isLast
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(AppTheme.radiusLg))
                  : null,
              border: Border(
                left: BorderSide(color: p.border),
                right: BorderSide(color: p.border),
                bottom: BorderSide(color: p.border),
              ),
            ),
            child: _AttendanceRow(
              index: index + 1,
              name: displayName(id),
              studentId: id,
              present: isPresent(id),
              onTap: () => onToggle(id),
            ),
          );
        },
        childCount: studentIds.length,
      ),
    );
  }
}

class _AttendanceRow extends StatefulWidget {
  final int index;
  final String name;
  final String studentId;
  final bool present;
  final VoidCallback onTap;

  const _AttendanceRow({
    required this.index,
    required this.name,
    required this.studentId,
    required this.present,
    required this.onTap,
  });

  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final showName = widget.name != widget.studentId;
    final bg = widget.present
        ? p.success.withValues(alpha: 0.08)
        : _hover
            ? p.surfaceAlt
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('${widget.index}',
                    style: context.tt.bodySmall
                        ?.copyWith(color: p.textMuted)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: context.tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (showName)
                      Text(widget.studentId,
                          style: context.tt.bodySmall
                              ?.copyWith(color: p.textMuted)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: widget.present,
                  onChanged: (_) => widget.onTap(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible card surfacing detected security flags.
class _FlagsCard extends StatelessWidget {
  final int count;
  final List<Widget> children;
  const _FlagsCard({required this.count, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.dangerContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: p.danger.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.warning_amber_rounded, color: p.danger),
          title: Text(
            '$count Security ${count == 1 ? 'Flag' : 'Flags'} Detected',
            style: context.tt.titleSmall
                ?.copyWith(color: p.danger, fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: children,
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final String reason;
  final String subtitle;
  const _FlagTile({required this.reason, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: p.danger.withValues(alpha: 0.15),
        child: Icon(Icons.person_off_rounded, size: 16, color: p.danger),
      ),
      title: Text(reason,
          style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: context.tt.bodySmall),
    );
  }
}
