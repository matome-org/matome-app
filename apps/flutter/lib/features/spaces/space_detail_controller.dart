import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/recording_card.dart';
import '../../core/providers.dart';
import '../home/inbox_item.dart';

/// State for the Space detail screen (`/spaces/:spaceId`): the workspace name
/// (for the header) plus the recordings assigned to it.
class SpaceDetailState {
  const SpaceDetailState({required this.name, required this.items});

  /// Workspace name, or null if the workspace no longer exists.
  final String? name;
  final List<InboxItem> items;
}

/// Drives the Space detail screen (S5, #784). Reads the workspace + its
/// recordings from Drift (`getRecordingsInWorkspace`), mirroring the mobile
/// `app/(tabs)/explore/[spaceId].tsx`. Drift-only (offline-first).
class SpaceDetailController
    extends StateNotifier<AsyncValue<SpaceDetailState>> {
  SpaceDetailController(this._ref, this.spaceId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final String spaceId;

  Future<SpaceDetailState> _load() async {
    final workspacesDao = _ref.read(workspacesDaoProvider);
    final recordingsDao = _ref.read(recordingsDaoProvider);

    final workspace = await workspacesDao.getWorkspaceById(spaceId);
    final rows = await recordingsDao.getRecordingsInWorkspace(spaceId);
    final items = rows
        .map(
          (row) => InboxItem(
            card: RecordingCard.fromRow(row, workspaceName: workspace?.name),
            createdAt: row.createdAt,
          ),
        )
        .toList(growable: false);
    return SpaceDetailState(name: workspace?.name, items: items);
  }

  Future<void> load() async {
    final next = await AsyncValue.guard(_load);
    // Guard against a state emit after the autoDispose provider tore down (e.g.
    // the user navigated away before the load resolved).
    if (!mounted) return;
    state = next;
  }
}

/// Family keyed by the space (workspace) id.
///
/// `autoDispose` so the notifier (and its Drift load) is torn down when the
/// Space detail route is popped — mirroring [detailsControllerProvider]. Without
/// it, one notifier leaks per visited workspaceId for the app's lifetime.
final spaceDetailControllerProvider = StateNotifierProvider.autoDispose.family<
    SpaceDetailController, AsyncValue<SpaceDetailState>, String>(
  (ref, spaceId) => SpaceDetailController(ref, spaceId),
);
