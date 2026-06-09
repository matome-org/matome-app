import 'package:flutter/material.dart';

/// Generic centered-label placeholder for shell routes whose real content
/// lands in Wave 3. Keeps the navigation tree complete and testable now.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
          ],
          Text(title, style: theme.textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
