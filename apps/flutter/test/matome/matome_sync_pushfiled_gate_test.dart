// W6 #1501 / W4-audit #74801 P2 — the pushFiled DATA-EGRESS gate (plan #102,
// spec R2.1). This closes the LAST second sync-eligibility predicate outside the
// single resolver: matome/child egress now flows through the ONE operation-keyed
// gate `SyncPolicy.can(caller, Operation.spaceSync, space)` over the ONE
// resolver — NOT the legacy `int.tryParse(spaceId)` numeric-id heuristic.
//
// The egress sink is COUNTED via the fake repo's `created`/`patched` (a matome
// that reaches `createMatome` egressed; a child that reaches PATCH egressed) —
// not log scraping. A HELD matome never touches the sink and never reconciles a
// coreId.
//
// Dual-flag LFS lane (mise `flutter-design-system-check`): runs under BOTH
// `ff.localFirstSpaces=false` (gate compiled out → legacy numeric-id filter, the
// shipped reality) and `=true` (gate ON → local-space matomes HELD). Each group
// self-skips the wrong build so each invocation proves exactly its reality.

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/contacts/contact.dart';
import 'package:matome_flutter/features/contacts/contacts_repository.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matome_sync_service.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

ApiClient _client() =>
    ApiClient(tokenStore: InMemoryTokenStore(), dio: Dio()..close());

/// Counts matome egress (createMatome) and child PATCHes — the data-egress sink.
class _CountingMatomesRepository extends MatomesRepository {
  _CountingMatomesRepository() : super(apiClient: _client());

  int _nextId = 1000;
  final List<Map<String, Object?>> created = [];
  final List<int> archived = [];

  @override
  Future<List<Matome>> fetchMatomes() async => const [];

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
    return Matome(id: id, ownerId: '1', title: title, workspaceId: workspaceId);
  }

  @override
  Future<Matome> archiveMatome(int id) async {
    archived.add(id);
    return Matome(id: id, ownerId: '1', title: 'r', archivedAt: DateTime.now());
  }
}

class _FakeContactsRepository extends ContactsRepository {
  _FakeContactsRepository() : super(apiClient: _client());
  @override
  Future<List<Contact>> fetchContacts() async => const [];
}

class _FakeRecordingsRepository extends RecordingsRepository {
  _FakeRecordingsRepository() : super(apiClient: _client());
  final List<int> patched = [];
  @override
  Future<Recording> updateRecording(
    int id, {
    String? transcript,
    String? notes,
    String? summary,
    String? title,
    String? badge,
    int? workspaceId,
    int? matomeId,
    bool clearWorkspace = false,
  }) async {
    patched.add(id);
    return Recording(
        id: id, ownerId: '1', title: 'r', status: RecordingStatus.done);
  }
}

ProviderContainer _container(
  AppDatabase db,
  _CountingMatomesRepository matomes,
  _FakeRecordingsRepository recordings,
) {
  return ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    matomesRepositoryProvider.overrideWithValue(matomes),
    contactsRepositoryProvider.overrideWithValue(_FakeContactsRepository()),
    recordingsRepositoryProvider.overrideWithValue(recordings),
    // The gate's [Caller] reads this; override so the test never builds the real
    // auth chain. The id is the future-PDP input; `spaceSync` gates only on the
    // space being cloud, so it changes no assertion here.
    currentOwnerIdProvider.overrideWithValue('owner-1'),
  ]);
}

/// Seed a space with an explicit `is_local` bit at a numeric id (so the LEGACY
/// `int.tryParse` heuristic would PASS for both local and cloud — proving the
/// egress decision is the NEW resolver gate, not the numeric-id check).
Future<String> _seedSpace(AppDatabase db, {required bool isLocal, required int id}) async {
  await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        id: '$id',
        name: 'space-$id',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        isLocal: Value(isLocal ? 1 : 0),
      ));
  return '$id';
}

Future<String> _seedMatome(AppDatabase db, {required String id, String? spaceId}) async {
  await db.matomesDao.create(MatomesCompanion(
    id: Value(id),
    spaceId: Value(spaceId),
    title: const Value('M'),
    happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
  ));
  return id;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('flag ON — pushFiled routed through the gate', () {
    test('a LOCAL-space matome is NOT pushed; a CLOUD-space matome IS', () async {
      if (!FeatureFlags.localFirstSpaces) return; // self-skip under OFF build.

      final localSpace = await _seedSpace(db, isLocal: true, id: 11);
      final cloudSpace = await _seedSpace(db, isLocal: false, id: 22);
      await _seedMatome(db, id: 'mat_local_space', spaceId: localSpace);
      await _seedMatome(db, id: 'mat_cloud_space', spaceId: cloudSpace);

      final matomes = _CountingMatomesRepository();
      final container = _container(db, matomes, _FakeRecordingsRepository());
      addTearDown(container.dispose);

      await container.read(matomeSyncServiceProvider).pushFiled();

      // Only the cloud-space matome egressed (created on Core).
      expect(matomes.created, hasLength(1),
          reason: 'exactly the cloud-space matome is pushed');
      expect(matomes.created.single['workspace_id'], 22);

      // The local-space matome stayed local-only (no coreId reconciled).
      final localRow = await db.matomesDao.getById('mat_local_space');
      expect(localRow!.coreId, isNull,
          reason: 'a local-space matome is HELD — never egressed (#74801 P2)');
      final cloudRow = await db.matomesDao.getById('mat_cloud_space');
      expect(cloudRow!.coreId, isNotNull, reason: 'cloud-space matome reconciled');
    });

    test('a local-space matome holds its children too (no child PATCH)', () async {
      if (!FeatureFlags.localFirstSpaces) return;

      final localSpace = await _seedSpace(db, isLocal: true, id: 33);
      await _seedMatome(db, id: 'mat_local_kids', spaceId: localSpace);
      // A reconciled child (coreId 7) — under the legacy path it would PATCH.
      await db.recordingsDao.upsertRecordingWithMatome(
        RecordingsCompanion.insert(
          id: 'rec_child',
          title: 'Child',
          timestamp: '9',
          duration: '1',
          audioFilePath: '/tmp/a.m4a',
          createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
          coreId: const Value(7),
          matomeId: const Value('mat_local_kids'),
        ),
      );

      final matomes = _CountingMatomesRepository();
      final recordings = _FakeRecordingsRepository();
      final container = _container(db, matomes, recordings);
      addTearDown(container.dispose);

      await container.read(matomeSyncServiceProvider).pushFiled();

      expect(matomes.created, isEmpty, reason: 'local-space matome held');
      expect(recordings.patched, isEmpty,
          reason: 'a held matome never pushes its children either');
    });
  });

  group('flag OFF — legacy numeric-id filter (shipped reality unchanged)', () {
    test('a numeric-id matome pushes regardless of is_local (no gate)', () async {
      if (FeatureFlags.localFirstSpaces) return; // self-skip under ON build.

      // Under OFF the gate is compiled out — both numeric-id spaces push, exactly
      // the pre-#102 behaviour (filed + numeric id ⇒ pushed).
      final localSpace = await _seedSpace(db, isLocal: true, id: 11);
      final cloudSpace = await _seedSpace(db, isLocal: false, id: 22);
      await _seedMatome(db, id: 'mat_a', spaceId: localSpace);
      await _seedMatome(db, id: 'mat_b', spaceId: cloudSpace);

      final matomes = _CountingMatomesRepository();
      final container = _container(db, matomes, _FakeRecordingsRepository());
      addTearDown(container.dispose);

      await container.read(matomeSyncServiceProvider).pushFiled();

      expect(matomes.created, hasLength(2),
          reason: 'flag OFF: both numeric-id matomes push (byte-unchanged)');
    });
  });
}
