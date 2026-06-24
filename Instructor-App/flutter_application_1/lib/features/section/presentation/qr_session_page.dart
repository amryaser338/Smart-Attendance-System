import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/adaptive_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/stats_card.dart';
import '../application/section_notifier.dart';
import 'not_scanned_page.dart';

class QrSessionPage extends ConsumerStatefulWidget {
  final String courseId;
  final String sectionId;

  const QrSessionPage({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  @override
  ConsumerState<QrSessionPage> createState() => _QrSessionPageState();
}

class _QrSessionPageState extends ConsumerState<QrSessionPage> {
  Timer? _tick;

  int _unixNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _endAndGoToNotScanned() async {
    final notifier = ref.read(sectionProvider.notifier);
    await notifier.refreshScansAndFlags();
    notifier.endQrSessionNow();
    notifier.applyQrResultAsAttendance();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotScannedPage(
          courseId: widget.courseId,
          sectionId: widget.sectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sectionProvider);
    final qr = state.qr;
    final p = context.palette;

    if (qr == null) {
      return const Scaffold(body: Center(child: Text('No QR session')));
    }

    final currentSyncedTime = _unixNow() + state.serverClockOffset;
    final remaining = qr.expiresAt - currentSyncedTime;

    if (remaining <= 0) {
      Future.microtask(_endAndGoToNotScanned);
    }

    final isExpired = remaining <= 0;
    final pctLeft = isExpired ? 0.0 : (remaining / 60.0).clamp(0.0, 1.0);
    final timerColor = remaining > 20
        ? AppColors.success
        : remaining > 10
            ? AppColors.warning
            : p.danger;

    final flagCount = state.flags?.flagsCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Attendance Session'),
        automaticallyImplyLeading: false,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          // Fully scroll-adaptive: nothing has a fixed height, so content can
          // never overflow regardless of viewport size.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stats row
                _StatRow(children: [
                  StatsCard(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scans',
                    value: '${state.scans?.count ?? 0}',
                    accent: p.brand,
                  ),
                  StatsCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Flags',
                    value: '$flagCount',
                    accent: flagCount > 0 ? p.danger : p.textMuted,
                  ),
                  StatsCard(
                    icon: Icons.timer_rounded,
                    label: 'Remaining Time',
                    value: isExpired ? 'Expired' : '${remaining}s',
                    accent: timerColor,
                  ),
                ]),
                const SizedBox(height: 14),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pctLeft,
                    minHeight: 8,
                    backgroundColor: p.border,
                    valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  ),
                ),
                const SizedBox(height: 14),

                // QR card — centered, adaptive, sized to fit the window.
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _QrCard(
                      isExpired: isExpired,
                      sessionId: qr.sessionId,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                PrimaryButton(
                  label: 'Save & Close QR Now',
                  icon: Icons.stop_circle_rounded,
                  height: 50,
                  color: p.danger,
                  onPressed: _endAndGoToNotScanned,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final bool isExpired;
  final String sessionId;
  const _QrCard({required this.isExpired, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: p.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // QR scales with the available width and clamps to a compact range
          // so the whole page fits a typical browser window — fully adaptive.
          final qrSize = (c.maxWidth - 64).clamp(160.0, 300.0);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired ? 'Session Expired' : 'Scan to Mark Attendance',
                  textAlign: TextAlign.center,
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isExpired ? p.danger : p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'The attendance window has closed.'
                      : 'Students point their app camera at this code.',
                  textAlign: TextAlign.center,
                  style: context.tt.bodySmall?.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: p.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: isExpired
                      ? SizedBox(
                          width: qrSize,
                          height: qrSize,
                          child: Center(
                            child: Icon(Icons.qr_code_rounded,
                                size: qrSize * 0.28, color: p.border),
                          ),
                        )
                      : QrImageView(data: sessionId, size: qrSize),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<Widget> children;
  const _StatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - gap * (children.length - 1)) / children.length;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}
