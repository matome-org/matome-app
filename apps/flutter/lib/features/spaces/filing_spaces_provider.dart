import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';

/// Filing-target Spaces for a matome's "Move to space" action (#1412), shared by
/// every list surface (Inbox / Home, Space detail, …) and by the matome row
/// actions. NEUTRAL by design (#1431/I-3): it reads the workspaces directly from
/// the DAO and is NOT anchored to the Inbox controller, so a non-inbox surface
/// (e.g. Space detail) no longer reaches across into an inbox-specific provider.
///
/// Loaded once and shared across rows so the dense menu has its targets without
/// a per-row Space query. Returns an empty list while loading / on error so the
/// row's handler degrades to an empty sheet rather than throwing.
final filingSpacesProvider = FutureProvider<List<WorkspaceRow>>(
  (ref) => ref.read(workspacesDaoProvider).getWorkspaces(),
);
