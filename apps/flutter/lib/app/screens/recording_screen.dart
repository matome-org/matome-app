import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';

/// Recording capture screen, presented as a fullscreen modal (route
/// `/recording`, pushed from the center mic FAB). Mirrors RN
/// `app/recording.tsx` presentation. Audio capture is out of scope for F1
/// (lands in a later wave); this is the placeholder shell with a close action.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.recording.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(t.recording.ready, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(t.recording.startHint, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
