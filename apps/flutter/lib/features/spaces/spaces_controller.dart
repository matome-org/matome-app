import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import 'space_card.dart';

/// Drives the Spaces tab (S5, #784): offline-first list of workspaces with their
/// recording counts, backed by Drift.
///
/// Display source is ALWAYS Drift. Mirrors apps/mobile `processes/spacesData.ts`
/// (`fetchSpacesData`): load workspaces, then count recordings in each. Create
/// and delete go straight to [WorkspacesDao]; delete returns the workspace's
/// recordings to the Inbox (`workspaceId = NULL`), mirroring `deleteWorkspace`.
///
/// Workspaces are local-only for S5 — Drift is the source of truth and no Core
/// `workspaces` endpoint is wired in the repository. (Inbox/recording sync is
/// handled separately by S1.)
class SpacesController extends StateNotifier<AsyncValue<List<SpaceCard>>> {
  SpacesController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  RecordingsDao get _recordingsDao => _ref.read(recordingsDaoProvider);

  /// Re-reads workspaces + per-workspace recording counts from Drift.
  /// Ports `fetchSpacesData`.
  Future<List<SpaceCard>> _loadCards() async {
    final workspaces = await _workspacesDao.getWorkspaces();
    final cards = <SpaceCard>[];
    for (final ws in workspaces) {
      final recordings = await _recordingsDao.getRecordingsInWorkspace(ws.id);
      cards.add(
        SpaceCard(
          id: ws.id,
          name: ws.name,
          count: recordings.length,
          isLocal: ws.isLocal == 1,
        ),
      );
    }
    return cards;
  }

  /// (Re)load the list and publish it as the new state.
  Future<void> load() async {
    state = await AsyncValue.guard(_loadCards);
  }

  /// Create a space (workspace) and refresh. Mirrors `createWorkspace`. A blank
  /// name is ignored (no-op), matching the RN container's guard.
  Future<void> createSpace(String name) async {
    if (name.trim().isEmpty) return;
    AppLog.event(LogCat.action, 'createSpace');
    await _workspacesDao.createWorkspace(name);
    await load();
  }

  /// Delete a space and refresh. Its recordings return to the Inbox
  /// (`workspaceId = NULL`) inside the DAO transaction. Mirrors
  /// `deleteWorkspace`.
  Future<void> deleteSpace(String id) async {
    AppLog.event(LogCat.action, 'deleteSpace $id');
    await _workspacesDao.deleteWorkspace(id);
    await load();
  }
}

final spacesControllerProvider =
    StateNotifierProvider<SpacesController, AsyncValue<List<SpaceCard>>>(
      (ref) => SpacesController(ref),
    );
