import 'package:flutter/material.dart';

/// Filled action button wrapper for the app catalog.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null;

  const PrimaryButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
    this.style,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: icon,
        label: child,
      );
    }

    return FilledButton(onPressed: onPressed, style: style, child: child);
  }
}

/// Text action button wrapper for the app catalog.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : icon = null;

  const AppTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
    this.style,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        style: style,
        icon: icon,
        label: child,
      );
    }

    return TextButton(onPressed: onPressed, style: style, child: child);
  }
}
