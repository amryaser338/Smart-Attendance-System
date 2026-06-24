import 'package:flutter/material.dart';
import '../theme/adaptive_colors.dart';

/// Labeled text field with the portal's input styling (label sits above the
/// field, not floating). Pure presentation — it forwards everything to a
/// [TextFormField] so existing controllers/validators work unchanged.
class ModernInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const ModernInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.tt.labelLarge
              ?.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autocorrect: autocorrect,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Labeled dropdown matching [ModernInput]'s visual language.
class ModernDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final IconData? prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const ModernDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.hint,
    this.prefixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.tt.labelLarge
              ?.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: p.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.textMuted),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          ),
        ),
      ],
    );
  }
}
