import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';

/// #1468: the inbox (cards ↔ table) and files (grid ↔ table) view preferences
/// must persist via the secure [SettingsStore] and rehydrate on the next launch.
/// These controllers mirror ThemeController / LocaleController.
void main() {
  ProviderContainer containerWith(SettingsStore store) {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('inboxViewProvider', () {
    test('defaults to cards when nothing is stored', () {
      final c = containerWith(InMemorySettingsStore());
      expect(c.read(inboxViewProvider), InboxView.cards);
    });

    test('setView writes the choice to the store', () async {
      final store = InMemorySettingsStore();
      final c = containerWith(store);

      await c.read(inboxViewProvider.notifier).setView(InboxView.table);

      expect(c.read(inboxViewProvider), InboxView.table);
      expect(await store.read('matome.inbox_view'), 'table');
    });

    test('round-trips: a stored choice rehydrates a fresh container', () async {
      final store = InMemorySettingsStore();
      final first = containerWith(store);
      await first.read(inboxViewProvider.notifier).setView(InboxView.table);

      // Simulate a relaunch: a brand-new container reading the same store.
      final reloaded = containerWith(store);
      // First read instantiates the controller (which kicks off async
      // _hydrate); pump the event queue so the stored value lands.
      expect(reloaded.read(inboxViewProvider), InboxView.cards);
      await Future<void>.delayed(Duration.zero);

      expect(reloaded.read(inboxViewProvider), InboxView.table);
    });
  });

  group('filesViewProvider', () {
    test('defaults to grid when nothing is stored', () {
      final c = containerWith(InMemorySettingsStore());
      expect(c.read(filesViewProvider), FilesView.grid);
    });

    test('setView writes the choice to the store', () async {
      final store = InMemorySettingsStore();
      final c = containerWith(store);

      await c.read(filesViewProvider.notifier).setView(FilesView.table);

      expect(c.read(filesViewProvider), FilesView.table);
      expect(await store.read('matome.files_view'), 'table');
    });

    test('round-trips: a stored choice rehydrates a fresh container', () async {
      final store = InMemorySettingsStore();
      final first = containerWith(store);
      await first.read(filesViewProvider.notifier).setView(FilesView.table);

      final reloaded = containerWith(store);
      expect(reloaded.read(filesViewProvider), FilesView.grid);
      await Future<void>.delayed(Duration.zero);

      expect(reloaded.read(filesViewProvider), FilesView.table);
    });
  });
}
