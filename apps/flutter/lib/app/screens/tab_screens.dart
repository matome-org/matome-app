import 'package:flutter/material.dart';

import '../../features/contacts/contacts_screen.dart' as contacts;
import '../../features/details/details_screen.dart';
import '../../features/spaces/space_detail_screen.dart' as spaces;
import '../../features/spaces/spaces_screen.dart' as spaces;
import 'satori_screen.dart' as satori;

/// Thin tab-root / per-tab stack wrappers that adapt the real feature screens
/// onto the shell's route slots. The Inbox root reuses the existing lab
/// `HomeScreen` (wired directly in the router), so it is not duplicated here.

/// Spaces tab root (S5, #784): the real Spaces list/grid with create + delete.
class SpacesScreen extends StatelessWidget {
  const SpacesScreen({super.key});
  @override
  Widget build(BuildContext context) => const spaces.SpacesScreen();
}

/// Satori tab root (S6, #785): the roadmap "under construction" screen.
class SatoriScreen extends StatelessWidget {
  const SatoriScreen({super.key});
  @override
  Widget build(BuildContext context) => const satori.SatoriScreen();
}

/// Contacts tab root (#1374): the owner's manual directory with create / edit /
/// delete. Manual entry only — linked-user / sharing / ACL is deferred (#1373).
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});
  @override
  Widget build(BuildContext context) => const contacts.ContactsScreen();
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
