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
///   * `notes` — if Core returns no transcript yet but the local row already
///     has notes, keep the local notes rather than wiping them to null.
RecordingsCompanion recordingToCompanion(
  Recording recording, {
  RecordingRow? existing,
}) {
  final local = statusToLocal(recording.status);
  final createdAt =
      (recording.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;

  final coreWorkspaceId = coreWorkspaceIdToLocal(recording.workspaceId);
  // Keep a local move-to-space if Core hasn't caught up (still reports Inbox).
  final mergedWorkspaceId =
      (coreWorkspaceId == null && existing?.workspaceId != null)
          ? existing!.workspaceId
          : coreWorkspaceId;

  final coreNotes = recording.transcript;
  // Keep local notes if Core has none yet but we already cached some.
  final mergedNotes = (coreNotes == null && existing?.notes != null)
      ? existing!.notes
      : coreNotes;

  return RecordingsCompanion(
    id: Value(coreIdToLocalId(recording.id)),
    title: Value(recording.title),
    summary: Value(recording.summary),
    timestamp: Value(formatClock(recording.insertedAt ?? DateTime.now())),
    duration: Value(formatDurationText(recording.duration)),
    badge: Value(recording.badge ?? 'Inbox'),
    isProcessing: Value(local.isProcessing),
    audioFilePath: Value(recording.storageKey ?? ''),
    createdAt: Value(createdAt),
    notes: Value(mergedNotes),
    workspaceId: Value(mergedWorkspaceId),
    mediaType: Value(recording.mediaType ?? 'audio'),
    processingStatus: Value(local.processingStatus),
  );
}
