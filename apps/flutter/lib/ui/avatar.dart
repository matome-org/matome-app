import 'package:flutter/material.dart';

/// Circular avatar surface for icons, initials, and progress/status glyphs.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.backgroundColor,
    this.foregroundColor,
    this.size = 36,
    this.icon,
    this.initials,
    this.child,
    this.semanticLabel,
  });

  final Color backgroundColor;
  final Color? foregroundColor;
  final double size;
  final IconData? icon;
  final String? initials;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground =
        foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final resolvedChild =
        child ??
        (icon != null
            ? Icon(icon, size: size * 0.5, color: foreground)
            : Text(
                initials ?? '',
                style: TextStyle(
                  color: foreground,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                ),
              ));
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: resolvedChild,
    );

    final label = semanticLabel;
    if (label == null) return avatar;
    return Semantics(label: label, child: avatar);
  }
}
