import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/master_detail_scaffold.dart';
import '../providers.dart';
import 'settings_store.dart';

/// The collection surfaces that each carry their OWN reading-pane mode.
/// One persisted key per surface (`matome.reading_pane.<surface.name>`), so the
/// Inbox / Files / Spaces / Contacts choices are independent.
enum ReadingPaneSurface { inbox, files, spaces, contacts }

/// The persisted key for a surface's reading-pane mode.
String _readingPaneKey(ReadingPaneSurface surface) =>
    'matome.reading_pane.${surface.name}';

/// Persisted controller for a single surface's [ReadingPaneMode], hydrated from
/// / written to the secure [SettingsStore]. Mirrors [InboxViewController]
/// exactly: default is [ReadingPaneMode.onClick] until the stored value loads,
/// and an unknown / stale stored value falls back to the same default.
///
/// One controller instance per [ReadingPaneSurface] via the family below; the
/// surfaces consume `readingPaneModeProvider(ReadingPaneSurface.<self>)`.
class ReadingPaneModeController extends StateNotifier<ReadingPaneMode> {
  ReadingPaneModeController(this._store, this.surface)
      : super(ReadingPaneMode.onClick) {
    _hydrate();
  }

  final SettingsStore _store;
  final ReadingPaneSurface surface;

  Future<void> _hydrate() async {
    final mode = _parse(await _store.read(_readingPaneKey(surface)));
    if (mode != null && mounted) state = mode;
  }

  Future<void> setMode(ReadingPaneMode mode) async {
    state = mode;
    await _store.write(_readingPaneKey(surface), mode.name);
  }

  static ReadingPaneMode? _parse(String? raw) {
    for (final m in ReadingPaneMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

/// Per-surface reading-pane mode. Keyed by [ReadingPaneSurface]; each surface
/// gets its own independently-persisted controller.
final readingPaneModeProvider = StateNotifierProvider.family<
    ReadingPaneModeController, ReadingPaneMode, ReadingPaneSurface>(
  (ref, surface) =>
      ReadingPaneModeController(ref.watch(settingsStoreProvider), surface),
);
