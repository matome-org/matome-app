// W6 #1501 — file a LOOSE item DIRECTLY into a space (no matome) end-to-end
// (plan #102, .docs/internal/architecture.md §5). Three load-bearing invariants:
//
//   1. owner-scope authz on the assign — a NON-owner cannot file another owner's
//      row (the local write is owner-scoped; a forged id moves zero rows).
//   2. filing into a LOCAL space HOLDS locally (the file-move sticks) but does
//      NOT egress (no Core PATCH) — filing ≠ sync, enforced by the GATE.
//   3. filing into a CLOUD space DOES egress (Core PATCH) — sync follows the
//      space TYPE, not the picker.
//
// Egress is COUNTED via the fake repo's `updateCalls` (a row that reaches PATCH
// egressed). Dual-flag LFS lane: the egress GATE only exists under
// `ff.localFirstSpaces=true`; the OFF group proves filing still writes locally
// and the legacy numeric-id egress path is unchanged.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

import 'package:dio/dio.dart';

const _owner = 'owner-1';
const _otherOwner = 'owner-2';

class _CountingRepository extends RecordingsRepository {
  _CountingRepository()
      : super(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio()..close(),
          ),
        );

  /// PATCH /api/recordings/:id egress calls (the file-into-space sync sink).
  int updateCalls = 0;
  final List<int?> patchedWorkspaceIds = [];

  @override
  Future<List<Recording>> fetchRecordings() async => const [];

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
    updateCalls++;
    patchedWorkspaceIds.add(workspaceId);
    return Recording(
        id: id, ownerId: '1', title: 'r', status: RecordingStatus.done);
  }
}

ProviderContainer _container(AppDatabase db, _CountingRepository repo,
    {String owner = _owner}) {
  return ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    recordingsRepositoryProvider.overrideWithValue(repo),
    currentOwnerIdProvider.overrideWithValue(owner),
  ]);
}

Future<String> _seedSpace(AppDatabase db,
    {required bool isLocal, required int id}) async {
  await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        id: '$id',
        name: 'space-$id',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        isLocal: Value(isLocal ? 1 : 0),
      ));
  return '$id';
}

/// A LOOSE, reconciled recording (coreId set so the legacy numeric-id PATCH
/// would fire) owned by [ownerId].
Future<String> _seedLoose(AppDatabase db, String ownerId, {int coreId = 900}) async {
  final id = 'rec_${ownerId}_${DateTime.now().microsecondsSinceEpoch}';
  await db.recordingsDao.insertRecording(RecordingsCompanion.insert(
    id: id,
    coreId: Value(coreId),
    title: 'Memo',
    timestamp: '9',
    duration: '1',
    audioFilePath: '/tmp/a',
    ownerId: Value(ownerId),
    createdAt: DateTime.now().millisecondsSinceEpoch,
  ));
  return id;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('owner-scope: a NON-owner cannot file another owner\'s loose item',
      () async {
    final cloudSpace = await _seedSpace(db, isLocal: false, id: 22);
    final row = await _seedLoose(db, _owner); // owned by owner-1

    final repo = _CountingRepository();
    // The acting caller is owner-2 (a different user).
    final container = _container(db, repo, owner: _otherOwner);
    addTearDown(container.dispose);

    final inbox = container.read(inboxControllerProvider.notifier);
    final ok = await inbox.fileIntoSpace(row, cloudSpace, ownerId: _otherOwner);

    expect(ok, isFalse, reason: 'a non-owner assign moves zero rows');
    final after = await db.recordingsDao.getRecordingById(row);
    expect(after!.workspaceId, isNull,
        reason: 'the other owner\'s file is untouched');
    expect(repo.updateCalls, 0, reason: 'no egress for a rejected assign');
  });

  group('flag ON — sync follows the space type (gate active)', () {
    test('file into a LOCAL space: holds locally, NO egress', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final localSpace = await _seedSpace(db, isLocal: true, id: 11);
      final row = await _seedLoose(db, _owner);

      final repo = _CountingRepository();
      final container = _container(db, repo);
      addTearDown(container.dispose);

      final ok = await container
          .read(inboxControllerProvider.notifier)
          .fileIntoSpace(row, localSpace, ownerId: _owner);

      expect(ok, isTrue, reason: 'owner filed the row');
      final after = await db.recordingsDao.getRecordingById(row);
      expect(after!.workspaceId, localSpace,
          reason: 'the local file-move HOLDS (filing ≠ sync)');
      expect(repo.updateCalls, 0,
          reason: 'filing into a LOCAL space must NOT egress (gate held it)');
    });

    test('file into a CLOUD space: holds locally AND egresses (PATCH)', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final cloudSpace = await _seedSpace(db, isLocal: false, id: 22);
      final row = await _seedLoose(db, _owner);

      final repo = _CountingRepository();
      final container = _container(db, repo);
      addTearDown(container.dispose);

      final ok = await container
          .read(inboxControllerProvider.notifier)
          .fileIntoSpace(row, cloudSpace, ownerId: _owner);

      expect(ok, isTrue);
      final after = await db.recordingsDao.getRecordingById(row);
      expect(after!.workspaceId, cloudSpace);
      expect(repo.updateCalls, 1,
          reason: 'filing into a CLOUD space DOES egress (sync follows type)');
      expect(repo.patchedWorkspaceIds.single, 22);
    });

    test('file back to Inbox (null space): purely local, no egress', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final cloudSpace = await _seedSpace(db, isLocal: false, id: 22);
      final row = await _seedLoose(db, _owner);
      final repo = _CountingRepository();
      final container = _container(db, repo);
      addTearDown(container.dispose);
      final inbox = container.read(inboxControllerProvider.notifier);

      await inbox.fileIntoSpace(row, cloudSpace, ownerId: _owner); // → cloud
      repo.updateCalls = 0;
      final ok = await inbox.fileIntoSpace(row, null, ownerId: _owner); // → Inbox

      expect(ok, isTrue);
      final after = await db.recordingsDao.getRecordingById(row);
      expect(after!.workspaceId, isNull, reason: 'cleared back to Inbox');
      expect(repo.updateCalls, 0, reason: 'clearing the space never egresses');
    });
  });

  group('flag OFF — filing writes locally; legacy numeric-id egress', () {
    test('file into a space writes locally and PATCHes (no gate)', () async {
      if (FeatureFlags.localFirstSpaces) return;
      final localSpace = await _seedSpace(db, isLocal: true, id: 11);
      final row = await _seedLoose(db, _owner);

      final repo = _CountingRepository();
      final container = _container(db, repo);
      addTearDown(container.dispose);

      final ok = await container
          .read(inboxControllerProvider.notifier)
          .fileIntoSpace(row, localSpace, ownerId: _owner);

      expect(ok, isTrue);
      final after = await db.recordingsDao.getRecordingById(row);
      expect(after!.workspaceId, localSpace, reason: 'local write holds');
      // OFF: no gate → the legacy numeric-id path PATCHes (byte-unchanged).
      expect(repo.updateCalls, 1,
          reason: 'flag OFF: numeric-id space PATCHes (no gate)');
    });
  });
}
