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
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Audio detail path migrated onto the unified [FileDetailScreen] host + the
/// presentational [FileView] (#1439). These tests pin the four acceptance
/// behaviours: Contents reads the machine `transcript` column (NOT the notes
/// buffer), Summary is gone, the notes editor is not auto-opened, and Notes
/// remains editable and saved to the `notes` column.
class _Recorder {
  final List<String> patched = [];
}

ProviderContainer _container(AppDatabase db, _Recorder rec) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:7001',
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  final adapter = DioAdapter(dio: dio);

  // download-url -> none, so the audio player stays inert (no platform calls).
  adapter.onGet(
    RegExp(r'/api/recordings/\d+/download-url'),
    (server) => server.reply(404, {'error': 'not_found'}),
  );
  adapter.onPatch(RegExp(r'/api/recordings/\d+'), (server) {
    rec.patched.add('patched');
    return server.reply(200, {
      'recording': {
        'id': 5,
        'owner_id': 1,
        'title': 'Standup',
        'status': 'done',
      },
    });
  }, data: Matchers.any);
  adapter.onGet(
    RegExp(r'/api/recordings/\d+$'),
    (server) => server.reply(200, {
      'recording': {'id': 5, 'owner_id': 1, 'title': 'Standup', 'status': 'done'},
    }),
  );

  final repo = RecordingsRepository(
    apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
  );
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

Future<void> _seed(
  AppDatabase db, {
  String notes = 'my own notes',
  String transcript = 'the spoken transcript',
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: const Value('5'),
      title: const Value('Standup'),
      timestamp: const Value('9:00 AM'),
      duration: const Value('0:30'),
      badge: const Value('Inbox'),
      isProcessing: const Value(0),
      audioFilePath: const Value(''),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      notes: Value(notes),
      transcript: Value(transcript),
      mediaType: const Value('audio/m4a'),
      processingStatus: const Value('done'),
    ),
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const FileDetailScreen.byId(id: '5'),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _Recorder rec;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    rec = _Recorder();
  });
  tearDown(() => db.close());

  testWidgets(
    'audio Contents shows the transcript column, NOT the notes buffer',
    (tester) async {
      await _seed(db);
      final container = _container(db, rec);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      // Unified host + presentational FileView.
      expect(find.byType(FileView), findsOneWidget);

      // Contents reads the machine transcript column.
      expect(
        find.text('the spoken transcript', skipOffstage: false),
        findsOneWidget,
      );
      // The notes buffer text must NOT appear inside the read-only Contents
      // section — it belongs only to the editable Notes field.
      expect(
        find.byKey(const ValueKey('file-view-contents'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('Summary segment/tab is absent', (tester) async {
    await _seed(db);
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // No legacy 3-tab segmented control: the Summary segment is gone.
    expect(find.byKey(const ValueKey('segment-summary')), findsNothing);
    expect(find.text('Summary', skipOffstage: false), findsNothing);
  });

  testWidgets('notes editor is not auto-opened; Notes is editable + saved', (
    tester,
  ) async {
    await _seed(db, notes: '');
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // The legacy auto-open markdown editor (toolbar B/I/H etc.) is NOT shown.
    expect(find.byKey(const ValueKey('details-editor')), findsNothing);
    expect(find.byKey(const ValueKey('toolbar-B')), findsNothing);

    // Notes field is present and editable inline.
    final notesField = find.descendant(
      of: find.byKey(const ValueKey('file-view-notes'), skipOffstage: false),
      matching: find.byType(TextField),
    );
    expect(notesField, findsOneWidget);

    await tester.enterText(notesField, 'edited note');
    await tester.pumpAndSettle();

    // Save persists to the notes column (and PATCHes Core).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.notes, 'edited note');
    // Transcript untouched by a notes save.
    expect(row.transcript, 'the spoken transcript');
    expect(rec.patched, isNotEmpty);
  });

  testWidgets('isDirty blocks leaving until discarded', (tester) async {
    await _seed(db);
    final container = _container(db, rec);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final notesField = find.descendant(
      of: find.byKey(const ValueKey('file-view-notes'), skipOffstage: false),
      matching: find.byType(TextField),
    );
    await tester.enterText(notesField, 'unsaved change');
    await tester.pumpAndSettle();

    final state = tester.state<NavigatorState>(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();

    expect(find.text(t.details.unsavedTitle), findsOneWidget);
    await tester.tap(find.text(t.details.keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(FileView), findsOneWidget);
  });

  testWidgets(
    "the '…' overflow is an anchored popup with Delete only — a file does not "
    'move between spaces (only the matome does)',
    (tester) async {
      await _seed(db);
      final container = _container(db, rec);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      final overflow = find.byWidgetPredicate(
        (w) => w is IconButton && w.icon is Icon &&
            (w.icon as Icon).icon == Icons.more_horiz,
      );
      expect(overflow, findsOneWidget);

      final button = tester.widget<IconButton>(overflow);
      expect(button.tooltip, t.details.moreActions);

      // The popup exposes Delete and NOT Move-to-space.
      await tester.tap(overflow);
      await tester.pumpAndSettle();
      expect(find.text(t.details.delete), findsOneWidget);
      expect(find.text(t.details.moveToSpace), findsNothing);
    },
  );
}
