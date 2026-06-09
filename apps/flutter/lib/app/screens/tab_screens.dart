import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import 'placeholder_screen.dart';

/// Wave-3 placeholder bodies for the tab roots and per-tab stack routes.
/// Each is a thin wrapper around [PlaceholderScreen] with the right i18n title;
/// real content lands in Wave 3. The Inbox root reuses the existing lab
/// `HomeScreen` (wired in the router), so it is not duplicated here.

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: t.calendar.title, icon: Icons.calendar_today);
}

class SpacesScreen extends StatelessWidget {
  const SpacesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: t.spaces.title, icon: Icons.folder_outlined);
}

class SatoriScreen extends StatelessWidget {
  const SatoriScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: t.satori.title, icon: Icons.auto_awesome);
}

/// Recording details, reachable as `/inbox/:id` and `/calendar/:id`.
class RecordingDetailScreen extends StatelessWidget {
  const RecordingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${t.recording.title} #$id')),
      body: PlaceholderScreen(title: t.details.summary, subtitle: 'id: $id'),
    );
  }
}

/// Space details, reachable as `/spaces/:spaceId`.
class SpaceDetailScreen extends StatelessWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.spaces.title)),
      body: PlaceholderScreen(title: t.spaces.title, subtitle: 'space: $spaceId'),
    );
  }
}

/// Recording within a space, reachable as `/spaces/recording/:id`.
class SpaceRecordingScreen extends StatelessWidget {
  const SpaceRecordingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${t.recording.title} #$id')),
      body: PlaceholderScreen(title: t.details.notes, subtitle: 'id: $id'),
    );
  }
}
