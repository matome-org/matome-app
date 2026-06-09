import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/details/details_screen.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Records the requests the mock adapter sees so tests can assert the Core
/// side-effects (PATCH on save, POST /process on retry).
class _Recorder {
  final List<String> patched = [];
  final List<String> processed = [];
  final List<String> deleted = [];
}

ProviderContainer _container(AppDatabase db, _Recorder rec) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:4000',
    validateStatus: (s) => s != null && s < 500,
  ));
  final adapter = DioAdapter(dio: dio);

  // download-url -> none, so the audio player stays inert (no platform calls).
  adapter.onGet(
    RegExp(r'/api/recordings/\d+/download-url'),
    (server) => server.reply(404, {'error': 'not_found'}),
  );
  // PATCH (save) succeeds and echoes the recording.
  adapter.onPatch(
    RegExp(r'/api/recordings/\d+'),
    (server) {
      rec.patched.add('patched');
      return server.reply(200, {
        'recording': {
          'id': 5,
          'owner_id': 1,
          'title': 'Test rec',
          'status': 'done',
          'transcript': 'edited body',
        }
      });
    },
    data: Matchers.any,
  );
  // POST /process (retry) -> 202 pending; poll then returns done.
  adapter.onPost(
    RegExp(r'/api/recordings/\d+/process'),
    (server) {
      rec.processed.add('processed');
      return server.reply(202, {
        'recording': {
          'id': 5,
          'owner_id': 1,
          'title': 'Test rec',
          'status': 'pending',
        }
      });
    },
  );
  adapter.onGet(
    RegExp(r'/api/recordings/\d+$'),
    (server) => server.reply(200, {
      'recording': {
        'id': 5,
        'owner_id': 1,
        'title': 'Test rec',
        'status': 'done',
        'summary': 'fresh summary',
        'transcript': 'fresh transcript',
      }
    }),
  );
  adapter.onDelete(
    RegExp(r'/api/recordings/\d+'),
    (server) {
      rec.deleted.add('deleted');
      return server.reply(204, null);
    },
  );

  final repo = RecordingsRepository(
    apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
  );
  return ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    recordingsRepositoryProvider.overrideWithValue(repo),
  ]);
}

Future<void> _seed(
  AppDatabase db, {
  String notes = 'initial notes',
  String processingStatus = 'done',
  int isProcessing = 0,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: const Value('5'),
      title: const Value('Test rec'),
      timestamp: const Value('9:00 AM'),
      duration: const Value('0:30'),
      badge: const Value('Inbox'),
      isProcessing: Value(isProcessing),
      audioFilePath: const Value(''),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      notes: Value(notes),
      mediaType: const Value('audio'),
      processingStatus: Value(processingStatus),
    ),
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: const MaterialApp(home: DetailsScreen(id: '5')),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _Recorder rec;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    rec = _Recorder();
  });
  tearDown(() => db.close());

  testWidgets('switches between the 3 tabs', (tester) async {
    await _seed(db);
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Notes tab is default — its edit toggle is visible.
    expect(find.byKey(const ValueKey('details-edit-toggle')), findsOneWidget);

    // Switch to Summary.
    await tester.tap(find.byKey(const ValueKey('segment-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('details-edit-toggle')), findsNothing);

    // Switch to Transcript.
    await tester.tap(find.byKey(const ValueKey('segment-transcript')));
    await tester.pumpAndSettle();
    expect(find.text('initial notes'), findsOneWidget); // raw transcript text

    // Back to Notes.
    await tester.tap(find.byKey(const ValueKey('segment-notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('details-edit-toggle')), findsOneWidget);
  });

  testWidgets('edit then save persists to Drift and Core', (tester) async {
    await _seed(db);
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Enter edit mode.
    await tester.tap(find.byKey(const ValueKey('details-edit-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('details-editor')), 'edited body');
    await tester.pumpAndSettle();

    // Save via FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Drift persisted.
    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.notes, 'edited body');
    // Core PATCH fired.
    expect(rec.patched, isNotEmpty);
  });

  testWidgets('isDirty blocks leaving until discarded', (tester) async {
    await _seed(db);
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('details-edit-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('details-editor')), 'unsaved change');
    await tester.pumpAndSettle();

    // Attempt to leave -> the unsaved-changes dialog appears (pop blocked).
    final state = tester.state<NavigatorState>(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();

    expect(find.text(t.details.unsavedTitle), findsOneWidget);
    // Keep editing dismisses the dialog and stays on screen.
    await tester.tap(find.text(t.details.keepEditing));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('details-editor')), findsOneWidget);
  });

  testWidgets('retry triggers the processing pipeline (POST /process)',
      (tester) async {
    await _seed(db, processingStatus: 'failed', notes: 'partial');
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Failed status surfaces the retry CTA in the Notes tab.
    final retry = find.byKey(const ValueKey('details-retry'));
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump(); // kick off async retry
    await tester.pump(const Duration(milliseconds: 50));

    // The F4 pipeline was triggered: enqueueProcessing (POST /process) fired
    // and the local row was flipped to processing for live feedback.
    expect(rec.processed, isNotEmpty);
    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.processingStatus, 'processing');
    expect(row.isProcessing, 1);

    // The Notes tab now shows the live "transcribing…" row.
    expect(find.byKey(const ValueKey('details-processing')), findsOneWidget);
  });
}
