import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/matome_card.dart';
import '../../core/providers.dart';

/// State for the Space detail screen (`/spaces/:spaceId`): the workspace name
/// (for the header) plus the **matomes** filed into it (#1378).
class SpaceDetailState {
  const SpaceDetailState({
    required this.name,
    required this.items,
    this.isLocal = false,
  });

  /// Workspace name, or null if the workspace no longer exists.
  final String? name;
  final List<MatomeItem> items;

  /// Local-first-spaces (#102): whether this space is local-only vs cloud.
  /// Drives the reading-pane header's "· Local/Cloud" suffix.
  final bool isLocal;
}

/// Drives the Space detail screen (S5) under the matome-centric model (#1378).
/// A Space lists its **matomes** (`MatomesDao.listMatomeItemsInSpace`), not
/// individual recordings. Drift-only (offline-first).
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
    final matomesDao = _ref.read(matomesDaoProvider);

    final workspace = await workspacesDao.getWorkspaceById(spaceId);
    final items = await matomesDao.listMatomeItemsInSpace(spaceId);
    return SpaceDetailState(
      name: workspace?.name,
      items: items,
      isLocal: workspace?.isLocal == 1,
    );
  }

  Future<void> load() async {
    final next = await AsyncValue.guard(_load);
    // Guard against a state emit after the autoDispose provider tore down.
    if (!mounted) return;
    state = next;
  }
}

/// Family keyed by the space (workspace) id.
///
/// `autoDispose` so the notifier (and its Drift load) is torn down when the
/// Space detail route is popped — mirroring [detailsControllerProvider].
final spaceDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<SpaceDetailController, AsyncValue<SpaceDetailState>, String>(
      (ref, spaceId) => SpaceDetailController(ref, spaceId),
    );
