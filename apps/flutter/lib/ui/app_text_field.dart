import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Labeled text field matching Matome form styling.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.autofocus = false,
    this.autocorrect = false,
    this.enableSuggestions,
    this.prefixIcon,
    this.suffixIcon,
    this.isDense,
    this.contentPadding,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textAlignVertical,
    this.style,
    this.hintStyle,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool autocorrect;
  final bool? enableSuggestions;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool? isDense;
  final EdgeInsetsGeometry? contentPadding;
  final int? maxLines;
  final int? minLines;

  /// Hard character cap (mirrors a server-side length rule). The built-in
  /// counter is hidden so the field stays compact in dialogs.
  final int? maxLength;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final field = TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textAlignVertical: textAlignVertical,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions ?? !obscure,
      autofillHints: autofillHints,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: style ?? typography.bodySmall.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        isDense: isDense,
        // Hide the built-in character counter — the cap is enforced silently.
        counterText: maxLength == null ? null : '',
        hintText: hint,
        hintStyle:
            hintStyle ?? typography.bodySmall.copyWith(color: colors.textMuted),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            contentPadding ??
            EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.accent),
        ),
      ),
    );

    final label = this.label;
    if (label == null || label.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: typography.label.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: spacing.xs),
        field,
      ],
    );
  }
}
