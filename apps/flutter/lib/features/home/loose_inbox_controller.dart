import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/providers.dart';
import 'inbox_controller.dart';
import 'inbox_effective_view.dart';
import 'inbox_item.dart';

/// Drives the LOOSE half of the W3 Inbox VIEW (local-first-spaces #102 W3,
/// ADR-0006 §1): bare items whose effective space is NULL — a recording with no
/// matome and no space ([RecordingsDao.getLooseRecordings]).
///
/// Gated behind [FeatureFlags.localFirstSpaces]: with the flag OFF this
/// controller publishes an EMPTY list and never queries — the Inbox stays the
/// matome-only list it ships as today (flag-off byte-unchanged). With the flag
/// ON it loads the loose recordings, then routes each through the ONE resolver
/// ([inboxLooseItems] → [EffectiveSpace.effectiveSpaceId]) so the membership
/// predicate is computed in exactly one place, never inline.
///
/// Display source is ALWAYS Drift. It re-reads whenever the recording-level
/// [inboxControllerProvider] emits (a loose capture, a triage move, a Core
/// reconcile) so a freshly-captured loose item surfaces without re-running Core
/// sync — mirroring [MatomeInboxController]'s listen wiring.
class LooseInboxController
    extends StateNotifier<AsyncValue<List<InboxItem>>> {
  LooseInboxController(this._ref) : super(const AsyncValue.loading()) {
    if (!FeatureFlags.localFirstSpaces) {
      // Flag OFF: the loose lane does not exist. Publish an empty, settled list
      // and do nothing else — the home screen renders matomes only, unchanged.
      state = const AsyncValue.data(<InboxItem>[]);
      return;
    }
    _ref.listen<AsyncValue<List<InboxItem>>>(
      inboxControllerProvider,
      (_, _) => reloadFromLocal(),
    );
    reloadFromLocal();
  }

  final Ref _ref;

  RecordingsDao get _dao => _ref.read(recordingsDaoProvider);

  Future<List<InboxItem>> _loadItems() async {
    final rows = await _dao.getLooseRecordings();
    // Pair each item with its SOURCE row so the resolver-confirm reads the row's
    // REAL membership, not constant nulls. `getLooseRecordings` narrows to
    // `matomeId IS NULL AND workspaceId IS NULL`, so the confirm normally passes
    // every row — but routing the row's ACTUAL `workspaceId` (a loose row has no
    // matome wrapper, so the matome-space side is genuinely NULL) through the
    // ONE resolver makes the guard REAL: a row that slipped in with a non-null
    // `workspaceId` resolves to a non-null effective space and is correctly
    // EXCLUDED from the loose Inbox, instead of the previous inert no-op (#74712,
    // spec R1.2 — never an inline re-derivation).
    final byId = <String, RecordingRow>{for (final row in rows) row.id: row};
    final items = rows.map(InboxItem.fromRow).toList(growable: false);
    return inboxLooseItems(
      items,
      // A loose recording has no matome wrapper, so its matome-space side is
      // genuinely NULL — the resolver then keys off the row's own workspaceId.
      matomeSpaceIdOf: (_) => null,
      workspaceIdOf: (item) => byId[item.id]?.workspaceId,
    );
  }

  /// Re-reads the loose Inbox items from Drift and publishes them. A no-op (kept
  /// empty) when the flag is OFF.
  Future<void> reloadFromLocal() async {
    if (!FeatureFlags.localFirstSpaces) return;
    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }
}

final looseInboxControllerProvider = StateNotifierProvider<LooseInboxController,
    AsyncValue<List<InboxItem>>>(
  (ref) => LooseInboxController(ref),
);
