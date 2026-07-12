import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';
import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/home/inbox_effective_view.dart';
import 'package:matome_flutter/features/home/loose_inbox_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

/// W3 (local-first-spaces #102): the Inbox is the VIEW over effective-space-NULL
/// — LOOSE items (no matome, no space) AND DRAFT matomes (no space). With the
/// flag ON the loose half surfaces; with it OFF the loose lane is empty and the
/// Inbox is byte-unchanged. Membership is computed ONLY through the one resolver
/// ([EffectiveSpace], via `inbox_effective_view.dart`), never re-derived inline.
///
/// `FeatureFlags.localFirstSpaces` is a compile-time const, so this file is run
/// TWICE by the design-system gate (forced OFF / forced ON). Each lane group
/// self-skips under the wrong build.
const _flagOn = bool.fromEnvironment(
  'ff.localFirstSpaces',
  defaultValue: false,
);

/// Seed a recording row. Loose ⟺ both [matomeId] and [workspaceId] NULL.
Future<void> _seedRecording(
  AppDatabase db, {
  required String id,
  String title = 'Memo',
  String? matomeId,
  String? workspaceId,
  String mediaType = 'audio',
  int createdAt = 1000,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion.insert(
      id: id,
      title: title,
      timestamp: '9:00 AM',
      duration: '0:30',
      audioFilePath: '/tmp/$id.m4a',
      createdAt: createdAt,
      mediaType: Value(mediaType),
      matomeId: Value(matomeId),
      workspaceId: Value(workspaceId),
    ),
  );
}

/// Seed a matome row. Draft ⟺ [spaceId] NULL.
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'Matome',
  String? spaceId,
  int happenedAt = 1000,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      happenedAt: happenedAt,
      createdAt: happenedAt,
      spaceId: Value(spaceId),
    ),
  );
}

Future<void> _seedSpace(AppDatabase db, String id, String name) {
  return db.into(db.workspaces).insert(
        WorkspacesCompanion.insert(id: id, name: name, createdAt: 0),
      );
}

/// A repo whose Core fetch returns nothing — the loose controller listens to the
/// recording-level [inboxControllerProvider] (which runs a Core `refresh()` on
/// construction), so the repo must be stubbed to keep the test offline/DB-only.
class _EmptyRepo extends RecordingsRepository {
  _EmptyRepo({required super.apiClient});

  @override
  Future<List<Recording>> fetchRecordings() async => const [];
}

ProviderContainer _container(AppDatabase db) => ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(
        _EmptyRepo(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
          ),
        ),
      ),
      currentOwnerIdProvider.overrideWithValue('1'),
    ]);

void main() {
  // ── Pure resolver-routed predicate (flag-independent) ─────────────────────
  group('inbox_effective_view — resolver-routed predicate', () {
    test('a loose item (matome NULL, space NULL) is in the Inbox', () {
      expect(
        isInboxLooseItem(matomeSpaceId: null, workspaceId: null),
        isTrue,
      );
    });

    test('a directly-filed item (own space set) is NOT in the Inbox', () {
      expect(
        isInboxLooseItem(matomeSpaceId: null, workspaceId: 'ws_1'),
        isFalse,
      );
    });

    test('an item in a FILED matome (matome space wins) is NOT in the Inbox',
        () {
      // matome WINS — even with a null own space the matome-space makes it filed.
      expect(
        isInboxLooseItem(matomeSpaceId: 'ws_1', workspaceId: null),
        isFalse,
      );
    });
  });

  group('lane: ff.localFirstSpaces=true (ON / loose + draft surface)', () {
    test(
      'the loose controller surfaces ONLY loose items — not items inside a '
      'matome, not filed items (effective space NULL via the resolver)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedSpace(db, 'ws_1', 'Work');
        // (a) a LOOSE item — should surface.
        await _seedRecording(db, id: 'loose_1', title: 'Loose note');
        // (b) an item INSIDE a draft matome — belongs to the matome card, NOT
        //     the loose list (it has a matomeId).
        await _seedMatome(db, id: 'mat_draft');
        await _seedRecording(db, id: 'in_matome', matomeId: 'mat_draft');
        // (c) a directly FILED item — effective space NON-null → excluded.
        await _seedRecording(db, id: 'filed', workspaceId: 'ws_1');

        final container = _container(db);
        addTearDown(container.dispose);

        // Settle the controller's initial async load.
        await container
            .read(looseInboxControllerProvider.notifier)
            .reloadFromLocal();
        final loose =
            container.read(looseInboxControllerProvider).requireValue;

        expect(loose.map((i) => i.id), ['loose_1'],
            reason: 'only the loose item surfaces in the loose Inbox lane');
      },
      skip: _flagOn ? false : 'ON-only lane',
    );

    test(
      'draft matomes surface via the resolver-routed filter (spaceId NULL only)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedSpace(db, 'ws_1', 'Work');
        await _seedMatome(db, id: 'mat_draft', title: 'Draft');
        await _seedMatome(db, id: 'mat_filed', title: 'Filed', spaceId: 'ws_1');

        // listInboxMatomeItems already narrows to spaceId NULL; the resolver
        // filter confirms membership without a second inline predicate.
        final inbox = await db.matomesDao.listInboxMatomeItems();
        final drafts = inboxDraftMatomes(inbox);

        expect(drafts.map((m) => m.id), ['mat_draft']);
      },
      skip: _flagOn ? false : 'ON-only lane',
    );

    test(
      'flag ON: both card kinds are present — at least one loose item AND one '
      'draft matome have effective space NULL together',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedRecording(db, id: 'loose_1');
        await _seedMatome(db, id: 'mat_draft');

        final container = _container(db);
        addTearDown(container.dispose);
        await container
            .read(looseInboxControllerProvider.notifier)
            .reloadFromLocal();

        final loose =
            container.read(looseInboxControllerProvider).requireValue;
        final drafts =
            inboxDraftMatomes(await db.matomesDao.listInboxMatomeItems());

        expect(loose, isNotEmpty, reason: 'loose card kind present');
        expect(drafts, isNotEmpty, reason: 'draft matome card kind present');
      },
      skip: _flagOn ? false : 'ON-only lane',
    );
  });

  group('lane: ff.localFirstSpaces=false (OFF / byte-unchanged)', () {
    test(
      'the loose controller is INERT — empty list, no loose items surface even '
      'when loose rows exist (Inbox stays matome-only)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        // A loose row exists in the DB, but the OFF lane must never surface it.
        await _seedRecording(db, id: 'loose_1');

        final container = _container(db);
        addTearDown(container.dispose);

        await container
            .read(looseInboxControllerProvider.notifier)
            .reloadFromLocal();
        final loose =
            container.read(looseInboxControllerProvider).requireValue;

        expect(loose, isEmpty,
            reason: 'flag OFF: the loose lane is inert (matome-only Inbox)');
      },
      skip: _flagOn ? 'OFF-only lane' : false,
    );
  });

  test('FeatureFlags.localFirstSpaces matches the lane', () {
    expect(FeatureFlags.localFirstSpaces, _flagOn);
  });
}
