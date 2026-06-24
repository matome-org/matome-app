import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/reading_pane.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// #1539: the GLOBAL reading-pane position must persist via the secure
/// [SettingsStore] and rehydrate on the next launch, defaulting to
/// [ReadingPanePosition.right]. Mirrors ThemeController / inboxViewProvider.
void main() {
  ProviderContainer containerWith(SettingsStore store) {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('readingPaneProvider', () {
    test('defaults to right when nothing is stored', () {
      final c = containerWith(InMemorySettingsStore());
      expect(c.read(readingPaneProvider), ReadingPanePosition.right);
    });

    test('setPosition writes the choice to the store and updates state',
        () async {
      final store = InMemorySettingsStore();
      final c = containerWith(store);

      await c
          .read(readingPaneProvider.notifier)
          .setPosition(ReadingPanePosition.off);

      expect(c.read(readingPaneProvider), ReadingPanePosition.off);
      expect(await store.read('matome.reading_pane'), 'off');
    });

    test('round-trips: a stored choice rehydrates a fresh container', () async {
      final store = InMemorySettingsStore();
      final first = containerWith(store);
      await first
          .read(readingPaneProvider.notifier)
          .setPosition(ReadingPanePosition.off);

      // Simulate a relaunch: a brand-new container reading the same store.
      final reloaded = containerWith(store);
      // First read instantiates the controller (which kicks off async
      // _hydrate); pump the event queue so the stored value lands.
      expect(reloaded.read(readingPaneProvider), ReadingPanePosition.right);
      await Future<void>.delayed(Duration.zero);

      expect(reloaded.read(readingPaneProvider), ReadingPanePosition.off);
    });

    test('an unknown / stale stored value hydrates to right', () async {
      final store = InMemorySettingsStore({'matome.reading_pane': 'bottom'});
      final c = containerWith(store);

      // Instantiate + pump _hydrate; the unknown value must be ignored.
      expect(c.read(readingPaneProvider), ReadingPanePosition.right);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(readingPaneProvider), ReadingPanePosition.right);
    });
  });
}
