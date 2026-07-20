import 'daos/items_dao.dart';
import '../../features/items/matome_item_type.dart';
import '../../features/recordings/recording_ids.dart';
import '../../features/recordings/processing_error.dart' as processing_error;

/// UI-facing recording item, ported from the RN home card data shape
/// (apps/mobile/processes/homeData + recordToCard in recordingService.ts).
///
/// This is the shape the home/calendar screens consume. It is derived from a
/// persisted [ItemWithPayload] via [RecordingItem.fromItem]; the DB row keeps the
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
    this.itemType = MatomeItemType.file,
    this.summary,
    this.notes,
    this.workspaceName,
    this.coreId,
    this.blobId,
    this.processingErrorCode,
  });

  final String id;
  final String title;
  final String? summary;
  final String timestamp;
  final String duration;
  final String badge;
  final String? notes;
  final bool isProcessing;
  final MatomeItemType itemType;
  final String mediaType;
  final String processingStatus;
  final String? processingErrorCode;

  String get processingErrorMessage =>
      processing_error.processingErrorMessage(processingErrorCode);

  /// The reconciled Core id, or null while the row is still local-only.
  ///
  /// A `rec_local_<uuid>` row keeps this NULL until `POST /api/recordings`
  /// succeeds; once set, the recording exists in the cloud. Drives the
  /// sync-state badge (on-device vs cloud) — plan #45, W2.
  final int? coreId;

  /// Populated only when the Item was loaded with its workspace relation;
  /// NULL means Inbox.
  final String? workspaceName;

  /// Opaque encrypted Vault identity. Preview leases are implemented in #2150.
  final String? blobId;

  /// Reconciled to Core AND not mid-upload — the single rule behind both the
  /// per-tile sync badge (StatusBadge.syncState) and the Matome-level sync
  /// rollup (MatomeItem.syncRollup), so a Matome pill can never contradict the
  /// "Cloud"/"On device" state of its own child tiles.
  bool get isOnCloud =>
      coreId != null && !isUploadQueuePendingStatus(processingStatus);

  /// Maps a persisted DB row to the UI card, mirroring `recordToCard`:
  ///   * `isProcessing` int → bool,
  ///   * `processingStatus` falls back to processing/done from the flag.
  factory RecordingItem.fromItem(ItemWithPayload row, {String? workspaceName}) {
    final duration = row.durationSeconds == null || row.durationSeconds! <= 0
        ? ''
        : '${row.durationSeconds! ~/ 60}m ${row.durationSeconds! % 60}s';
    return RecordingItem(
      id: row.id,
      title: row.title,
      summary: row.summary,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
      ).toIso8601String(),
      duration: duration,
      badge: row.workspaceId == null ? 'Inbox' : 'Space',
      notes: row.notes,
      isProcessing: row.isProcessing,
      itemType: row.type,
      mediaType: row.mediaType,
      processingStatus: row.processingStatus,
      processingErrorCode: row.processingErrorCode,
      workspaceName: workspaceName,
      coreId: row.coreId,
      blobId: row.blobId,
    );
  }

  factory RecordingItem.textItem({
    required String id,
    required String body,
    required String insertedAt,
  }) {
    final title = body.trim().split('\n').first.trim();
    return RecordingItem(
      id: id,
      title: title.isEmpty ? 'Text note' : title,
      summary: body,
      timestamp: insertedAt,
      duration: '',
      badge: 'Note',
      notes: body,
      isProcessing: false,
      itemType: MatomeItemType.text,
      mediaType: 'text',
      processingStatus: 'done',
    );
  }
}
