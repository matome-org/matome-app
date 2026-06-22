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
  contacts,
  files;

  /// Build-time visibility. Inbox is never hidden (the app needs a home).
  ///
  /// [ShellTab.files] is the graduated-shell destination (DR-002, #1467) and is
  /// ONLY a navigable shell branch under [FeatureFlags.newNavShell]; under the
  /// legacy shell `/files` stays a root-level deep-link route, so `files` is not
  /// "enabled" as a legacy tab.
  bool get enabled => switch (this) {
        ShellTab.inbox => true,
        ShellTab.calendar => FeatureFlags.calendar,
        ShellTab.spaces => FeatureFlags.spaces,
        ShellTab.satori => FeatureFlags.satori,
        ShellTab.contacts => FeatureFlags.contacts,
        ShellTab.files => FeatureFlags.newNavShell,
      };

  /// The branch's root location (matches the GoRoute paths in `router.dart`).
  String get location => switch (this) {
        ShellTab.inbox => '/inbox',
        ShellTab.calendar => '/calendar',
        ShellTab.spaces => '/spaces',
        ShellTab.satori => '/satori',
        ShellTab.contacts => '/contacts',
        ShellTab.files => '/files',
      };

  IconData get icon => switch (this) {
        ShellTab.inbox => Icons.inbox_outlined,
        ShellTab.calendar => Icons.calendar_today_outlined,
        ShellTab.spaces => Icons.folder_outlined,
        ShellTab.satori => Icons.auto_awesome_outlined,
        ShellTab.contacts => Icons.contacts_outlined,
        ShellTab.files => Icons.description_outlined,
      };

  IconData get selectedIcon => switch (this) {
        ShellTab.inbox => Icons.inbox,
        ShellTab.calendar => Icons.calendar_today,
        ShellTab.spaces => Icons.folder,
        ShellTab.satori => Icons.auto_awesome,
        ShellTab.contacts => Icons.contacts,
        ShellTab.files => Icons.description,
      };

  String get label => switch (this) {
        ShellTab.inbox => t.inbox.title,
        ShellTab.calendar => t.calendar.title,
        ShellTab.spaces => t.spaces.title,
        ShellTab.satori => t.satori.title,
        ShellTab.contacts => t.contacts.title,
        ShellTab.files => t.files.title,
      };
}

/// The tabs enabled by the current build's [FeatureFlags], in canonical order.
/// Drives the LEGACY shell's destinations (NavigationRail / bottom-bar).
final List<ShellTab> enabledTabs = ShellTab.values
    .where((t) => t.enabled && t != ShellTab.files)
    .toList(growable: false);

/// The single ordered list of shell branches the router AND the active shell
/// build from, so `StatefulNavigationShell.currentIndex` / `goBranch(index)`
/// always line up no matter which tabs the flags drop.
///
/// - [FeatureFlags.newNavShell] **OFF** → the shipped order
///   (inbox · calendar · spaces · satori · contacts, flags applied). Identical
///   to [enabledTabs], so the legacy shell is untouched.
/// - **ON** → the DR-002 order (inbox · calendar · files · contacts · spaces),
///   Satori EXCLUDED (its route is compiled out in `router.dart`) and `/files`
///   promoted to a branch.
///
/// Inbox is always present (the app needs a home). The router gates each
/// branch by the SAME predicate ([ShellTab.enabled]) so the branch list here
/// and the route tree there stay aligned.
List<ShellTab> get shellBranches {
  if (!FeatureFlags.newNavShell) return enabledTabs;
  const order = [
    ShellTab.inbox,
    ShellTab.calendar,
    ShellTab.files,
    ShellTab.contacts,
    ShellTab.spaces,
  ];
  return order.where((t) => t.enabled).toList(growable: false);
}
