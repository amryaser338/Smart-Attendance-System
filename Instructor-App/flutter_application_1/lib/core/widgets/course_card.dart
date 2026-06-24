import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';
import '../theme/app_theme.dart';

/// Premium course card for the dashboard: course-code badge, course name,
/// a section count, and tappable section chips with arrow navigation.
class CourseCard extends StatelessWidget {
  final String courseId;
  final String courseName;
  final List<String> sections;
  final void Function(String sectionId) onSectionTap;

  const CourseCard({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.sections,
    required this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: p.brandContainer,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.brand,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    courseId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    courseName,
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.onBrandContainer,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.layers_rounded, size: 15, color: p.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${sections.length} ${sections.length == 1 ? 'SECTION' : 'SECTIONS'}',
                      style: context.tt.labelSmall?.copyWith(
                        color: p.textMuted,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final sec in sections)
                      _SectionChip(
                        label: sec,
                        onTap: () => onSectionTap(sec),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SectionChip({required this.label, required this.onTap});

  @override
  State<_SectionChip> createState() => _SectionChipState();
}

class _SectionChipState extends State<_SectionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? p.brand : p.brandContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
                color: active ? p.brand : p.brand.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded,
                  size: 16, color: active ? Colors.white : p.brand),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? Colors.white : p.brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: active ? Colors.white : p.brand),
            ],
          ),
        ),
      ),
    );
  }
}
