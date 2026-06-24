import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/adaptive_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/stats_card.dart';
import '../application/section_notifier.dart';

class NotScannedPage extends ConsumerStatefulWidget {
  final String courseId;
  final String sectionId;

  const NotScannedPage({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  @override
  ConsumerState<NotScannedPage> createState() => _NotScannedPageState();
}

class _NotScannedPageState extends ConsumerState<NotScannedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(sectionProvider);
      final meetingId = state.qr?.meetingId;
      if (meetingId != null) {
        ref.read(sectionProvider.notifier).loadAbsentStudents(
              courseId: widget.courseId,
              sectionId: widget.sectionId,
              meetingId: meetingId,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sectionProvider);
    final notifier = ref.read(sectionProvider.notifier);
    final p = context.palette;

    final meetingId = state.qr?.meetingId;
    final absentStudents = state.absentState?.absentStudents ?? [];

    // Toggle handler — identical behavior to the original (optimistic local
    // toggle + draft sync to the backend for the active meeting).
    Future<void> toggle(String studentId, bool currentlyChecked) async {
      if (meetingId == null) return;
      notifier.togglePresent(studentId);
      final status = !currentlyChecked ? "present" : "absent";
      await ref.read(sectionApiProvider).markDraftForMeeting(
            meetingId: meetingId,
            studentId: studentId,
            status: status,
          );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Students Who Didn't Scan")),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: CustomScrollView(
            slivers: [
              // Loading bar
              if (state.isLoading)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(color: p.brand),
                ),

              // Summary cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: LayoutBuilder(builder: (context, c) {
                    const gap = 12.0;
                    final w = (c.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: w,
                          child: StatsCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scanned',
                            value: '${state.scans?.count ?? 0}',
                            accent: AppColors.success,
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: StatsCard(
                            icon: Icons.person_off_rounded,
                            label: 'Not Scanned',
                            value: '${absentStudents.length}',
                            accent: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),

              // Missing meeting_id warning
              if (meetingId == null)
                SliverToBoxAdapter(
                  child: Container(
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
                            size: 18, color: p.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'meeting_id missing — generate a QR session first.',
                            style: context.tt.bodySmall
                                ?.copyWith(color: p.danger),
                          ),
                        ),
                      ],
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
                          .map((f) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      p.danger.withValues(alpha: 0.15),
                                  child: Icon(Icons.person_off_rounded,
                                      size: 16, color: p.danger),
                                ),
                                title: Text(f.flagReason,
                                    style: context.tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'ID: ${f.studentId} · ${f.message}',
                                    style: context.tt.bodySmall),
                              ))
                          .toList(),
                    ),
                  ),
                ),

              // All-scanned empty state
              if (absentStudents.isEmpty && !state.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: p.border),
                      ),
                      height: 200,
                      child: EmptyStateWidget(
                        icon: Icons.verified_rounded,
                        iconColor: AppColors.success,
                        title: 'All students scanned!',
                        message:
                            'Everyone marked their attendance for this session.',
                      ),
                    ),
                  ),
                ),

              // Absent list header
              if (absentStudents.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusLg)),
                        border: Border.all(color: p.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          border:
                              Border(bottom: BorderSide(color: p.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MARK AS PRESENT (AUTO-SAVED)',
                                style: context.tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: p.textMuted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            Icon(Icons.cloud_done_rounded,
                                size: 16, color: p.brand),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Absent rows
              if (absentStudents.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final student = absentStudents[index];
                        final checked = state.presentSelected
                            .contains(student.studentId);
                        final isLast = index == absentStudents.length - 1;
                        return Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: isLast
                                ? const BorderRadius.vertical(
                                    bottom:
                                        Radius.circular(AppTheme.radiusLg))
                                : null,
                            border: Border(
                              left: BorderSide(color: p.border),
                              right: BorderSide(color: p.border),
                              bottom: BorderSide(color: p.border),
                            ),
                          ),
                          child: _AbsentRow(
                            index: index + 1,
                            name: student.name,
                            studentId: student.studentId,
                            checked: checked,
                            enabled: meetingId != null,
                            onToggle: () =>
                                toggle(student.studentId, checked),
                          ),
                        );
                      },
                      childCount: absentStudents.length,
                    ),
                  ),
                ),

              // Return button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: PrimaryButton(
                    label: 'Return to Full Attendance',
                    icon: Icons.list_alt_rounded,
                    height: 54,
                    onPressed: () => Navigator.pop(context),
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

class _AbsentRow extends StatefulWidget {
  final int index;
  final String name;
  final String studentId;
  final bool checked;
  final bool enabled;
  final VoidCallback onToggle;

  const _AbsentRow({
    required this.index,
    required this.name,
    required this.studentId,
    required this.checked,
    required this.enabled,
    required this.onToggle,
  });

  @override
  State<_AbsentRow> createState() => _AbsentRowState();
}

class _AbsentRowState extends State<_AbsentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = widget.checked
        ? p.success.withValues(alpha: 0.08)
        : _hover
            ? p.surfaceAlt
            : Colors.transparent;

    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: widget.checked,
                  onChanged:
                      widget.enabled ? (_) => widget.onToggle() : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.index}. ${widget.name}',
                        style: context.tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(widget.studentId,
                        style: context.tt.bodySmall
                            ?.copyWith(color: p.textMuted)),
                  ],
                ),
              ),
              if (widget.checked)
                Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 14, color: p.brand),
                    const SizedBox(width: 4),
                    Text('Saved',
                        style:
                            context.tt.labelSmall?.copyWith(color: p.brand)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
