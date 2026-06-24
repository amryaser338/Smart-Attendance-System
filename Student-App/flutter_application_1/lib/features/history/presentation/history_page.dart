import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/custom_screen_header.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/history_api.dart';
import '../domain/history_models.dart';

class HistoryPage extends StatefulWidget {
  final String studentId;
  const HistoryPage({super.key, required this.studentId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryResponse? _response;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await HistoryApi.fetchHistory(widget.studentId);
      if (mounted) {
        setState(() {
          _response = response;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  children: [
                    const CustomScreenHeader(title: 'My Attendance'),
                    const SizedBox(height: 16),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.primaryRed));
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.wifi_off_rounded,
        iconColor: c.primaryRed,
        title: 'Failed to load attendance',
        message: _error!,
        action: _RetryButton(onTap: _load),
      );
    }

    final response = _response;

    if (response == null || response.sections.isEmpty) {
      return _StateMessage(
        icon: Icons.event_busy_rounded,
        iconColor: c.textMuted,
        title: 'No attendance records yet',
        message: 'Records will appear after your first session.',
      );
    }

    final total = response.presentDays + response.absentDays;
    final rate = total > 0 ? response.presentDays / total : 0.0;

    return RefreshIndicator(
      color: c.primaryRed,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SummaryCard(response: response, rate: rate),
          const SizedBox(height: 16),
          ...response.sections.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SectionCard(section: s),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final HistoryResponse response;
  final double rate;
  const _SummaryCard({required this.response, required this.rate});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GlassCard(
      emphasized: true,
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: c.primaryRed,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Attendance',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${response.presentDays} '
                      'session${response.presentDays == 1 ? '' : 's'} present',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: c.border.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation(AppColors.brandRed),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${response.sections.length} '
            'course${response.sections.length == 1 ? '' : 's'} · '
            '${response.absentDays} absent',
            style: TextStyle(color: c.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final AttendanceSection section;
  const _SectionCard({required this.section});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.section;
    final total = s.presentCount + s.absentCount;
    final rate = total > 0 ? s.presentCount / total : 0.0;
    final rateColor = rate >= 0.75 ? AppColors.success : AppColors.brandRed;

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandRed.withValues(
                      alpha: c.isDark ? 0.30 : 0.12,
                    ),
                    border: Border.all(
                      color: AppColors.brandRed.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: c.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.courseId,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        'Section ${s.sectionId}',
                        style: TextStyle(color: c.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(
                      alpha: c.isDark ? 0.30 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${s.presentCount}P / ${s.absentCount}A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: c.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: c.textMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Section-level progress bar (always visible)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 4,
              backgroundColor: c.border.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(rateColor),
            ),
          ),

          // ── Expanded dates ─────────────────────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: 12),
            ...s.days.map((day) => _DayRow(day: day)),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final AttendanceDay day;
  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPresent = day.status == 'present';
    final rowColor = isPresent ? AppColors.success : AppColors.brandRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: rowColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rowColor.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(
              isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18,
              color: rowColor,
            ),
            const SizedBox(width: 10),
            Text(
              day.date,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                day.source.toUpperCase(),
                style: TextStyle(fontSize: 10, color: c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared state widgets (loading / empty / error) ────────────────────────────

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: SingleChildScrollView(
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Retry'),
    );
  }
}
