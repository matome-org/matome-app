import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../contacts/contact.dart';
import 'matome.dart';
import 'matome_summary.dart';

/// Core <-> Drift reconciliation for space-scoped Matome/Contact sync (ADR-0004,
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
