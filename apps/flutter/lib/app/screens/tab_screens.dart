import 'package:flutter/material.dart';

import '../../features/details/details_screen.dart';
import '../../features/spaces/space_detail_screen.dart' as spaces;
import '../../features/spaces/spaces_screen.dart' as spaces;
import '../../i18n/strings.g.dart';
import 'placeholder_screen.dart';

/// Wave-3 placeholder bodies for the tab roots and per-tab stack routes.
/// Each is a thin wrapper around [PlaceholderScreen] with the right i18n title;
/// real content lands in Wave 3. The Inbox root reuses the existing lab
/// `HomeScreen` (wired in the router), so it is not duplicated here.

/// Spaces tab root (S5, #784): the real Spaces list/grid with create + delete.
class SpacesScreen extends StatelessWidget {
  const SpacesScreen({super.key});
  @override
  Widget build(BuildContext context) => const spaces.SpacesScreen();
}

class SatoriScreen extends StatelessWidget {
  const SatoriScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: t.satori.title, icon: Icons.auto_awesome);
}

/// Recording details (S2, #781), reachable as `/inbox/:id` and `/calendar/:id`.
class RecordingDetailScreen extends StatelessWidget {
  const RecordingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DetailsScreen(id: id);
}

/// Space details (S5, #784), reachable as `/spaces/:spaceId`. Lists the
/// recordings assigned to the workspace.
class SpaceDetailScreen extends StatelessWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context) =>
      spaces.SpaceDetailScreen(spaceId: spaceId);
}

/// Recording within a space (S2, #781), reachable as `/spaces/recording/:id`
/// (the migration's `/explore/recording/:id` slot).
class SpaceRecordingScreen extends StatelessWidget {
  const SpaceRecordingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DetailsScreen(id: id);
}
