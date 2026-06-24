import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../recordings/recording.dart';

/// Core <-> Drift reconciliation for the Inbox (S1, #780).
///
/// The local store (Drift `recordings.id`) is TEXT; the Core [Recording.id] is
/// an int. We pin the local primary key to the Core id stringified
/// (`id.toString()`), mirroring apps/mobile which persists Core numeric ids as
/// strings (`String(created.recording.id)`). The same convention is used for
/// `workspaceId` (Core int -> TEXT).
///
/// This keeps Drift the single display source: sync upserts Core rows here,
/// the UI reads back from `getInboxRecordings`.

/// Stringified Core recording id used as the Drift primary key.
String coreIdToLocalId(int coreId) => coreId.toString();

/// Merge guard for a terminal/realtime text field (summary, notes, transcript).
///
/// A `recording:status` socket `done` event can be **sparse** — it may carry a
/// null/empty summary or transcript even though processing produced good data
/// (the loser of the socket-vs-poll race, or an early partial broadcast). Writing
/// that null through a partial UPDATE would WIPE a previously-good value.
///
/// Returns [Value.absent] when [incoming] is null or empty so the column is
/// left untouched (the existing DB value is preserved); otherwise [Value] of the
/// trimmed-non-empty incoming text. This is the B3 data-loss guard, mirroring the
/// per-field merge [recordingToCompanion] already applies on the sync path.
Value<String?> mergeText(String? incoming) {
  if (incoming == null || incoming.isEmpty) return const Value.absent();
  return Value(incoming);
}

/// Stringified Core workspace id, or null for the Inbox.
String? coreWorkspaceIdToLocal(int? workspaceId) => workspaceId?.toString();

/// `m:ss`-style duration string the Drift schema persists (it stores TEXT, not
/// a numeric duration). Mirrors apps/mobile `formatDuration` semantics enough
/// for display; empty for unknown/zero.
String formatDurationText(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  if (mins > 0) return '${mins}m ${secs}s';
  return '${secs}s';
}

/// A short clock-style timestamp (h:mm AM/PM), mirroring mobile
/// `formatTimestamp`. Used only as a fallback display column; the card's
/// relative time is derived from `createdAt` instead.
String formatClock(DateTime when) {
  final local = when.toLocal();
  final hour24 = local.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// Maps a server [RecordingStatus] onto the local `processingStatus` TEXT +
/// `isProcessing` 0/1 flag the Drift schema persists.
({String processingStatus, int isProcessing}) statusToLocal(
  RecordingStatus status,
) {
  switch (status) {
    case RecordingStatus.pending:
      return (processingStatus: 'pending', isProcessing: 1);
    case RecordingStatus.processing:
      return (processingStatus: 'processing', isProcessing: 1);
    case RecordingStatus.failed:
      return (processingStatus: 'failed', isProcessing: 0);
    case RecordingStatus.done:
    case RecordingStatus.unknown:
      return (processingStatus: 'done', isProcessing: 0);
  }
}

/// Builds the upsert companion for a single Core [recording].
///
/// `audioFilePath` defaults to the storage key (or empty) — S1 does not need a
/// local file path for synced rows. Inbox rows keep `workspaceId` NULL.
///
/// [existing] is the row already in Drift (or `null` for a first-time insert).
/// When supplied, this performs a **per-field merge** so a stale Core list-row
/// does not clobber a local-only edit that has not yet round-tripped to Core:
///
///   * `workspaceId` — if the local row was moved into a space but Core still
///     reports the Inbox (null), keep the local space. This is the data-loss
///     guard for move-to-space (B2): without it the next `refresh()` snaps the
///     recording back to the Inbox.
///   * `transcript` (Core-owned, #1434) — adopt Core's transcript when present;
///     keep a locally cached transcript only when Core carries none yet.
///   * `notes` (user-owned, #1434) — a pull must NEVER clobber a local note, so
///     the pull only seeds `notes` on a first-time insert; any existing local
///     note is preserved (only the save-path / push may overwrite it).
///   * `audioFilePath` — if the local row holds a real on-device path but Core's
///     `storageKey` is null/empty (fresh recording), keep the local path so the
///     audio stays playable (#45 W1) and retained (#46 W2) across refresh.
RecordingsCompanion recordingToCompanion(
  Recording recording, {
  RecordingRow? existing,
}) {
  final local = statusToLocal(recording.status);
  final createdAt =
      (recording.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;

  // Keep the existing local PK when this Core row was already reconciled into a
  // `rec_local_<uuid>` row (plan #43, W3): without this the upsert would mint a
  // SECOND row under the stringified-Core-id PK, duplicating the recording on
  // refresh. For a first-time sync (no existing row) the PK is the stringified
  // Core id (the legacy convention). Either way the `coreId` column is set so
  // the row is reconcilable by Core id from then on.
  final localId =
      (existing != null) ? existing.id : coreIdToLocalId(recording.id);

  final coreWorkspaceId = coreWorkspaceIdToLocal(recording.workspaceId);
  // Keep a local move-to-space if Core hasn't caught up (still reports Inbox).
  final mergedWorkspaceId =
      (coreWorkspaceId == null && existing?.workspaceId != null)
          ? existing!.workspaceId
          : coreWorkspaceId;

  // matomeId merge-guard (m007, .docs/internal/architecture.md §11 (D3)): every local recording is an Item of
  // exactly one Matome, but Core does NOT yet carry a Matome id on its
  // recording payload. A naive upsert that left `matome_id` ABSENT would be
  // fine on update, but `recordingToCompanion` builds a FULL companion used
  // with `insertOnConflictUpdate`, so an absent value would NULL the column on
  // the conflict-update — orphaning the recording from its Matome on the very
  // next `refresh()`. Mirror the workspaceId/B2 guard: preserve the existing
  // local `matome_id` (and emit `Value.absent()` for a first-time insert, which
  // can't happen via this path today but keeps the companion well-formed). A
  // Core refresh must NEVER null-clobber a local recording.matomeId.
  final matomeIdValue = (existing?.matomeId != null)
      ? Value<String?>(existing!.matomeId)
      : const Value<String?>.absent();

  // WRITE-AUTHORITY CONTRACT (#1434): `transcript` is Core-produced and `notes`
  // is user-produced. They are DISTINCT columns — previously Core `transcript`
  // was aliased into the `notes` column, clobbering user-edited notes on every
  // pull. They are now routed independently.
  //
  // PAYLOAD SEMANTICS: the `/api/recordings` list pull is a FULL-STATE snapshot
  // (every field is carried, possibly null), NOT a sparse patch. So a null here
  // means "Core has no value", not "field omitted". The merge therefore keys on
  // the contract authority, not on null-vs-empty:
  //
  //   * transcript (Core-owned): a pull populates/updates it. We adopt Core's
  //     transcript whenever it is present; if Core carries none yet we keep any
  //     locally cached transcript rather than wiping it (the absence guard).
  //   * notes (user-owned): a pull must NEVER clobber a locally-edited note. The
  //     pull only seeds `notes` when there is no existing local row (first sync);
  //     for any existing row the local note is preserved verbatim and only the
  //     save-path (push, task #1435) may overwrite it.
  final coreTranscript = recording.transcript;
  final mergedTranscript = (coreTranscript == null && existing?.transcript != null)
      ? existing!.transcript
      : coreTranscript;

  final mergedNotes = (existing != null) ? existing.notes : recording.notes;

  // Keep the locally-probed duration if Core reports none yet (plan #46 W3): an
  // imported file's real length is probed on-device at insert; a Core list-row
  // that hasn't computed/returned a duration must NOT blank it back out (same
  // data-loss guard as notes / move-to-space above).
  final coreDuration = formatDurationText(recording.duration);
  final existingDuration = existing?.duration;
  final mergedDuration = (coreDuration.isEmpty &&
          existingDuration != null &&
          existingDuration.isNotEmpty)
      ? existingDuration
      : coreDuration;

  // Keep the durable LOCAL audio path (plan #45 W1 playback / #46 W2 retention):
  // a local-first import persists `audioFilePath=/…/import_x.mp3`, but Core's
  // `storageKey` is null/empty on a fresh recording. After coreId reconcile the
  // FIRST refresh upsert would otherwise WIPE that local path to '' (insertOn-
  // ConflictUpdate), re-breaking "audio won't play / disappeared". Only adopt
  // Core's storageKey when there is NO local copy to preserve — i.e. the existing
  // path is empty or is itself a storage key, not a real on-device file path.
  final coreStorageKey = recording.storageKey ?? '';
  final existingAudioPath = existing?.audioFilePath;
  final hasLocalCopy = existingAudioPath != null &&
      (existingAudioPath.startsWith('/') ||
          existingAudioPath.startsWith('file:'));
  final mergedAudioFilePath =
      (coreStorageKey.isEmpty && hasLocalCopy) ? existingAudioPath : coreStorageKey;

  // OWNER-SCOPING (#1469, A01 — Broken Access Control). `recordings.owner_id` is
  // the SECURITY-CRITICAL scope for the Files view (filesForOwner): a NULL owner
  // is excluded from every owner's view (fail-closed), and a wrong/poison owner
  // (e.g. "0" from the old `asInt` bug) would LEAK across owners. The merge rule:
  //
  //   * Core is the AUTHORITY on ownership — its `recordings.owner_id` is NOT
  //     NULL and server-enforced (`list_recordings` filters `owner_id ==
  //     ^owner_id`). When Core carries a non-empty owner_id we adopt it verbatim
  //     (last-write-wins from the server; this also BACKFILLS a previously
  //     NULL-owner local row on the next sync).
  //   * A missing/blank Core owner_id is REJECTED, never defaulted: emit
  //     `Value.absent()` so the column is LEFT UNTOUCHED. On a first-time insert
  //     that means the row lands NULL-owner (correctly invisible until a later
  //     sync supplies a real owner); on an update it preserves the existing good
  //     owner rather than null-clobbering it. We NEVER write `0`/`""`.
  //
  // CONFLICT RESOLUTION (owner mismatch): Core wins. A non-empty server owner_id
  // overwrites a differing local owner — the server is the single source of truth
  // for who owns a row, so a stale/incorrect local owner is corrected on sync.
  final coreOwnerId = recording.ownerId;
  final ownerIdValue = (coreOwnerId != null && coreOwnerId.isNotEmpty)
      ? Value<String?>(coreOwnerId)
      : const Value<String?>.absent();

  // byteSize (#1471): the declared upload size in bytes. Adopt Core's value
  // whenever it carries one; if Core reports none yet (a row created before the
  // client declared a size, or a list-row Core hasn't backfilled) keep any
  // locally-known size rather than null-clobbering it (same absence guard as
  // duration / transcript above). Emits `Value.absent()` only when BOTH are
  // null, leaving the column untouched (NULL → "—").
  final coreByteSize = recording.byteSize;
  final byteSizeValue = (coreByteSize != null)
      ? Value<int?>(coreByteSize)
      : (existing?.byteSize != null)
          ? Value<int?>(existing!.byteSize)
          : const Value<int?>.absent();

  return RecordingsCompanion(
    id: Value(localId),
    coreId: Value(recording.id),
    title: Value(recording.title),
    summary: Value(recording.summary),
    timestamp: Value(formatClock(recording.insertedAt ?? DateTime.now())),
    duration: Value(mergedDuration),
    badge: Value(recording.badge ?? 'Inbox'),
    isProcessing: Value(local.isProcessing),
    audioFilePath: Value(mergedAudioFilePath),
    createdAt: Value(createdAt),
    notes: Value(mergedNotes),
    transcript: Value(mergedTranscript),
    workspaceId: Value(mergedWorkspaceId),
    mediaType: Value(recording.mediaType ?? 'audio'),
    processingStatus: Value(local.processingStatus),
    matomeId: matomeIdValue,
    ownerId: ownerIdValue,
    byteSize: byteSizeValue,
  );
}
