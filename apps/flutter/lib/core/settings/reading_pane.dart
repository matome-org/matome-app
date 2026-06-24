import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/master_detail_scaffold.dart';
import '../providers.dart';
import 'settings_store.dart';

/// The single GLOBAL key under which the reading-pane position is persisted.
const _readingPaneKey = 'matome.reading_pane';

/// Persisted controller for the GLOBAL [ReadingPanePosition] (#1539), hydrated
/// from / written to the secure [SettingsStore]. Mirrors [InboxViewController]
/// exactly: default is [ReadingPanePosition.right] until the stored value loads,
/// and an unknown / stale stored value falls back to the same default.
///
/// This is GLOBAL — there are no per-surface keys. Collection surfaces consume
/// [readingPaneProvider] in later waves (W2–W4); nothing wires it in here.
class ReadingPaneController extends StateNotifier<ReadingPanePosition> {
  ReadingPaneController(this._store) : super(ReadingPanePosition.right) {
    _hydrate();
  }

  final SettingsStore _store;

  Future<void> _hydrate() async {
    final position = _parse(await _store.read(_readingPaneKey));
    if (position != null && mounted) state = position;
  }

  Future<void> setPosition(ReadingPanePosition position) async {
    state = position;
    await _store.write(_readingPaneKey, position.name);
  }

  static ReadingPanePosition? _parse(String? raw) {
    for (final p in ReadingPanePosition.values) {
      if (p.name == raw) return p;
    }
    return null;
  }
}

final readingPaneProvider =
    StateNotifierProvider<ReadingPaneController, ReadingPanePosition>(
  (ref) => ReadingPaneController(ref.watch(settingsStoreProvider)),
);
