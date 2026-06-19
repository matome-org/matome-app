import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';

/// Deep-link redirect (#1378): an OLD recording-centric link (`:id` is a
/// recordingId) must resolve to its PARENT matome hub `/matome/<matomeId>` via
/// `recording.matomeId` — deterministic by the 1-rec→1-matome invariant. When a
/// recording has no parent matome, the redirect is a no-op (the legacy route's
/// own builder runs).

Future<String?> _redirect(WidgetRef ref, String? recordingId) async {
  if (recordingId == null) return null;
  final matomeId =
      await ref.read(matomesDaoProvider).matomeIdForRecording(recordingId);
  if (matomeId == null) return null;
  return '/matome/$matomeId';
}

String? _resolved;

Widget _app(AppDatabase db) {
  _resolved = null;
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: Consumer(
      builder: (context, ref, _) {
        final router = GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(
              path: '/start',
              builder: (_, _) => const Scaffold(body: Text('start')),
            ),
            GoRoute(
              path: '/inbox/:id',
              redirect: (_, state) => _redirect(ref, state.pathParameters['id']),
              builder: (_, state) {
                _resolved = '/inbox/${state.pathParameters['id']}';
                return const Scaffold(body: Text('legacy-recording'));
              },
            ),
            GoRoute(
              path: '/matome/:id',
              builder: (_, state) {
                _resolved = '/matome/${state.pathParameters['id']}';
                return const Scaffold(body: Text('matome-hub'));
              },
            ),
          ],
        );
        return MaterialApp.router(routerConfig: router);
      },
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(String recId, String matId) async {
    await db.matomesDao.create(
      MatomesCompanion.insert(
        id: matId,
        title: 'Parent',
        happenedAt: 1000,
        createdAt: 1000,
      ),
    );
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: recId,
        title: 'Child',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/$recId.m4a',
        createdAt: 1000,
        matomeId: Value(matId),
      ),
    );
  }

  testWidgets('a legacy recording link redirects to its parent matome', (
    tester,
  ) async {
    await seed('rec-1', 'mat-1');
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('start'));
    GoRouter.of(ctx).go('/inbox/rec-1');
    await tester.pumpAndSettle();

    expect(_resolved, '/matome/mat-1');
    expect(find.text('matome-hub'), findsOneWidget);
    expect(find.text('legacy-recording'), findsNothing);
  });

  testWidgets('a recording with no parent matome falls through (no redirect)', (
    tester,
  ) async {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: 'orphan',
        title: 'Orphan',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/orphan.m4a',
        createdAt: 1000,
      ),
    );
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('start'));
    GoRouter.of(ctx).go('/inbox/orphan');
    await tester.pumpAndSettle();

    expect(_resolved, '/inbox/orphan');
    expect(find.text('legacy-recording'), findsOneWidget);
  });
}
