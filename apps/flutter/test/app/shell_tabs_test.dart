import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/app/shell_tabs.dart';
import 'package:matome_flutter/core/config/feature_flags.dart';

/// These hold under ANY `--dart-define` flag combination, so the same file
/// proves the wiring whether run with the default (all tabs on) or with a flag
/// forced off, e.g.:
///   flutter test --dart-define=ff.screens.satori=false test/app/shell_tabs_test.dart
void main() {
  test('inbox is always enabled — the app needs a home', () {
    expect(ShellTab.inbox.enabled, isTrue);
    expect(enabledTabs, contains(ShellTab.inbox));
    expect(enabledTabs.first, ShellTab.inbox);
  });

  test('a tab appears in enabledTabs iff its build-time flag is on', () {
    // [enabledTabs] is the LEGACY shell's destination list; the graduated-shell
    // `files` tab is never one of its destinations (it lives in [shellBranches]
    // under the new-shell flag), so exclude it from this legacy invariant.
    for (final tab in ShellTab.values.where((t) => t != ShellTab.files)) {
      expect(
        enabledTabs.contains(tab),
        tab.enabled,
        reason: '${tab.name} presence must match its flag (${tab.enabled})',
      );
    }
    expect(enabledTabs, isNot(contains(ShellTab.files)));
  });

  test('the secondary tabs track their FeatureFlags constants', () {
    expect(ShellTab.calendar.enabled, FeatureFlags.calendar);
    expect(ShellTab.spaces.enabled, FeatureFlags.spaces);
    expect(ShellTab.satori.enabled, FeatureFlags.satori);
    expect(ShellTab.contacts.enabled, FeatureFlags.contacts);
  });

  test('enabledTabs is the canonical order filtered by the flags', () {
    expect(
      enabledTabs,
      ShellTab.values.where((t) => t.enabled && t != ShellTab.files).toList(),
    );
  });

  test('every tab maps to a distinct location matching the router paths', () {
    const expected = {
      ShellTab.inbox: '/inbox',
      ShellTab.calendar: '/calendar',
      ShellTab.spaces: '/spaces',
      ShellTab.satori: '/satori',
      ShellTab.contacts: '/contacts',
      ShellTab.files: '/files',
    };
    for (final tab in ShellTab.values) {
      expect(tab.location, expected[tab]);
    }
    final locations = ShellTab.values.map((t) => t.location).toSet();
    expect(locations, hasLength(ShellTab.values.length));
  });

  // shellBranches is the SINGLE ordered list the router branches and the active
  // shell's destinations both derive from. Its shape tracks the new-shell flag:
  //  - OFF (the default build) → equals enabledTabs, satori is a branch, files
  //    is NOT a branch (/files stays a root deep-link route).
  //  - ON → the DR-002 order (inbox · calendar · files · contacts · spaces),
  //    satori EXCLUDED (its route is compiled out), files PROMOTED to a branch.
  test('shellBranches tracks the new-shell flag', () {
    expect(ShellTab.files.enabled, FeatureFlags.newNavShell);
    if (FeatureFlags.newNavShell) {
      expect(shellBranches, isNot(contains(ShellTab.satori)));
      expect(shellBranches, contains(ShellTab.files));
      // DR-002 order (filtered by the per-tab flags).
      const order = [
        ShellTab.inbox,
        ShellTab.calendar,
        ShellTab.files,
        ShellTab.contacts,
        ShellTab.spaces,
      ];
      expect(shellBranches, order.where((t) => t.enabled).toList());
    } else {
      expect(shellBranches, enabledTabs);
      expect(shellBranches, isNot(contains(ShellTab.files)));
    }
  });
}
