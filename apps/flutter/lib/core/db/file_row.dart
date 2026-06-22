import 'app_database.dart';
import 'matome_card.dart';
import 'recording_card.dart';

/// The kind of a file (an Item / recording), driving its type icon and any
/// kind-specific meta (duration is audio-only). Mirrors the three `mediaType`
/// buckets `mediaTypeForPath` writes and the `FileKind` the DR-003 Files
/// proposal (`matome_files_proposal.dart`) uses.
enum FileKind { audio, image, document }

/// Maps a persisted `recordings.mediaType` string to a [FileKind]. The third
/// bucket (`document`) catches anything that is not audio/image — matching
/// `mediaTypeForPath`'s own third bucket — so an imported pdf/docx/md Item is a
/// document, never silently dropped.
FileKind fileKindFromMediaType(String mediaType) {
  switch (mediaType) {
    case 'audio':
    case 'meeting':
      return FileKind.audio;
    case 'image':
      return FileKind.image;
    default:
      return FileKind.document;
  }
}

/// UI-facing **File** row for the Files view (DR-003 / #1461) — the display-ready
/// view of a [RecordingRow] (a "file" is an Item / recording of `mediaType`
/// audio|image|document) joined with its three INDEPENDENT relations (matome,
/// space, people) and a sync rollup.
///
/// DR-003 LOAD-BEARING: matome, space and people are THREE independent relations,
/// each surfaced by its own atom with its own absence:
///   * [matome] == null  ⟺  **Unfiled** (no matome relation) — [unfiled].
///   * [space]  == null  ⟺  **Inbox**   (no space relation)  — [inInbox].
///   * [contacts] empty   ⟺  nobody tagged.
///
/// SCHEMA GAPS flagged at #1461 (mapped to what the schema can supply, degrading
/// gracefully — see the spike comment):
///   * **people are matome-mediated, not independent.** There is no per-file
///     `recording_contacts` edge; contacts attach via `matome_contacts`. So
///     [contacts] is the file's MATOME's tagged contacts when it has a matome,
///     and EMPTY for an Unfiled file. The DR-003 "people tied to a file directly"
///     relation does not exist in the schema yet.
///   * people are matome-mediated (see above).
///
/// SIZE (#1471): the recording's byte size IS now persisted end-to-end — captured
/// client-side at upload (`content_length`), stored in Core (`byte_size`) and
/// mirrored onto the Drift `byte_size` column. [sizeLabel] is the human-readable
/// label ("2.4 MB"); it is null ONLY for legacy rows whose `byte_size` was never
/// declared, in which case the UI shows a dash.
class FileRow {
  const FileRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.when,
    required this.whenSort,
    required this.rollup,
    this.ext,
    this.sizeLabel,
    this.matome,
    this.space,
    this.contacts = const [],
    this.duration,
  });

  /// The recording id (PK) — stable identity for selection / per-row actions.
  final String id;

  /// Display name of the file (the recording title).
  final String name;

  /// audio | image | document — drives the type icon.
  final FileKind kind;

  /// Lower-case source extension, no leading dot (`pdf`, `m4a`, `jpg`). From
  /// `recordings.original_extension` for documents (#1449); null when the row
  /// carries none (legacy / audio / image rows disambiguated by [kind]).
  final String? ext;

  /// Human size label (e.g. "2.4 MB"), produced by [formatBytes] from the row's
  /// persisted `byteSize` (#1471). **Null** only when the row carries no byte
  /// size (legacy rows created before size was plumbed through), in which case
  /// the UI renders a dash.
  final String? sizeLabel;

  /// Short relative display label for the "When" column / tile meta (e.g. "3h",
  /// "2d", "now") — derived from `createdAt` so the widget stays presentational
  /// and never touches the clock.
  final String when;

  /// Sort key for "When" — the recording's `createdAt` (epoch ms), newest-first.
  final int whenSort;

  /// matome relation — null ⟺ **Unfiled**. Display name of the owning matome.
  final String? matome;

  /// space relation (INDEPENDENT of matome) — null ⟺ **Inbox**. The filed
  /// Space (`workspaces.name`); a loose file can still live in a space.
  final String? space;

  /// people tagged on the file (contact display names). Matome-mediated today
  /// (schema gap — see class doc): the file's matome's contacts, or empty.
  final List<String> contacts;

  /// Sync rollup — reuses [MatomeSyncRollup] / [RecordingItem.isOnCloud].
  final MatomeSyncRollup rollup;

  /// Display duration (`m:ss`) — audio only; null for image/document.
  final String? duration;

  /// no matome relation (DR-003 "Unfiled").
  bool get unfiled => matome == null;

  /// no space relation (DR-003 "Inbox").
  bool get inInbox => space == null;

  /// Maps a persisted [RecordingRow] plus its resolved relation display values
  /// to the UI row. [matomeTitle] / [spaceName] come from the owner-scoped
  /// query's joins (null when Unfiled / Inbox); [contacts] from the matome's
  /// `matome_contacts` (empty when Unfiled).
  factory FileRow.fromRow(
    RecordingRow row, {
    String? matomeTitle,
    String? spaceName,
    List<String> contacts = const [],
    DateTime? now,
  }) {
    final kind = fileKindFromMediaType(row.mediaType);
    return FileRow(
      id: row.id,
      name: row.title,
      kind: kind,
      ext: row.originalExtension,
      sizeLabel: formatBytes(row.byteSize), // null only for legacy/no-size rows.
      when: relativeWhen(row.createdAt, now: now),
      whenSort: row.createdAt,
      matome: matomeTitle,
      space: spaceName,
      contacts: contacts,
      rollup: _rollupForRow(row),
      duration: kind == FileKind.audio ? row.duration : null,
    );
  }

  /// Formats a byte count into a human-readable size label (#1471).
  ///
  /// Pure + deterministic so it is unit-testable and the presentational widgets
  /// never format. Uses 1024-based (binary) units with the conventional
  /// KB/MB/GB labels (matching what file managers show). Rules:
  ///   * `null`        → null (the row has no size → UI renders "—").
  ///   * `< 0`         → null (a poison/negative size is treated as unknown,
  ///                     never rendered as a bogus label).
  ///   * `< 1 KB`      → whole bytes, e.g. "512 B", "0 B".
  ///   * `< 1 MB`      → KB, 1 decimal trimmed of a trailing ".0", e.g. "640 KB".
  ///   * `< 1 GB`      → MB, e.g. "2.4 MB".
  ///   * otherwise     → GB, e.g. "1.3 GB".
  static String? formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) return null;
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${_trim(bytes / kb)} KB';
    if (bytes < gb) return '${_trim(bytes / mb)} MB';
    return '${_trim(bytes / gb)} GB';
  }

  /// One-decimal rounding that drops a trailing ".0" so "640.0" → "640".
  static String _trim(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  /// Short relative label for an epoch-ms timestamp ("now"/"3h"/"2d"/"5w").
  /// Pure (and unit-testable) so the Files view-model carries a ready-to-render
  /// "When" string and the presentational widgets never read the clock. Mirrors
  /// the Inbox card's `formatTimestamp` buckets.
  static String relativeWhen(int createdAtMs, {DateTime? now}) {
    final when = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
    final reference = now ?? DateTime.now();
    final diff = reference.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  /// Single-file sync rollup, using the SAME [RecordingItem.isOnCloud] rule the
  /// per-tile badge and [MatomeItem.syncRollup] use — so a file row's pill can
  /// never contradict the matome rollup. A file is either fully on cloud or on
  /// device (it has no children to be "partial" over).
  static MatomeSyncRollup _rollupForRow(RecordingRow row) {
    return RecordingItem.fromRow(row).isOnCloud
        ? MatomeSyncRollup.cloud
        : MatomeSyncRollup.onDevice;
  }
}
