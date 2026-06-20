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
    for (final tab in ShellTab.values) {
      expect(
        enabledTabs.contains(tab),
        tab.enabled,
        reason: '${tab.name} presence must match its flag (${tab.enabled})',
      );
    }
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
      ShellTab.values.where((t) => t.enabled).toList(),
    );
  });

  test('every tab maps to a distinct location matching the router paths', () {
    const expected = {
      ShellTab.inbox: '/inbox',
      ShellTab.calendar: '/calendar',
      ShellTab.spaces: '/spaces',
      ShellTab.satori: '/satori',
      ShellTab.contacts: '/contacts',
    };
    for (final tab in ShellTab.values) {
      expect(tab.location, expected[tab]);
    }
    final locations = ShellTab.values.map((t) => t.location).toSet();
    expect(locations, hasLength(ShellTab.values.length));
  });
}
