import 'app_database.dart';

/// UI-facing recording item, ported from the RN home card data shape
/// (apps/mobile/processes/homeData + recordToCard in recordingService.ts).
///
/// This is the shape the home/calendar screens consume. It is derived from a
/// persisted [RecordingRow] via [RecordingItem.fromRow]; the DB row keeps the
/// raw SQLite columns, the card exposes the display-ready, typed view.
class RecordingItem {
  const RecordingItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.duration,
    required this.badge,
    required this.isProcessing,
    required this.mediaType,
    required this.processingStatus,
    this.summary,
    this.notes,
    this.workspaceName,
    this.coreId,
    this.filePath,
  });

  final String id;
  final String title;
  final String? summary;
  final String timestamp;
  final String duration;
  final String badge;
  final String? notes;
  final bool isProcessing;
  final String mediaType;
  final String processingStatus;

  /// The reconciled Core id, or null while the row is still local-only.
  ///
  /// A `rec_local_<uuid>` row keeps this NULL until `POST /api/recordings`
  /// succeeds; once set, the recording exists in the cloud. Drives the
  /// sync-state badge (on-device vs cloud) — plan #45, W2.
  final int? coreId;

  /// Populated only when the row was loaded via a workspace LEFT JOIN
  /// (see [RecordingsDao.recordingsByDayWithWorkspace]); NULL == Inbox.
  final String? workspaceName;

  /// On-device path to the item's media (audio file or imported photo). Drives
  /// the image thumbnail/preview in the matome hub.
  final String? filePath;

  /// Reconciled to Core AND not mid-upload — the single rule behind both the
  /// per-tile sync badge (StatusBadge.syncState) and the Matome-level sync
  /// rollup (MatomeItem.syncRollup), so a Matome pill can never contradict the
  /// "Cloud"/"On device" state of its own child tiles.
  bool get isOnCloud =>
      coreId != null &&
      processingStatus != 'pending_upload' &&
      processingStatus != 'failed';

  /// Maps a persisted DB row to the UI card, mirroring `recordToCard`:
  ///   * `isProcessing` int → bool,
  ///   * `processingStatus` falls back to processing/done from the flag.
  factory RecordingItem.fromRow(RecordingRow row, {String? workspaceName}) {
    return RecordingItem(
      id: row.id,
      title: row.title,
      summary: row.summary,
      timestamp: row.timestamp,
      duration: row.duration,
      badge: row.badge,
      notes: row.notes,
      isProcessing: row.isProcessing == 1,
      mediaType: row.mediaType,
      processingStatus: row.processingStatus.isNotEmpty
          ? row.processingStatus
          : (row.isProcessing == 1 ? 'processing' : 'done'),
      workspaceName: workspaceName,
      coreId: row.coreId,
      filePath: row.audioFilePath,
    );
  }
}
