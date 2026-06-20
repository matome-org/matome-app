import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_state.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/spaces_dao.dart';
import '../../core/db/matome_card.dart';
import '../../core/providers.dart';
import '../contacts/contacts_controller.dart' show kPlaceholderContactOwnerId;
import '../home/inbox_upload.dart'
    show DurableImportCopy, PickedUpload, durableImportCopy, mediaTypeForPath;
import '../recordings/recording_ids.dart';

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
  /// be present and is the default/most-prominent destination (ADR-0004).
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
/// Triage (ADR-0004) = enrich + FILE INTO A SPACE. [fileIntoSpace] sets
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
  RecordingsDao get _recordingsDao => _ref.read(recordingsDaoProvider);
  ContactsDao get _contactsDao => _ref.read(contactsDaoProvider);

  /// The current owner id used to scope the directory picker — `user_<coreId>`
  /// for a signed-in user, otherwise the single-user placeholder. Mirrors
  /// [ContactsController.ownerId] so the picker lists the same directory.
  String get _ownerId {
    final user = _ref.read(authStateProvider).user;
    return user == null ? kPlaceholderContactOwnerId : 'user_${user.id}';
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, notFound: false);
    final matome = await _dao.getMatomeWithRecordings(state.id);
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
  Future<void> attachContact(String contactId, {String role = 'attendee'}) async {
    await _contactsDao.addContactToMatome(
      matomeId: state.id,
      contactId: contactId,
      role: role,
    );
    await load();
  }

  /// Untag [contactId] from this Matome — EXPLICIT removal of the
  /// `matome_contacts` edge (set-merge rule: membership is never trimmed
  /// implicitly). Reloads so the chip disappears.
  Future<void> detachContact(String contactId) async {
    await _contactsDao.removeContactFromMatome(
      matomeId: state.id,
      contactId: contactId,
    );
    await load();
  }

  /// Change the edge [role] of an already-attached [contactId]. Reloads.
  Future<void> setContactRole(String contactId, String role) async {
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
  /// (ADR-0004). Exposed so the UI can mark it as the most-prominent option.
  Future<WorkspaceRow> defaultPersonalSpace() =>
      _spacesDao.ensureDefaultPersonalSpace();

  /// FILE this Matome into [spaceId] — the core triage action (ADR-0004): sets
  /// `space_id`, moving it out of the Inbox into the sync domain. Reloads so the
  /// screen reflects the filed state (and any inbox list elsewhere drops it).
  Future<void> fileIntoSpace(String spaceId) async {
    await _dao.fileIntoSpace(state.id, spaceId);
    await load();
  }

  /// Edit the Matome's notes (`description`). Marks the aggregated summary stale
  /// when the notes actually changed (the Matome content moved on).
  Future<void> saveNotes(String notes) async {
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
  /// (ADR-0003). Deterministic LOCAL composition via the DAO — no AI/backend
  /// call. Stores the rollup and clears the stale flag (or NULLs it when no Item
  /// has a summary yet). Reloads so the hub reflects the fresh summary.
  Future<void> regenerateSummary() async {
    await _dao.regenerateSummary(state.id);
    await load();
  }

  /// Import an image [file] as an Item (recording, `mediaType: 'image'`) of this
  /// Matome. Reuses the local-first upload insert path: the bytes are copied to
  /// durable app storage, then a `rec_local_<uuid>` row is upserted with this
  /// Matome's id via [RecordingsDao.upsertRecordingWithMatome]. The Matome's
  /// triage state (spaceId) is untouched.
  Future<void> addPhoto({required File file, required String name}) async {
    // Capture the matome id up front: the durable-copy / DAO awaits can outlive
    // an autoDispose of this notifier, and reading `state` afterwards throws.
    final matomeId = state.id;
    final picked = PickedUpload(
      file: file,
      title: _titleFromName(name),
      mediaType: mediaTypeForPath(file.path),
    );
    final stored = kIsWeb ? picked : await _durableCopy(picked);

    final now = DateTime.now();
    await _recordingsDao.upsertRecordingWithMatome(
      RecordingsCompanion(
        id: Value(mintLocalRecordingId()),
        matomeId: Value(matomeId),
        coreId: const Value(null),
        title: Value(stored.title),
        timestamp: Value(_clock(now)),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: Value(stored.file.path),
        createdAt: Value(now.millisecondsSinceEpoch),
        mediaType: const Value('image'),
        processingStatus: const Value(kProcessingStatusPendingUpload),
      ),
    );
    if (!mounted) return;
    await load();
  }
}

String _titleFromName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final trimmed = base.trim();
  return trimmed.isEmpty ? 'Untitled' : trimmed;
}

String _clock(DateTime when) {
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final minute = when.minute.toString().padLeft(2, '0');
  final period = when.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Family provider keyed by the Matome id (the Drift TEXT id from the route).
final matomeDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<MatomeDetailController, MatomeDetailState, String>(
  (ref, id) => MatomeDetailController(ref, id),
);
