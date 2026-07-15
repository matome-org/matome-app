import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/endpoint_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart';
import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/spaces_dao.dart';
import '../../core/db/daos/work_queue_dao.dart';
import '../../core/db/file_row.dart';
import '../../core/db/matome_card.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../contacts/contacts_controller.dart' show kPlaceholderContactOwnerId;
import '../home/inbox_upload.dart'
    show DurableImportCopy, PickedUpload, durableImportCopy, mediaTypeForPath;
import '../home/matome_inbox_controller.dart'
    show matomeInboxControllerProvider;
import '../items/matome_item_type.dart';
import '../recordings/recording_ids.dart';
import '../recordings/upload_queue.dart' show uploadQueueProvider;
import 'matome_sync_service.dart';
import 'matomes_repository.dart';

/// Immutable view-state for the Matome detail hub (#1371, triage #1372).
///
/// Mirrors [DetailsState] (the single-recording analogue): a loading flag, a
/// not-found flag, and the hydrated [MatomeItem] when present. #1372 layers the
/// triage actions (file-into-space, notes edit, photo import) on top.
class MatomeDetailState {
  const MatomeDetailState({
    required this.id,
    this.matome,
    this.spaces = const [],
    this.contacts = const [],
    this.isLoading = true,
    this.notFound = false,
  });

  final String id;
  final MatomeItem? matome;

  /// Spaces the Matome can be filed into — the personal Space is guaranteed to
  /// be present and is the default/most-prominent destination (.docs/internal/architecture.md §11 (D4)).
  final List<WorkspaceRow> spaces;

  /// Contacts tagged in this Matome (the `matome_contacts` edges), each paired
  /// with its edge role — display-name ascending (#1375).
  final List<MatomeContactEntry> contacts;

  final bool isLoading;
  final bool notFound;

  MatomeDetailState copyWith({
    MatomeItem? matome,
    List<WorkspaceRow>? spaces,
    List<MatomeContactEntry>? contacts,
    bool? isLoading,
    bool? notFound,
  }) {
    return MatomeDetailState(
      id: id,
      matome: matome ?? this.matome,
      spaces: spaces ?? this.spaces,
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      notFound: notFound ?? this.notFound,
    );
  }
}

/// Drives the Matome detail hub (#1371) and its triage actions (#1372). Display
/// source is ALWAYS Drift — the sync layer reconciles Core into Drift, so this
/// screen never reaches the network (mirrors [DetailsController]).
///
/// Triage (.docs/internal/architecture.md §11 (D4)) = enrich + FILE INTO A SPACE. [fileIntoSpace] sets
/// `matome.spaceId`, moving the Matome out of the Inbox and into the sync
/// domain; [saveNotes] edits the description; [addPhoto] imports an image as an
/// Item of this Matome.
class MatomeDetailController extends StateNotifier<MatomeDetailState> {
  MatomeDetailController(this._ref, String id, {DurableImportCopy? durableCopy})
    : _durableCopy = durableCopy ?? durableImportCopy,
      super(MatomeDetailState(id: id)) {
    load();
  }

  final Ref _ref;

  /// Copies a file-picker import into durable app storage before the local-first
  /// insert (plan #45 W1). Injectable for tests; defaults to [durableImportCopy].
  final DurableImportCopy _durableCopy;

  MatomesDao get _dao => _ref.read(matomesDaoProvider);
  SpacesDao get _spacesDao => _ref.read(spacesDaoProvider);
  ItemsDao get _itemsDao => _ref.read(itemsDaoProvider);
  ContactsDao get _contactsDao => _ref.read(contactsDaoProvider);
  MatomesRepository get _matomesRepo => _ref.read(matomesRepositoryProvider);

  /// The current owner id used to scope the directory picker. Mirrors
  /// [ContactsController.ownerId] so the picker lists the same directory.
  String get _ownerId =>
      _ref.read(currentOwnerIdProvider) ?? kPlaceholderContactOwnerId;

  String get _itemOwnerId {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('An authenticated owner is required');
    }
    return ownerId;
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, notFound: false);
    final matome = await _dao.getMatomeWithItems(state.id, _itemOwnerId);
    if (!mounted) return;
    if (matome == null) {
      state = state.copyWith(isLoading: false, notFound: true);
      return;
    }
    final spaces = await _loadSpaces();
    final contacts = await _contactsDao.listContactsForMatome(state.id);
    if (!mounted) return;
    state = state.copyWith(
      matome: matome,
      spaces: spaces,
      contacts: contacts,
      isLoading: false,
      notFound: false,
    );
  }

  /// The owner's directory contacts — the candidates surfaced in the
  /// "Add contact" picker (ContactsDao.listContactsForOwner, same owner-id
  /// source as the Contacts tab).
  Future<List<ContactRow>> directoryContacts() =>
      _contactsDao.listContactsForOwner(_ownerId);

  /// Tag [contactId] in this Matome with [role] (default 'attendee'). The
  /// (matome_id, contact_id) UNIQUE makes a re-add a no-op (set-merge rule), so
  /// attaching is idempotent. Reloads so the chip appears.
  Future<void> attachContact(
    String contactId, {
    String role = 'attendee',
  }) async {
    AppLog.event(
      LogCat.action,
      'attachContact $contactId to ${state.id} ($role)',
    );
    await _contactsDao.addContactToMatome(
      matomeId: state.id,
      contactId: contactId,
      role: role,
    );
    await load();
    // The inbox/master list is a one-shot load; nudge it so the open-beside
    // table/cards reflect the new people count (master-detail).
    _ref.read(matomeInboxControllerProvider.notifier).reloadFromLocal();
  }

  /// The owner's files that are NOT already Items of this Matome — the Files
  /// candidates for the unified "Add anything" picker. Owner-scoped via
  /// [ItemsDao.filesForOwner]; excludes the current Items by id.
  Future<List<FileRow>> candidateFiles() async {
    final all = await _itemsDao.filesForOwner(_itemOwnerId);
    final here = (state.matome?.recordings ?? const [])
        .map((r) => r.id)
        .toSet();
    return all.where((f) => !here.contains(f.id)).toList();
  }

  /// MOVE the given owner files into this Matome — the Files link of the unified
  /// picker. A recording has ONE matome (#1473), so linking REASSIGNS each row's
  /// `matome_id` to this Matome. Owner-scoped (the DAO rejects foreign targets);
  /// reloads so the new Items appear. Returns the number moved.
  Future<int> linkFiles(Set<String> recordingIds) async {
    if (recordingIds.isEmpty) return 0;
    AppLog.event(
      LogCat.action,
      'linkFiles ${recordingIds.length} -> ${state.id}',
    );
    final moved = await _itemsDao.moveItemsToMatome(
      recordingIds,
      state.id,
      _itemOwnerId,
    );
    await load();
    return moved;
  }

  /// Create a directory contact for the owner and immediately tag it in this
  /// Matome — the picker's "Create contact" action. The created id reuses the
  /// `contact_local_<uuid>` convention; `metadata` falls back to its column
  /// default ('{}'). [attachContact] reloads.
  Future<void> createContactAndAttach(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) return;
    final id = 'contact_local_${const Uuid().v4()}';
    AppLog.event(LogCat.action, 'createContactAndAttach $id -> ${state.id}');
    await _contactsDao.create(
      ContactsCompanion.insert(
        id: id,
        ownerId: _ownerId,
        displayName: name,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await attachContact(id);
  }

  /// Create a Space (workspace) and file this Matome into it — the picker's
  /// "New space" action (single-valued, last-wins). [fileIntoSpace] reloads.
  Future<void> createSpaceAndFile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final ws = await _ref.read(workspacesDaoProvider).createWorkspace(trimmed);
    AppLog.event(LogCat.action, 'createSpaceAndFile ${ws.id} -> ${state.id}');
    await fileIntoSpace(ws.id);
  }

  /// Untag [contactId] from this Matome — EXPLICIT removal of the
  /// `matome_contacts` edge (set-merge rule: membership is never trimmed
  /// implicitly). Reloads so the chip disappears.
  Future<void> detachContact(String contactId) async {
    AppLog.event(LogCat.action, 'detachContact $contactId from ${state.id}');
    await _contactsDao.removeContactFromMatome(
      matomeId: state.id,
      contactId: contactId,
    );
    await load();
    _ref.read(matomeInboxControllerProvider.notifier).reloadFromLocal();
  }

  /// Change the edge [role] of an already-attached [contactId]. Reloads.
  Future<void> setContactRole(String contactId, String role) async {
    AppLog.event(
      LogCat.action,
      'setContactRole $contactId on ${state.id} -> $role',
    );
    await _contactsDao.setMatomeContactRole(
      matomeId: state.id,
      contactId: contactId,
      role: role,
    );
    await load();
  }

  /// All Spaces available as triage destinations, with the seeded default
  /// personal Space guaranteed present and ordered first (the default target).
  Future<List<WorkspaceRow>> _loadSpaces() async {
    final personal = await _spacesDao.ensureDefaultPersonalSpace();
    final all = await _ref.read(workspacesDaoProvider).getWorkspaces();
    final rest = all.where((w) => w.id != personal.id);
    return [personal, ...rest];
  }

  /// The seeded default personal Space — the default triage destination
  /// (.docs/internal/architecture.md §11 (D4)). Exposed so the UI can mark it as the most-prominent option.
  Future<WorkspaceRow> defaultPersonalSpace() =>
      _spacesDao.ensureDefaultPersonalSpace();

  /// FILE this Matome into [spaceId] — the core triage action (.docs/internal/architecture.md §11 (D4)): sets
  /// `space_id`, moving it out of the Inbox into the sync domain. Reloads so the
  /// screen reflects the filed state (and any inbox list elsewhere drops it).
  Future<void> fileIntoSpace(String spaceId) async {
    AppLog.event(LogCat.action, 'fileIntoSpace ${state.id} -> $spaceId');
    await _dao.fileIntoSpace(state.id, spaceId);
    await load();
  }

  /// Edit the Matome's notes (`description`). Marks the aggregated summary stale
  /// when the notes actually changed (the Matome content moved on).
  Future<void> saveNotes(String notes) async {
    AppLog.event(LogCat.action, 'saveNotes ${state.id}');
    final trimmed = notes.trim();
    final current = state.matome?.description?.trim() ?? '';
    await _dao.updateMatome(
      state.id,
      MatomesCompanion(description: Value(trimmed.isEmpty ? null : trimmed)),
    );
    if (trimmed != current) {
      await _dao.markSummaryStale(state.id, true);
    }
    await load();
  }

  /// Regenerate the stored aggregated summary from the Matome's CURRENT Items
  /// (.docs/internal/architecture.md §11 (D3)). Deterministic LOCAL composition via the DAO — no AI/backend
  /// call. Stores the rollup and clears the stale flag (or NULLs it when no Item
  /// has a summary yet). Reloads so the hub reflects the fresh summary.
  Future<void> regenerateSummary() async {
    AppLog.event(LogCat.action, 'regenerateSummary ${state.id}');
    await _dao.regenerateSummary(state.id, _itemOwnerId);
    await load();
  }

  /// Import an image [file] as an Item of this Matome — the "Add photo"
  /// affordance. Thin wrapper over the generic [addFile]: the media type is
  /// resolved from the extension exactly as for any other import (an image
  /// extension yields `mediaType: 'image'`), so this stays a labelled entry
  /// point without a hardcoded type.
  Future<void> addPhoto({required File file, required String name}) =>
      addFile(file: file, name: name);

  /// Import an arbitrary [file] as an Item of this Matome — the generic
  /// document/photo import (#1449). Reuses the local-first upload insert path:
  /// the bytes are copied to durable app storage, then a `rec_local_<uuid>` row
  /// and its initial work row are inserted atomically with this Matome's id via
  /// [ItemsDao.createFileItem]. The Matome's triage state
  /// (spaceId) is untouched.
  ///
  /// The `mediaType` is DERIVED from the file extension via [mediaTypeForPath]
  /// (audio/image/document) — NEVER hardcoded — and the original lower-case
  /// extension is PERSISTED on the row (`originalExtension`) so the file-type
  /// icon / open-extract routing survive the durable copy's opaque rename.
  ///
  /// A client-side size guard rejects files over [kMaxImportFileBytes]
  /// (mirroring the Core upload cap, task #1448) BEFORE any durable copy or DB
  /// write, throwing [FileTooLargeException] so the caller can surface a
  /// message.
  Future<void> addFile({required File file, required String name}) async {
    // Capture the matome id up front: the durable-copy / DAO awaits can outlive
    // an autoDispose of this notifier, and reading `state` afterwards throws.
    final matomeId = state.id;

    // Size guard FIRST — before the durable copy / insert. A file over the cap
    // would only be rejected by Core after the upload starts (or OOM on copy),
    // so fail fast with a typed error the UI turns into a message. Native only:
    // on web the import is cloud-direct with no on-disk `File` to stat (the cap
    // is enforced server-side, #1448). `lengthSync` (not the async `length`)
    // keeps this a single synchronous step so it does not introduce a real-I/O
    // await into the local-first insert path.
    if (!kIsWeb) {
      final sizeBytes = file.lengthSync();
      if (sizeBytes > kMaxImportFileBytes) {
        throw FileTooLargeException(sizeBytes: sizeBytes, name: name);
      }
    }

    final picked = PickedUpload(
      file: file,
      title: _titleFromName(name),
      mediaType: mediaTypeForPath(file.path),
    );
    final stored = kIsWeb ? picked : await _durableCopy(picked);

    // Mint the local id up front so we can hand THIS row to the upload queue
    // after the insert (the drain below targets it directly).
    final recordingId = mintLocalRecordingId();
    final fileId = 'file_$recordingId';
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    await _itemsDao.createFileItem(
      item: ItemsCompanion.insert(
        id: recordingId,
        ownerId: _itemOwnerId,
        clientId: recordingId,
        matomeId: Value(matomeId),
        itemType: MatomeItemType.file.wireName,
        title: Value(stored.title),
        fileBlobId: Value(fileId),
        syncState: const Value(kProcessingStatusPendingUpload),
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      file: FileBlobsCompanion.insert(
        id: fileId,
        filename: Value(name),
        byteSize: Value(kIsWeb ? 0 : stored.file.lengthSync()),
        mediaType: picked.mediaType,
        localPath: Value(stored.file.path),
        wrappedFek: Value(stored.wrappedFekBase64),
        fileNoncePrefix: Value(stored.fileNoncePrefixBase64),
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      initialWork: fileUploadWork(
        itemId: recordingId,
        sourceRevision: 1,
        now: timestamp,
        configRevision: workConfigRevisionForEndpoint(
          _ref.read(endpointConfigProvider),
        ),
      ),
    );
    if (!mounted) return;
    await load();

    // KICK THE UPLOAD QUEUE for the just-inserted durable work row (#1457).
    // Without this drain the doc/photo would
    // sit "Saved on device · waiting to upload" until an unrelated trigger
    // (app-start / connectivity rising-edge) fires, because `addFile` matches
    // none of the `UploadRetryService` triggers (unlike the recorder path, which
    // drains inline via `InboxUploader.upload`). Mirrors `inbox_controller.dart`'s
    // manual retry: drain THIS row through the same single-flight queue.
    //
    // Best-effort / non-blocking: the drain runs in the background and any
    // failure (offline, Core 401) is swallowed here. The local-first insert is
    // already committed and MUST NOT be reverted — the row stays `pending_upload`
    // so a later trigger retries it. We do NOT await it (an in-flight upload must
    // not block the import returning) and catch so a throwing drain never escapes.
    unawaited(
      Future(
        () => _ref.read(uploadQueueProvider).drainRow(recordingId),
      ).catchError((Object e, StackTrace st) {
        AppLog.error(
          LogCat.upload,
          'addFile: best-effort drain failed (row stays pending_upload) '
          '$recordingId',
          e,
          st,
        );
      }),
    );
  }

  /// Create a plain-text Item for this Matome without entering the file upload
  /// pipeline. This writes only the Core-shaped `text_contents` + `items` local
  /// mirror and deliberately performs no durable copy, presign, upload queue, or
  /// AI dispatch work; rich-text editing is intentionally out of scope.
  Future<String> addTextNote(String body) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Text note cannot be empty');
    }

    final matomeId = state.id;
    final matome = await _dao.getById(matomeId);
    final coreMatomeId = matome?.coreId;
    final itemId = 'text_local_${const Uuid().v4()}';
    final payloadId = 'text_content_${const Uuid().v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _itemsDao.createTextItem(
      item: ItemsCompanion.insert(
        id: itemId,
        ownerId: _itemOwnerId,
        clientId: itemId,
        matomeId: Value(matomeId),
        itemType: MatomeItemType.text.wireName,
        title: Value(text.split('\n').first),
        textContentId: Value(payloadId),
        syncState: const Value('local_saved'),
        createdAt: now,
        updatedAt: now,
      ),
      text: TextContentsCompanion.insert(
        id: payloadId,
        body: text,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _dao.markSummaryStale(matomeId, true);

    // SYNC (#1830 / W1): a reconciled Matome MUST push the note to Core so it is
    // durable + visible cross-device — the local mirror alone was lost on
    // reinstall / device loss. Local-first + best-effort: the note is already
    // committed to Drift above; a failed POST (offline / server error) is
    // logged and swallowed here (NEVER reverts the local write). An
    // un-reconciled Matome never reaches this method (the action is UI-gated on
    // `coreId != null` and the guard above throws), so it stays local-only.
    if (coreMatomeId != null) {
      try {
        await _matomesRepo.createTextItem(
          matomeId: coreMatomeId,
          clientId: itemId,
          body: text,
        );
      } catch (e, st) {
        AppLog.error(
          LogCat.sync,
          'addTextNote: Core POST failed (note kept local, reconciles later) '
          '$matomeId',
          e,
          st,
        );
      }
    }

    if (mounted) await load();
    return itemId;
  }

  /// Rename this Matome — the local-first edit (task #1408 / W5). Writes the
  /// trimmed [title] to Drift FIRST (so the header updates immediately,
  /// offline-safe), then PATCHes Core when the Matome is reconciled. Reload so
  /// the hub reflects the new title. The matome id is captured up front: the
  /// sync awaits can outlive an autoDispose of this notifier.
  Future<void> rename(String title) async {
    final matomeId = state.id;
    AppLog.event(LogCat.action, 'rename $matomeId');
    await _ref
        .read(matomeSyncServiceProvider)
        .editMatome(matomeId, title: title);
    if (!mounted) return;
    await load();
  }

  /// Edit this Matome's date & time (`happened_at`) — the local-first re-date
  /// (task #1408 / W5). Writes [happenedAt] to Drift FIRST (so the header + every
  /// list re-sort immediately, offline-safe), then PATCHes Core when reconciled.
  /// Reload so the hub reflects the new timestamp. The matome id is captured up
  /// front: the sync awaits can outlive an autoDispose of this notifier.
  Future<void> editDateTime(DateTime happenedAt) async {
    final matomeId = state.id;
    AppLog.event(LogCat.action, 'editDateTime $matomeId');
    await _ref
        .read(matomeSyncServiceProvider)
        .editMatome(matomeId, happenedAt: happenedAt);
    if (!mounted) return;
    await load();
  }

  /// Archive (soft-delete) this Matome — the local-first, offline-first triage
  /// action (task #1410 / #1431-W1). Stamps `archived_at` in Drift FIRST so it
  /// leaves every local list immediately; the Core POST is best-effort and may
  /// throw (offline / server error) WITHOUT reverting the local archive — the
  /// next pull reconciles. Recoverable via [restore] (the Undo affordance). The
  /// matome id is captured up front: the sync awaits can outlive an autoDispose
  /// of this notifier, after which reading `state` would throw.
  Future<void> archive() async {
    final matomeId = state.id;
    AppLog.event(LogCat.action, 'archive $matomeId');
    await _ref.read(matomeSyncServiceProvider).archiveMatome(matomeId);
  }

  /// Restore (un-archive) this Matome — the Undo affordance for an archive, and
  /// the action wired to the archived-detail banner (#1431-I1). Local-first /
  /// offline-first: clears `archived_at` in Drift immediately, then best-effort
  /// POSTs Core; a failed Core leg reconciles on the next pull.
  Future<void> restore() async {
    final matomeId = state.id;
    AppLog.event(LogCat.action, 'restore $matomeId');
    await _ref.read(matomeSyncServiceProvider).restoreMatome(matomeId);
  }

  /// Remove an Item (recording) from this Matome: delete the row, its on-device
  /// file (best-effort), mark the aggregated summary stale (the item set
  /// changed), and reload so the hub drops it.
  Future<void> removeItem(String recordingId, {String? filePath}) async {
    final matomeId = state.id;
    AppLog.event(LogCat.action, 'removeItem $recordingId from $matomeId');
    await _itemsDao.deleteWithPayload(recordingId, _itemOwnerId);
    if (filePath != null && filePath.isNotEmpty) {
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Best-effort: a missing/locked file must not block removal.
      }
    }
    await _dao.markSummaryStale(matomeId, true);
    if (!mounted) return;
    await load();
  }
}

/// Client-side import size ceiling, mirroring the Core upload cap (#1448): a
/// file larger than this is rejected before any durable copy / DB write, so an
/// oversize pick never reaches the upload queue (where Core would 413) nor OOMs
/// the durable copy. 25 MB.
const int kMaxImportFileBytes = 25 * 1024 * 1024;

/// Thrown by [MatomeDetailController.addFile] when the picked file exceeds
/// [kMaxImportFileBytes]. Carries the offending size + name so the UI can build
/// a user-facing message; nothing is persisted when this throws.
class FileTooLargeException implements Exception {
  const FileTooLargeException({required this.sizeBytes, required this.name});

  final int sizeBytes;
  final String name;

  /// The cap in whole megabytes — for the user message ("max 25 MB").
  int get maxMegabytes => kMaxImportFileBytes ~/ (1024 * 1024);

  @override
  String toString() =>
      'FileTooLargeException($name is $sizeBytes bytes, '
      'max $kMaxImportFileBytes)';
}

String _titleFromName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final trimmed = base.trim();
  return trimmed.isEmpty ? 'Untitled' : trimmed;
}

/// The lower-case extension of [name] (no leading dot), or NULL when the file
/// has no extension. Mirrors [mediaTypeForPath]'s extension extraction so the
/// persisted `originalExtension` agrees with the derived `mediaType`.
/// Family provider keyed by the Matome id (the Drift TEXT id from the route).
final matomeDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<MatomeDetailController, MatomeDetailState, String>(
      (ref, id) => MatomeDetailController(ref, id),
    );
