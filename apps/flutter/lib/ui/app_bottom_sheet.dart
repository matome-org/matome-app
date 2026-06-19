import 'package:flutter/material.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(context: context, builder: builder);
}

/// Bottom-sheet shell for list/action sheets that share SafeArea + min column.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.children,
    this.title,
    this.titlePadding = const EdgeInsets.fromLTRB(20, 18, 20, 8),
    this.bottomPadding = 8,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget? title;
  final List<Widget> children;
  final EdgeInsetsGeometry titlePadding;
  final double bottomPadding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final title = this.title;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (title != null) Padding(padding: titlePadding, child: title),
          ...children,
          if (bottomPadding > 0) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
