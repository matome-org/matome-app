import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/details/details_controller.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';

// ---------------------------------------------------------------------------
// E2E REGRESSION — task #1443: a notes edit NEVER wipes the machine transcript.
//
// This is the acceptance criterion for the whole P1 data-loss fix (W1). It
// drives the PRODUCTION providers end-to-end against an in-memory Drift DB + a
// fake Core (`DioAdapter`), reproducing the exact user round-trip:
//
//     import/create a recording
//   → SYNC          (Core pull populates the machine `transcript` column)
//   → EDIT NOTES    (DetailsController.save writes the user `notes`)
//   → RE-SYNC       (a second Core pull carries the transcript AGAIN)
//   → ASSERT        transcript SURVIVES unchanged AND user notes PERSIST.
//
// It exercises the full sync ↔ save ↔ sync loop (InboxController.refresh +
// DetailsController.save + recordingToCompanion merge) — not one half in
// isolation. It consolidates the unit regressions from #1434 (sync routing /
// pull-must-not-clobber-notes) and #1435 (save writes notes, never aliases the
// transcript) into one continuous proof.
//
// WHY THIS WOULD HAVE FAILED ON PRE-W1 CODE
// -----------------------------------------
// Pre-W1 there was a single shared column and the save path aliased the user's
// buffer into Core `transcript` (and the pull aliased Core `transcript` into
// the `notes` column). Two assertions below pin the two halves of that bug:
//
//   (A) After EDIT NOTES: `row.transcript == 'MACHINE TRANSCRIPT v1'`.
//       Pre-W1, save() PATCHed the user's text onto Core `transcript` and/or
//       wrote the shared column, so the machine transcript was overwritten with
//       "USER NOTES v1" — this expect would read back the user's note, not the
//       transcript, and FAIL.
//
//   (B) After RE-SYNC: `row.notes == 'USER NOTES v1'`.
//       Pre-W1, the Core list pull aliased Core `transcript` into the `notes`
//       column, so the second refresh clobbered the user's saved note back to
//       the machine transcript text — this expect would read the transcript,
//       not the note, and FAIL.
//
// Both halves are asserted on EVERY step so neither direction of the alias can
// regress silently.
// ---------------------------------------------------------------------------

/// A [RecordingResultAwaiter] that never has to resolve — the round-trip below
/// never invokes retry(), so this is only here to keep DetailsController's
/// constructor deterministic if load() were to race a terminal.
RecordingResultAwaiter _noopAwaiter() =>
    ({required recording, required poll, required ref}) async =>
        const RecordingResult.done(null);

/// The Core list-row JSON for recording id 5. Crucially the Core `/api/recordings`
/// pull is a FULL-STATE snapshot: every refresh carries the machine `transcript`
/// again (and Core `notes` is whatever Core last stored). [notes] lets a test
/// simulate Core echoing the user's pushed note on a later pull.
Map<String, dynamic> _coreRow({
  required String transcript,
  String? notes,
}) {
  return {
    'id': 5,
    'owner_id': 1,
    'title': 'Imported memo',
    'status': 'done',
    'summary': 'A memo',
    'transcript': transcript,
    'notes': notes,
    'workspace_id': null,
    'inserted_at': '2026-06-08T12:00:00Z',
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'e2e #1443: import → sync → edit notes → re-sync — the machine '
      'transcript survives and the user note persists (notes edit never '
      'wipes the transcript)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // -- Fake Core -----------------------------------------------------------
    // The list pull (`GET /api/recordings`) is mutable so the test can change
    // what the SECOND refresh returns — modelling Core having (or not having)
    // round-tripped the user's note. The save PATCH (`PATCH /api/recordings/5`)
    // is captured so we can assert the WRITE-AUTHORITY contract on the wire:
    // notes is sent, transcript is NOT.
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));

    // The body the next `GET /api/recordings` should serve. Step 1 (import/sync)
    // serves the machine transcript with NO Core note yet.
    var listBody = <String, dynamic>{
      'recordings': [
        _coreRow(transcript: 'MACHINE TRANSCRIPT v1'),
      ],
    };

    Map<String, dynamic>? patchBody;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'PATCH' && options.path == '/api/recordings/5') {
          patchBody = options.data as Map<String, dynamic>;
        }
        handler.next(options);
      },
    ));

    final adapter = DioAdapter(dio: dio);
    adapter
      ..onGet('/api/recordings', (s) => s.reply(200, listBody))
      ..onPatch(
        '/api/recordings/5',
        (s) => s.reply(200, {
          'recording': {
            'id': 5,
            'owner_id': 1,
            'title': 'Imported memo',
            'status': 'done',
            // Core echoes the saved note back; transcript stays put server-side.
            'transcript': 'MACHINE TRANSCRIPT v1',
            'notes': 'USER NOTES v1',
          },
        }),
        data: Matchers.any,
      );

    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // ------------------------------------------------------------------------
    // STEP 1 — IMPORT + SYNC: the Core pull populates the machine `transcript`
    // column. (An import is a Core recording the first list pull reconciles into
    // Drift via recordingToCompanion; this is the same path a created recording
    // takes after upload.)
    // ------------------------------------------------------------------------
    final inbox = container.read(inboxControllerProvider.notifier);
    await inbox.refresh();

    var row = await db.recordingsDao.getRecordingById('5');
    expect(row, isNotNull, reason: 'sync reconciled the Core recording');
    expect(row!.transcript, 'MACHINE TRANSCRIPT v1',
        reason: 'first sync populated the machine transcript column');
    // First-sync seeds notes from Core (which carried none) → empty/null.
    expect(row.notes ?? '', isEmpty,
        reason: 'no user note yet — Core carried none on the import pull');

    // ------------------------------------------------------------------------
    // STEP 2 — EDIT NOTES: the user types a note and saves. save() writes the
    // user-owned `notes` column (Drift) and PATCHes Core `notes` — it must
    // NEVER touch the machine `transcript`.
    // ------------------------------------------------------------------------
    final detailsProvider = Provider<DetailsController>(
      (ref) => DetailsController(ref, '5', awaitResult: _noopAwaiter()),
    );
    final details = container.read(detailsProvider);
    // Let load() settle so the controller holds the synced row (and its coreId).
    for (var i = 0; i < 40 && details.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(details.state.row?.transcript, 'MACHINE TRANSCRIPT v1',
        reason: 'details loaded the synced row with its transcript');

    await details.save('USER NOTES v1');

    // (A) The machine transcript is UNTOUCHED by the notes save. Pre-W1 the save
    //     aliased the buffer into the transcript and this would read back
    //     'USER NOTES v1' → FAIL.
    row = await db.recordingsDao.getRecordingById('5');
    expect(row!.transcript, 'MACHINE TRANSCRIPT v1',
        reason: 'save(notes) must leave the machine transcript intact');
    expect(row.notes, 'USER NOTES v1', reason: 'the user note was persisted');

    // WRITE-AUTHORITY on the wire: the Core PATCH carries `notes`, never
    // `transcript` (the historic data-loss PATCH).
    expect(patchBody, isNotNull, reason: 'a Core PATCH was issued by save()');
    expect(patchBody!['notes'], 'USER NOTES v1');
    expect(patchBody!.containsKey('transcript'), isFalse,
        reason: 'save() must not PATCH Core transcript');

    // ------------------------------------------------------------------------
    // STEP 3 — RE-SYNC: a SECOND Core list pull arrives carrying the machine
    // transcript AGAIN (full-state snapshot). Model the realistic race where
    // Core has NOT yet round-tripped the user's note (notes: null on the pull),
    // which is the harshest case for the pull-must-not-clobber-notes contract.
    // ------------------------------------------------------------------------
    listBody = <String, dynamic>{
      'recordings': [
        _coreRow(transcript: 'MACHINE TRANSCRIPT v1', notes: null),
      ],
    };
    adapter.onGet('/api/recordings', (s) => s.reply(200, listBody));

    await inbox.refresh();

    row = await db.recordingsDao.getRecordingById('5');

    // FINAL ASSERTIONS — both halves survive the full round-trip:
    //   transcript intact (Core re-asserted it; the merge adopts it unchanged)
    //   notes intact (the pull did NOT clobber the locally-edited note).
    expect(row!.transcript, 'MACHINE TRANSCRIPT v1',
        reason: 'transcript survives the re-sync unchanged');
    // (B) Pre-W1 the pull aliased Core transcript into the notes column, so this
    //     would read 'MACHINE TRANSCRIPT v1' → FAIL.
    expect(row.notes, 'USER NOTES v1',
        reason: 're-sync must NOT clobber the locally-edited user note');

    // ------------------------------------------------------------------------
    // STEP 4 — RE-SYNC where Core HAS round-tripped the note (notes echoed):
    // even when the pull carries the user's note, both columns stay correctly
    // routed (transcript→transcript, notes→notes), never crossed.
    // ------------------------------------------------------------------------
    listBody = <String, dynamic>{
      'recordings': [
        _coreRow(transcript: 'MACHINE TRANSCRIPT v2', notes: 'USER NOTES v1'),
      ],
    };
    adapter.onGet('/api/recordings', (s) => s.reply(200, listBody));

    await inbox.refresh();

    row = await db.recordingsDao.getRecordingById('5');
    // Core re-processed the audio → an UPDATED transcript is adopted (Core owns
    // it), and the note is still the user's, never crossed into the transcript.
    expect(row!.transcript, 'MACHINE TRANSCRIPT v2',
        reason: 'Core owns the transcript; an updated machine transcript wins');
    expect(row.notes, 'USER NOTES v1',
        reason: 'the user note remains the user note across the whole loop');
  });
}
