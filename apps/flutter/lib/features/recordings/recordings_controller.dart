import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'recording.dart';

/// Async list of the signed-in user's recordings.
///
/// Surfaces loading/error/data via `AsyncValue<List<Recording>>`. The UI
/// (#765) watches this; `refresh()` re-fetches.
class RecordingsController extends StateNotifier<AsyncValue<List<Recording>>> {
  RecordingsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _ref.read(recordingsRepositoryProvider).fetchRecordings(),
    );
  }

  Future<void> refresh() => load();
}

final recordingsControllerProvider = StateNotifierProvider<RecordingsController,
    AsyncValue<List<Recording>>>(
  (ref) => RecordingsController(ref),
);
