import 'package:flutter/material.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/contacts/contact_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tab_screens.dart' as tab_screens;

/// Canonical route target for `/inbox/settings`.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

/// Canonical route target for `/calendar`.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) => const CalendarScreen();
}

/// Canonical route target for `/spaces`.
class SpacesPage extends StatelessWidget {
  const SpacesPage({super.key});

  @override
  Widget build(BuildContext context) => const tab_screens.SpacesScreen();
}

/// Canonical route target for `/spaces/:spaceId`.
class SpaceDetailPage extends StatelessWidget {
  const SpaceDetailPage({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context) =>
      tab_screens.SpaceDetailScreen(spaceId: spaceId);
}

/// Canonical route target for `/contacts`.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) => const tab_screens.ContactsScreen();
}

/// Canonical route target for `/contacts/:id`.
class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => ContactDetailScreen(id: id);
}
