import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_state.dart';
import '../../core/db/file_row.dart';
import '../../core/providers.dart';

/// The current authenticated owner's id (Core user id, stringified to match the
/// TEXT `recordings.owner_id` column), or null when signed out.
///
/// SECURITY (#1461): this is the SINGLE source of the owner predicate for the
/// Files view. The owner is taken from the authenticated session
/// ([authStateProvider]), never from a request param or list filter — so the
/// owner-scoped query can never be widened by the caller.
final currentOwnerIdProvider = Provider<String?>((ref) {
  final id = ref.watch(authStateProvider).user?.id;
  return id?.toString();
});

/// Every file (audio|image|document Item) the CURRENT OWNER owns, across all
/// matomes AND loose/Unfiled rows, newest first — the data source for the Files
/// view (DR-003 / #1461).
///
/// SECURITY (A01): owner-scoped at the data source. The owner predicate is
/// applied as `recordings.owner_id == ownerId` ON THE ROW inside the DAO
/// ([RecordingsDao.filesForOwner]) — NOT a client-side filter over an unscoped
/// fetch. When signed out (no owner id), returns an empty list rather than the
/// whole table, so an absent session can never surface another owner's rows.
final filesForCurrentOwnerProvider = FutureProvider<List<FileRow>>((ref) async {
  final ownerId = ref.watch(currentOwnerIdProvider);
  if (ownerId == null) return const <FileRow>[];
  final dao = ref.watch(recordingsDaoProvider);
  return dao.filesForOwner(ownerId);
});
