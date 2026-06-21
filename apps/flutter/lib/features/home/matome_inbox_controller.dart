import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/matome_card.dart';
import '../../core/providers.dart';
import 'inbox_controller.dart';
import 'inbox_item.dart';

/// Drives the Inbox screen (S1) under the matome-centric model (#1378): the
/// list shows **inbox matomes** (`MatomesDao.listInboxMatomeItems`, spaceId
/// NULL) instead of individual recordings.
///
/// Display source is ALWAYS Drift. `refresh()` still pulls recordings from Core
/// and upserts them via `upsertRecordingWithMatome` (recordings keep syncing
/// underneath, and each lands in a matome), then re-reads the **inbox matome**
/// list from Drift. Network errors are swallowed so the offline cache renders.
class MatomeInboxController
    extends StateNotifier<AsyncValue<List<MatomeItem>>> {
  MatomeInboxController(this._ref) : super(const AsyncValue.loading()) {
    // Keep the recording-level Inbox controller alive (it owns the upload /
    // retry / Core-reconcile pipeline) and re-read the matome list whenever it
    // emits — so a local upload (which lands a recording in an Inbox matome via
    // `upsertRecordingWithMatome`), a retry, or a reconcile surfaces the new /
    // updated matome row without the matome list having to re-run Core sync.
    _ref.listen<AsyncValue<List<InboxItem>>>(
      inboxControllerProvider,
      (_, _) => reloadFromLocal(),
    );
    refresh();
  }

  final Ref _ref;

  MatomesDao get _matomesDao => _ref.read(matomesDaoProvider);

  Future<List<MatomeItem>> _loadItems() => _matomesDao.listInboxMatomeItems();

  /// Re-reads the inbox matomes from Drift and publishes them.
  Future<void> reloadFromLocal() async {
    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }

  /// Show the cached inbox matomes immediately, then drive a Core recording
  /// sync through the recording-level controller. That sync upserts each remote
  /// recording into a matome (`upsertRecordingWithMatome`) and, on completion,
  /// fires our listener → [reloadFromLocal]. The display source is ALWAYS the
  /// Drift inbox-matome list; network failures are swallowed underneath so the
  /// offline cache still renders.
  Future<void> refresh() async {
    final cached = await AsyncValue.guard(_loadItems);
    if (!mounted) return;
    state = cached;
    await _ref.read(inboxControllerProvider.notifier).refresh();
    await reloadFromLocal();
  }

  /// File an inbox matome into [spaceId] — the triage move (ADR-0004): the
  /// matome leaves the Inbox immediately. Reloads so the row drops out.
  Future<void> fileIntoSpace(String matomeId, String spaceId) async {
    await _matomesDao.fileIntoSpace(matomeId, spaceId);
    await reloadFromLocal();
  }
}

final matomeInboxControllerProvider = StateNotifierProvider<
    MatomeInboxController, AsyncValue<List<MatomeItem>>>(
  (ref) => MatomeInboxController(ref),
);
