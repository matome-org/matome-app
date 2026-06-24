import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../contacts/contact.dart';
import 'matome.dart';
import 'matome_summary.dart';

/// Core <-> Drift reconciliation for space-scoped Matome/Contact sync (.docs/internal/architecture.md §11 (D4),
/// task #1377). Mirrors `inbox_sync.dart` (the recordings sync): a remote payload
/// is mapped to a Drift upsert companion with PER-FIELD merge-guards so a sparse
/// Core row never clobbers a local-only edit that has not round-tripped yet.
///
/// Reconciliation is by the `core_id` column (NEVER a PK remap): a local-minted
/// `mat_local_<uuid>` / `contact_local_<uuid>` row keeps its UUID PK and the
/// matched remote row fills (or refreshes) its `core_id`. A first-time pull of a
/// remote row the client has never seen mints under the stringified Core id PK.

/// Stringified Core id used as the Drift PK for a first-time-pulled remote row.
String coreIdToLocalId(int coreId) => coreId.toString();

/// Stringified Core Space (workspace) id, mirroring the recordings sync
/// (`coreWorkspaceIdToLocal`). A synced Matome is always filed into a Space.
String? coreSpaceIdToLocal(int? workspaceId) => workspaceId?.toString();

/// Builds the upsert companion for a single Core [matome].
///
/// [existing] is the local row already reconciled to this Matome (matched by
/// `core_id`), or `null` for a first-time pull. When supplied, this performs a
/// per-field merge so a stale/sparse Core row does not wipe local edits:
///
///   * PK — keep the existing local PK (a `mat_local_<uuid>` that synced keeps
///     its UUID); else mint under the stringified Core id.
///   * `spaceId` — if Core reports no Space but the local row is already filed,
///     keep the local Space (the move-to-space data-loss guard, mirroring the
///     recordings B2 guard).
///   * `aggregatedSummary` — merged via [mergeAggregatedSummary]: a sparse Core
///     payload that nulls/omits the aggregate must never erase a good local one.
///   * `description` — same null-wipe guard (kept if Core has none yet).
MatomesCompanion matomeToCompanion(Matome matome, {MatomeRow? existing}) {
  final localId = existing?.id ?? coreIdToLocalId(matome.id);

  final coreSpaceId = coreSpaceIdToLocal(matome.workspaceId);
  final mergedSpaceId = (coreSpaceId == null && existing?.spaceId != null)
      ? existing!.spaceId
      : coreSpaceId;

  // Null-wipe guards: only adopt Core's value when it is non-empty; otherwise
  // leave the column untouched (Value.absent) so the existing local value
  // survives a sparse pull.
  final summaryValue = mergeAggregatedSummary(matome.aggregatedSummary);
  final descriptionValue = _mergeNullableText(matome.description);
  final archivedAtValue =
      _mergeArchivedAt(matome.archivedAt, existing?.archivedAt);

  // `upsert` runs `insertOnConflictUpdate`, which validates the companion as an
  // INSERT — so the NOT-NULL happenedAt/createdAt must always be present. Keep
  // the EXISTING local timestamps on a re-sync (don't reset the local row's
  // happened/created); only derive fresh ones for a first-time pull.
  final happenedAt = existing?.happenedAt ??
      (matome.happenedAt ?? matome.insertedAt ?? DateTime.now())
          .millisecondsSinceEpoch;
  final createdAt = existing?.createdAt ??
      (matome.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;

  return MatomesCompanion(
    id: Value(localId),
    coreId: Value(matome.id),
    title: Value(matome.title),
    spaceId: Value(mergedSpaceId),
    happenedAt: Value(happenedAt),
    createdAt: Value(createdAt),
    description: descriptionValue,
    aggregatedSummary: summaryValue,
    // Archive-adopt guard (#1431/#70912) — see [_mergeArchivedAt]. A Core-
    // reported active (NULL) row must NOT clobber a local archive that has not
    // round-tripped to Core yet (the failed-archive offline window); the sync
    // PUSH re-archives it on Core so the two ends converge to archived. A genuine
    // archive (Core reports a stamp) and a restore of a NOT-locally-archived row
    // both flow through normally.
    archivedAt: archivedAtValue,
  );
}

/// Builds the upsert companion for a single Core [contact].
///
/// [existing] is the local row matched by `core_id` (or null for a first pull).
/// `metadata` is merged with the same null-wipe guard so a sparse Core payload
/// does not blank a local metadata blob.
ContactsCompanion contactToCompanion(Contact contact, {ContactRow? existing}) {
  final localId = existing?.id ?? coreIdToLocalId(contact.id);
  // `contacts.metadata` is NON-NULL (defaults to `{}`); a sparse/blank Core
  // metadata leaves the column untouched (Value.absent) so a local blob is not
  // wiped, otherwise the trimmed incoming JSON is adopted.
  final trimmedMetadata = contact.metadata?.trim();
  final metadataValue =
      (trimmedMetadata == null || trimmedMetadata.isEmpty)
          ? const Value<String>.absent()
          : Value<String>(trimmedMetadata);
  // `upsert` validates as an INSERT, so the NOT-NULL createdAt must always be
  // present; keep the existing local value on a re-sync.
  final createdAt = existing?.createdAt ??
      (contact.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;

  return ContactsCompanion(
    id: Value(localId),
    coreId: Value(contact.id),
    ownerId: Value(contact.ownerId),
    displayName: Value(contact.displayName),
    // Structured fields (#1462): sparse Core payload leaves a local value
    // untouched rather than wiping it (same null-wipe guard as metadata).
    email: _mergeNullableText(contact.email),
    phone: _mergeNullableText(contact.phone),
    company: _mergeNullableText(contact.company),
    title: _mergeNullableText(contact.title),
    metadata: metadataValue,
    linkedUserId: Value(contact.linkedUserId),
    createdAt: Value(createdAt),
  );
}

/// Sparse-pull null-wipe guard for a nullable TEXT column (description /
/// metadata): leaves the column untouched when [incoming] is null/blank so a
/// partial UPDATE preserves the existing local value. Mirrors
/// `inbox_sync.dart` `mergeText`.
Value<String?> _mergeNullableText(String? incoming) {
  final trimmed = incoming?.trim();
  if (trimmed == null || trimmed.isEmpty) return const Value.absent();
  return Value(trimmed);
}

/// Archive-adopt guard for the pull→Drift merge (#1431, audit #70912).
///
/// Core's default Matome list EXCLUDES archived rows, so a row that comes back
/// in the pull as active ([incoming] == null) is normally genuinely active.
/// The one exception is the OFFLINE-ARCHIVE WINDOW: a reconciled Matome that was
/// archived locally while its Core POST failed is still active on Core, so it
/// re-appears in the pull as active. Adopting that NULL unconditionally would
/// silently UN-archive the local row — the bug this guards.
///
/// So: when Core reports active (NULL) but the local row is ALREADY archived,
/// keep the local archive (`Value.absent` — leave the column untouched). The
/// sync PUSH re-archives the row on Core (see `MatomeSyncService.pushArchives`),
/// which makes Core converge to archived; once it does, Core stops listing the
/// row and the guard is no longer exercised for it.
///
/// Every other case adopts Core's value verbatim:
///   * Core reports a stamp ([incoming] != null) → adopt the archive.
///   * Core reports active and the local row is NOT archived → adopt active
///     (this is the genuine restore-on-pull path, kept working).
Value<int?> _mergeArchivedAt(DateTime? incoming, int? existingArchivedAt) {
  if (incoming == null && existingArchivedAt != null) {
    // Locally archived, Core unaware (offline-archive window) — keep the local
    // archive; the push re-archives Core so the two ends converge.
    return const Value.absent();
  }
  return Value(incoming?.millisecondsSinceEpoch);
}
