import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/reading_pane.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// Per-surface reading-pane modes must persist via the secure [SettingsStore]
/// and rehydrate on the next launch, each under its OWN key
/// (`matome.reading_pane.<surface.name>`), defaulting to
/// [ReadingPaneMode.onClick]. Surfaces are independent.
void main() {
  ProviderContainer containerWith(SettingsStore store) {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('readingPaneModeProvider (per-surface)', () {
    test('defaults to onClick when nothing is stored', () {
      final c = containerWith(InMemorySettingsStore());
      for (final surface in ReadingPaneSurface.values) {
        expect(
          c.read(readingPaneModeProvider(surface)),
          ReadingPaneMode.onClick,
        );
      }
    });

    test('setMode writes the choice under the surface key and updates state',
        () async {
      final store = InMemorySettingsStore();
      final c = containerWith(store);

      await c
          .read(readingPaneModeProvider(ReadingPaneSurface.files).notifier)
          .setMode(ReadingPaneMode.always);

      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.files)),
        ReadingPaneMode.always,
      );
      expect(await store.read('matome.reading_pane.files'), 'always');
    });

    test('round-trips: a stored choice rehydrates a fresh container', () async {
      final store = InMemorySettingsStore();
      final first = containerWith(store);
      await first
          .read(readingPaneModeProvider(ReadingPaneSurface.inbox).notifier)
          .setMode(ReadingPaneMode.off);

      // Simulate a relaunch: a brand-new container reading the same store.
      final reloaded = containerWith(store);
      // First read instantiates the controller (which kicks off async
      // _hydrate); pump the event queue so the stored value lands.
      expect(
        reloaded.read(readingPaneModeProvider(ReadingPaneSurface.inbox)),
        ReadingPaneMode.onClick,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        reloaded.read(readingPaneModeProvider(ReadingPaneSurface.inbox)),
        ReadingPaneMode.off,
      );
    });

    test('an unknown / stale stored value hydrates to onClick', () async {
      final store = InMemorySettingsStore(
        {'matome.reading_pane.spaces': 'bottom'},
      );
      final c = containerWith(store);

      // Instantiate + pump _hydrate; the unknown value must be ignored.
      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.spaces)),
        ReadingPaneMode.onClick,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.spaces)),
        ReadingPaneMode.onClick,
      );
    });

    test('surfaces are independent — setting one leaves the others default',
        () async {
      final store = InMemorySettingsStore();
      final c = containerWith(store);

      await c
          .read(readingPaneModeProvider(ReadingPaneSurface.contacts).notifier)
          .setMode(ReadingPaneMode.always);

      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.contacts)),
        ReadingPaneMode.always,
      );
      // The other three surfaces keep their default.
      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.inbox)),
        ReadingPaneMode.onClick,
      );
      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.files)),
        ReadingPaneMode.onClick,
      );
      expect(
        c.read(readingPaneModeProvider(ReadingPaneSurface.spaces)),
        ReadingPaneMode.onClick,
      );
      // Only the contacts key was written.
      expect(await store.read('matome.reading_pane.contacts'), 'always');
      expect(await store.read('matome.reading_pane.inbox'), isNull);
    });

    test('two surfaces round-trip independently from the same store', () async {
      final store = InMemorySettingsStore();
      final first = containerWith(store);
      await first
          .read(readingPaneModeProvider(ReadingPaneSurface.inbox).notifier)
          .setMode(ReadingPaneMode.always);
      await first
          .read(readingPaneModeProvider(ReadingPaneSurface.files).notifier)
          .setMode(ReadingPaneMode.off);

      final reloaded = containerWith(store);
      // Touch both so their controllers hydrate.
      reloaded.read(readingPaneModeProvider(ReadingPaneSurface.inbox));
      reloaded.read(readingPaneModeProvider(ReadingPaneSurface.files));
      await Future<void>.delayed(Duration.zero);

      expect(
        reloaded.read(readingPaneModeProvider(ReadingPaneSurface.inbox)),
        ReadingPaneMode.always,
      );
      expect(
        reloaded.read(readingPaneModeProvider(ReadingPaneSurface.files)),
        ReadingPaneMode.off,
      );
    });
  });
}
