import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Centered empty-state composition shared by list and catalog surfaces.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.iconSize = 44,
    this.iconColor,
    this.titleStyle,
    this.messageStyle,
    this.padding = const EdgeInsets.all(24),
    this.titleTextAlign = TextAlign.center,
    this.messageTextAlign = TextAlign.center,
  });

  final IconData icon;
  final String title;
  final String? message;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final EdgeInsetsGeometry padding;
  final TextAlign titleTextAlign;
  final TextAlign messageTextAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = this.message;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor ?? colors.textMuted),
            SizedBox(height: context.spacing.sm),
            Text(
              title,
              textAlign: titleTextAlign,
              style:
                  titleStyle ??
                  TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
            ),
            if (message != null) ...[
              SizedBox(height: context.spacing.xxs),
              Text(
                message,
                textAlign: messageTextAlign,
                style:
                    messageStyle ??
                    TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
