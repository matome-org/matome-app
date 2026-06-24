import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/spaces/space_detail_screen.dart';
import 'package:matome_flutter/features/spaces/spaces_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Widget tests for the Spaces tab (S5, #784): list renders with counts, the
/// FAB-create modal adds a space, long-press + confirm deletes a space (and the
/// recordings return to the Inbox), and the detail screen lists the workspace's
/// recordings and routes on tap.

Future<void> _seedRecording(
  AppDatabase db, {
  required String id,
  String title = 'Recording',
  String? workspaceId,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: Value(id),
      title: Value(title),
      timestamp: const Value(''),
      duration: const Value(''),
      badge: const Value('Inbox'),
      isProcessing: const Value(0),
      audioFilePath: const Value(''),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      mediaType: const Value('audio'),
      processingStatus: const Value('done'),
      workspaceId: Value(workspaceId),
    ),
  );
}

/// Seeds a Matome filed into [spaceId] (#1378) — the unit the Space detail now
/// lists.
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'Matome',
  String? spaceId,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      spaceId: Value(spaceId),
      happenedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    ),
  );
}

String? _lastRoute;

Widget _app(AppDatabase db) {
  _lastRoute = null;
  final router = GoRouter(
    initialLocation: '/spaces',
    routes: [
      GoRoute(
        path: '/spaces',
        builder: (_, _) => const SpacesScreen(),
        routes: [
          GoRoute(
            path: ':spaceId',
            builder: (_, state) =>
                SpaceDetailScreen(spaceId: state.pathParameters['spaceId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/matome/:id',
        builder: (_, state) {
          _lastRoute = '/matome/${state.pathParameters['id']}';
          return const Scaffold(body: Text('matome-stub'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: TranslationProvider(
      child: MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('renders the space list with names and counts', (tester) async {
    final work = await db.workspacesDao.createWorkspace('Work');
    await db.workspacesDao.createWorkspace('Ideas');
    await _seedRecording(db, id: 'a', workspaceId: work.id);
    await _seedRecording(db, id: 'b', workspaceId: work.id);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('Pessoal'), findsOneWidget); // seeded default
    // The master now renders the real [SpaceSyncTile]; its meta line is the
    // proposal's "N matomes" format (driven off the same count).
    expect(find.text(t.spaces.matomeCount(n: 2)), findsOneWidget); // Work
    // Ideas + Pessoal both have 0 items.
    expect(find.text(t.spaces.matomeCount(n: 0)), findsNWidgets(2));
  });

  testWidgets('shows only the seeded default when no spaces were created', (
    tester,
  ) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // The default "Pessoal" workspace is always present (mobile parity), so the
    // empty state never shows; the default tile renders instead.
    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text(t.spaces.empty), findsNothing);
  });

  testWidgets('create modal adds a space', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Marketing');
    await tester.tap(find.byKey(const ValueKey('create-space-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Marketing'), findsOneWidget);
    expect(
      (await db.workspacesDao.getWorkspaces()).map((w) => w.name),
      containsAll(['Pessoal', 'Marketing']),
    );
  });

  testWidgets('long-press + confirm deletes the space and returns recordings '
      'to the Inbox', (tester) async {
    final work = await db.workspacesDao.createWorkspace('Work');
    await _seedRecording(db, id: 'a', workspaceId: work.id);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);

    await tester.longPress(find.byKey(ValueKey('space-tile-${work.id}')));
    await tester.pumpAndSettle();

    // Confirm dialog visible.
    expect(find.text(t.spaces.deleteTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-space-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);

    // Recording returned to the Inbox.
    final inbox = await db.recordingsDao.getInboxRecordings();
    expect(inbox.single.id, 'a');
    expect(inbox.single.workspaceId, isNull);
  });

  testWidgets('cancelling delete keeps the space', (tester) async {
    final work = await db.workspacesDao.createWorkspace('Work');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(ValueKey('space-tile-${work.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.spaces.cancel));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('tapping a space opens its detail listing its matomes', (
    tester,
  ) async {
    final work = await db.workspacesDao.createWorkspace('Work');
    await _seedMatome(
      db,
      id: 'a',
      title: 'In work space',
      spaceId: work.id,
    );
    await _seedMatome(db, id: 'inbox-one', title: 'Inbox only');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
    await tester.pumpAndSettle();

    expect(find.text('In work space'), findsOneWidget);
    expect(find.text('Inbox only'), findsNothing); // not in this space
  });

  testWidgets('tapping a matome in detail routes to /matome/:id', (
    tester,
  ) async {
    final work = await db.workspacesDao.createWorkspace('Work');
    await _seedMatome(
      db,
      id: 'mat-9',
      title: 'Routed',
      spaceId: work.id,
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('space-matome-mat-9')));
    await tester.pumpAndSettle();

    expect(_lastRoute, '/matome/mat-9');
    expect(find.text('matome-stub'), findsOneWidget);
  });

  testWidgets('detail shows empty state for a space with no matomes', (
    tester,
  ) async {
    final work = await db.workspacesDao.createWorkspace('Empty');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
    await tester.pumpAndSettle();

    expect(find.text(t.spaces.detailEmptyMatomes), findsOneWidget);
  });
}
