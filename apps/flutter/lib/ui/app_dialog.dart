import 'package:flutter/material.dart';

/// Thin app catalog wrapper for confirmation and form dialogs.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: backgroundColor,
      title: title,
      content: content,
      actions: actions,
    );
  }
}
