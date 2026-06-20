import 'package:flutter/material.dart';

import '../core/config/feature_flags.dart';
import '../i18n/strings.g.dart';

/// A primary navigation tab in the app shell.
///
/// The declaration order here is the canonical tab order. Inbox is the fixed
/// home and is always present; every other tab is gated by a build-time
/// [FeatureFlags] constant, so a disabled screen is compiled out (its router
/// branch is dropped behind a `const` `if`), not merely hidden at runtime.
///
/// [enabledTabs] — the tabs that survived the flags, in order — is the SINGLE
/// list both the router (StatefulShell branches) and the shell (NavigationRail /
/// bottom-bar destinations) build from, so their indices always line up no
/// matter which tabs are off.
enum ShellTab {
  inbox,
  calendar,
  spaces,
  satori,
  contacts;

  /// Build-time visibility. Inbox is never hidden (the app needs a home).
  bool get enabled => switch (this) {
        ShellTab.inbox => true,
        ShellTab.calendar => FeatureFlags.calendar,
        ShellTab.spaces => FeatureFlags.spaces,
        ShellTab.satori => FeatureFlags.satori,
        ShellTab.contacts => FeatureFlags.contacts,
      };

  /// The branch's root location (matches the GoRoute paths in `router.dart`).
  String get location => switch (this) {
        ShellTab.inbox => '/inbox',
        ShellTab.calendar => '/calendar',
        ShellTab.spaces => '/spaces',
        ShellTab.satori => '/satori',
        ShellTab.contacts => '/contacts',
      };

  IconData get icon => switch (this) {
        ShellTab.inbox => Icons.inbox_outlined,
        ShellTab.calendar => Icons.calendar_today_outlined,
        ShellTab.spaces => Icons.folder_outlined,
        ShellTab.satori => Icons.auto_awesome_outlined,
        ShellTab.contacts => Icons.contacts_outlined,
      };

  IconData get selectedIcon => switch (this) {
        ShellTab.inbox => Icons.inbox,
        ShellTab.calendar => Icons.calendar_today,
        ShellTab.spaces => Icons.folder,
        ShellTab.satori => Icons.auto_awesome,
        ShellTab.contacts => Icons.contacts,
      };

  String get label => switch (this) {
        ShellTab.inbox => t.inbox.title,
        ShellTab.calendar => t.calendar.title,
        ShellTab.spaces => t.spaces.title,
        ShellTab.satori => t.satori.title,
        ShellTab.contacts => t.contacts.title,
      };
}

/// The tabs enabled by the current build's [FeatureFlags], in canonical order.
/// Drives both the router's shell branches and the shell's destinations.
final List<ShellTab> enabledTabs =
    ShellTab.values.where((t) => t.enabled).toList(growable: false);
