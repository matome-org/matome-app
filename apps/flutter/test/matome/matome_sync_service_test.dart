import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/contacts/contact.dart';
import 'package:matome_flutter/features/contacts/contacts_repository.dart';
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matome_sync_service.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

// ---------------------------------------------------------------------------
// Fake repositories — no live backend. Each records the calls the sync service
// made and returns canned remote data (mirrors the recordings sync test style).
// ---------------------------------------------------------------------------

ApiClient _client() =>
    ApiClient(tokenStore: InMemoryTokenStore(), dio: Dio()..close());

class FakeMatomesRepository extends MatomesRepository {
  FakeMatomesRepository({this.remoteMatomes = const []})
      : super(apiClient: _client());

  List<Matome> remoteMatomes;

  int _nextId = 1000;
  final List<Map<String, Object?>> created = [];
  final List<Map<String, Object?>> attached = [];
  final List<Map<String, Object?>> detached = [];

  @override
  Future<List<Matome>> fetchMatomes() async => remoteMatomes;

  @override
  Future<Matome> createMatome({
    required String title,
    required int workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    final id = _nextId++;
    created.add({'title': title, 'workspace_id': workspaceId, 'id': id});
    return Matome(
      id: id,
      ownerId: '1',
      title: title,
      workspaceId: workspaceId,
      description: description,
      aggregatedSummary: aggregatedSummary,
    );
  }

  @override
  Future<void> attachContact({
    required int matomeId,
    required int contactId,
    String role = 'attendee',
  }) async {
    attached.add({'matome': matomeId, 'contact': contactId, 'role': role});
  }

  @override
  Future<void> detachContact({
    required int matomeId,
    required int contactId,
  }) async {
    detached.add({'matome': matomeId, 'contact': contactId});
  }
}

class FakeContactsRepository extends ContactsRepository {
  FakeContactsRepository({this.remoteContacts = const []})
      : super(apiClient: _client());

  List<Contact> remoteContacts;

  int _nextId = 2000;
  final List<Map<String, Object?>> created = [];

  @override
  Future<List<Contact>> fetchContacts() async => remoteContacts;

  @override
  Future<Contact> createContact({
    required String displayName,
    String? metadata,
    String? linkedUserId,
  }) async {
    final id = _nextId++;
    created.add({'display_name': displayName, 'id': id});
    return Contact(id: id, ownerId: '1', displayName: displayName);
  }
}

class FakeRecordingsRepository extends RecordingsRepository {
  FakeRecordingsRepository() : super(apiClient: _client());

  final List<Map<String, Object?>> patched = [];

  @override
  Future<Recording> updateRecording(
    int id, {
    String? transcript,
    String? summary,
    String? title,
    String? badge,
    int? workspaceId,
    int? matomeId,
    bool clearWorkspace = false,
  }) async {
    patched.add({'id': id, 'matome_id': matomeId});
    return Recording(
      id: id,
      ownerId: 1,
      title: title ?? 'r',
      status: RecordingStatus.done,
      matomeId: matomeId,
    );
  }
}

ProviderContainer _container(
  AppDatabase db, {
  FakeMatomesRepository? matomes,
  FakeContactsRepository? contacts,
  FakeRecordingsRepository? recordings,
}) {
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    matomesRepositoryProvider.overrideWithValue(matomes ?? FakeMatomesRepository()),
    contactsRepositoryProvider
        .overrideWithValue(contacts ?? FakeContactsRepository()),
    recordingsRepositoryProvider
        .overrideWithValue(recordings ?? FakeRecordingsRepository()),
  ]);
  return container;
}

/// Seed a Core-backed Space (a numeric workspace id is the "Core-backed"
/// convention, mirroring the recordings sync). Returns the id as TEXT.
Future<String> _seedCoreSpace(AppDatabase db, int coreId) async {
  await db.into(db.workspaces).insert(
        WorkspacesCompanion.insert(
          id: '$coreId',
          name: 'Space $coreId',
          createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        ),
      );
  return '$coreId';
}

Future<String> _seedMatome(
  AppDatabase db, {
  required String id,
  String? spaceId,
  int? coreId,
  String title = 'Meeting',
  String? aggregatedSummary,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      coreId: Value(coreId),
      title: Value(title),
      aggregatedSummary: Value(aggregatedSummary),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );
  return id;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a FILED matome (spaceId set) is pushed → remote created → local coreId '
      'set', () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_a', spaceId: space, title: 'Filed');

    final matomesRepo = FakeMatomesRepository();
    final container = _container(db, matomes: matomesRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();

    expect(matomesRepo.created, hasLength(1));
    expect(matomesRepo.created.single['workspace_id'], 42);
    final row = await db.matomesDao.getById('mat_local_a');
    expect(row!.coreId, isNotNull); // reconciled (no PK remap)
    expect(row.id, 'mat_local_a'); // PK unchanged
  });

  test('an INBOX matome (spaceId null) is NEVER pushed', () async {
    await _seedMatome(db, id: 'mat_local_inbox', spaceId: null);

    final matomesRepo = FakeMatomesRepository();
    final container = _container(db, matomes: matomesRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();

    expect(matomesRepo.created, isEmpty); // inbox matome stayed local-only
    final row = await db.matomesDao.getById('mat_local_inbox');
    expect(row!.coreId, isNull);
  });

  test('reconciliation matches by coreId — re-sync does NOT create a duplicate '
      'remote', () async {
    final space = await _seedCoreSpace(db, 42);
    // Already reconciled (coreId 500).
    await _seedMatome(db, id: 'mat_local_b', spaceId: space, coreId: 500);

    final matomesRepo = FakeMatomesRepository();
    final container = _container(db, matomes: matomesRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();
    await container.read(matomeSyncServiceProvider).pushFiled();

    expect(matomesRepo.created, isEmpty); // already has a coreId → no re-create
  });

  test('child-before-parent: a recording sends its matome_id only AFTER its '
      'matome has a coreId', () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_c', spaceId: space, title: 'Parent');

    // A reconciled child recording (coreId 7) under the not-yet-pushed matome.
    await db.recordingsDao.upsertRecordingWithMatome(
      RecordingsCompanion.insert(
        id: 'rec_local_child',
        title: 'Child',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        coreId: const Value(7),
        matomeId: const Value('mat_local_c'),
      ),
    );

    final matomesRepo = FakeMatomesRepository();
    final recordingsRepo = FakeRecordingsRepository();
    final container =
        _container(db, matomes: matomesRepo, recordings: recordingsRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();

    // Matome was created first; its new coreId is what the child sends.
    final matomeCoreId = matomesRepo.created.single['id'] as int;
    expect(recordingsRepo.patched, hasLength(1));
    expect(recordingsRepo.patched.single['id'], 7); // PATCH /api/recordings/7
    expect(recordingsRepo.patched.single['matome_id'], matomeCoreId);
  });

  test('child-before-parent: a child with NO coreId does NOT send matome_id',
      () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_d', spaceId: space);

    // A local-only child (coreId NULL) — not reconciled with Core yet.
    await db.recordingsDao.upsertRecordingWithMatome(
      RecordingsCompanion.insert(
        id: 'rec_local_unsynced',
        title: 'Unsynced child',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        matomeId: const Value('mat_local_d'),
      ),
    );

    final recordingsRepo = FakeRecordingsRepository();
    final container = _container(db, recordings: recordingsRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();

    expect(recordingsRepo.patched, isEmpty); // no matome_id sent for it
  });

  test('contacts pushed: an untagged local contact is created on Core, its '
      'coreId reconciled, then attached', () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_e', spaceId: space);
    // A local-only contact (coreId NULL), tagged in the matome.
    await db.contactsDao.create(
      ContactsCompanion.insert(
        id: 'contact_local_x',
        ownerId: 'user_1',
        displayName: 'Ada',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    await db.contactsDao.addContactToMatome(
      matomeId: 'mat_local_e',
      contactId: 'contact_local_x',
      role: 'organizer',
    );

    final matomesRepo = FakeMatomesRepository();
    final contactsRepo = FakeContactsRepository();
    final container =
        _container(db, matomes: matomesRepo, contacts: contactsRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pushFiled();

    expect(contactsRepo.created, hasLength(1)); // contact created on Core
    final contactRow = await db.contactsDao.getById('contact_local_x');
    expect(contactRow!.coreId, isNotNull); // reconciled
    expect(matomesRepo.attached, hasLength(1));
    expect(matomesRepo.attached.single['contact'], contactRow.coreId);
    expect(matomesRepo.attached.single['role'], 'organizer');
  });

  test('contacts upsert by coreId on pull — no duplicate row on re-sync',
      () async {
    final remote = [
      Contact(id: 5, ownerId: '1', displayName: 'Ada', metadata: '{"e":"a"}'),
    ];
    final contactsRepo = FakeContactsRepository(remoteContacts: remote);
    final container = _container(db, contacts: contactsRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pullContacts();
    await container.read(matomeSyncServiceProvider).pullContacts();

    final all = await db.contactsDao.listContacts();
    expect(all, hasLength(1)); // upsert by coreId — no dup
    expect(all.single.coreId, 5);
    expect(all.single.displayName, 'Ada');
  });

  test('merge-guards on a sparse pull preserve local aggregated_summary and '
      'spaceId', () async {
    final space = await _seedCoreSpace(db, 42);
    // A reconciled matome (coreId 9) with a good local aggregated_summary, filed.
    await _seedMatome(
      db,
      id: 'mat_local_f',
      spaceId: space,
      coreId: 9,
      title: 'Has summary',
      aggregatedSummary: 'good local rollup',
    );

    // Core list returns id 9 with NO aggregated_summary and NO workspace_id
    // (a sparse payload). The merge-guards must NOT wipe the local values.
    final remote = [
      Matome(id: 9, ownerId: '1', title: 'Has summary'),
    ];
    final matomesRepo = FakeMatomesRepository(remoteMatomes: remote);
    final container = _container(db, matomes: matomesRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pullMatomes();

    final row = await db.matomesDao.getById('mat_local_f');
    expect(row!.aggregatedSummary, 'good local rollup'); // preserved
    expect(row.spaceId, space); // local filed Space preserved (not wiped to null)
    // No duplicate row under PK '9'.
    expect(await db.matomesDao.getById('9'), isNull);
  });

  test('merge-survival: a sparse pull that omits a local contact edge does NOT '
      'drop it', () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_g', spaceId: space, coreId: 11);
    // A local contact (already reconciled to coreId 5) tagged in the matome.
    await db.contactsDao.create(
      ContactsCompanion.insert(
        id: 'contact_local_keep',
        ownerId: 'user_1',
        displayName: 'Keep me',
        coreId: const Value(5),
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    await db.contactsDao.addContactToMatome(
      matomeId: 'mat_local_g',
      contactId: 'contact_local_keep',
      role: 'attendee',
    );

    // Core returns the matome with an EMPTY contact set (sparse: the edge wasn't
    // returned). Set-merge survival: the local edge must NOT be dropped.
    final remote = [
      Matome(id: 11, ownerId: '1', title: 'Meeting', workspaceId: 42),
    ];
    final matomesRepo = FakeMatomesRepository(remoteMatomes: remote);
    final container = _container(db, matomes: matomesRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).pullMatomes();

    final edges = await db.contactsDao.listContactsForMatome('mat_local_g');
    expect(edges, hasLength(1)); // local edge survived the sparse pull
    expect(edges.single.contact.id, 'contact_local_keep');
  });

  test('pull adds a remote contact edge idempotently (no duplicate on re-sync)',
      () async {
    final space = await _seedCoreSpace(db, 42);
    await _seedMatome(db, id: 'mat_local_h', spaceId: space, coreId: 12);

    // Contacts are pulled first (id 5 → local row), then the matome whose edge
    // references contact_id 5. The edge add is idempotent.
    final contactsRepo = FakeContactsRepository(remoteContacts: [
      Contact(id: 5, ownerId: '1', displayName: 'Ada'),
    ]);
    final matomesRepo = FakeMatomesRepository(remoteMatomes: [
      Matome(
        id: 12,
        ownerId: '1',
        title: 'Meeting',
        workspaceId: 42,
        contacts: const [MatomeContactEdge(contactId: 5, role: 'speaker')],
      ),
    ]);
    final container =
        _container(db, matomes: matomesRepo, contacts: contactsRepo);
    addTearDown(container.dispose);

    await container.read(matomeSyncServiceProvider).sync();
    await container.read(matomeSyncServiceProvider).sync();

    final edges = await db.contactsDao.listContactsForMatome('mat_local_h');
    expect(edges, hasLength(1)); // idempotent add — no dup edge
    expect(edges.single.role, 'speaker');
  });
}
