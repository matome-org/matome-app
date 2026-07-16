import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart'
    show PickedUpload;
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import 'support/e2e_harness.dart';

// ---------------------------------------------------------------------------
// E2E — task #1454: the FIRST-SHIP document-upload loop, end-to-end, on Linux
// desktop. This is the acceptance proof for plan #98's document upload: pick a
// document → STORE it (durable copy + local-first row under a matome) → UPLOAD
// it (real presigned PUT to a loopback storage stand-in + a stub callback that
// resolves the job `done` with a summary) → DRILL into the doc Item and assert
// it renders as a DOCUMENT (doc card + file-type chip) with the stub summary in
// Contents and an EDITABLE Notes field.
//
// What is REAL (under test) vs FAKED:
//   * REAL: `MatomeDetailController.addFile` (the production pick→store path —
//     durable copy + `upsertRecordingWithMatome` local-first insert), the
//     `UploadQueue.drainRow` pipeline, `RecordingsRepository.uploadFile` /
//     `_uploadStream` PUTting to a real loopback server, the go_router doc route
//     (`/items/document/:id`), the `_RowOnlyDetailById` host, and the whole
//     `FileView` render (FileTypeChip media header + Contents state machine +
//     Notes field).
//   * FAKED: only Core's own create/enqueue/fetch API (a fake repo) — those are
//     not what this loop proves, and a live Core/ai-stub is unavailable in a
//     headless integration run. The fake's terminal `done` mirrors the REAL
//     ai-stub `successPayload` for a document: it carries the stub summary in
//     the machine-owned `transcript` field, exactly the field Core fills from
//     the stub callback and that `applyUploadResult` routes into the Drift
//     `transcript` column the doc Contents reads.
//
// WHY THIS WOULD HAVE FAILED ON THE PRE-#1454 UI
// ----------------------------------------------
// The doc detail host hardcoded `contentsState: empty` / `contentsText: null`
// for ALL non-audio kinds, so a drained document showed "No contents yet" even
// after the upload completed — the stub summary NEVER rendered, and the live
// doc Contents states (processing / failed / ready) were dead. The Contents
// assertion below pins the fix: the stub summary renders in the ready body.
// ---------------------------------------------------------------------------

/// The clearly-a-placeholder document summary the REAL ai-stub returns for a
/// `media_type: document` job (see services/ai-stub/src/server.js `summaryFor`).
/// Pinned here so the e2e proves the EXACT stub text reaches the doc Contents.
const _stubDocSummary =
    '[PLACEHOLDER] AI stub summary for document recording 9001. '
    'No document content was processed.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A real loopback server standing in for the presigned-PUT storage target.
  // The REAL repo `_uploadStream` streams the document bytes here unchanged.
  late HttpServer putServer;
  late List<int> capturedBody;
  String? capturedMethod;
  late Completer<void> putReceived;

  // A durable-storage temp dir for the import copy (the production durableCopy
  // writes into app docs; here it is redirected to this temp dir).
  late Directory tmp;

  setUp(() async {
    capturedBody = <int>[];
    capturedMethod = null;
    putReceived = Completer<void>();
    putServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    putServer.listen((HttpRequest req) async {
      capturedMethod = req.method;
      capturedBody = await req.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      req.response.statusCode = 200;
      await req.response.close();
      if (!putReceived.isCompleted) putReceived.complete();
    });
    tmp = await Directory.systemTemp.createTemp('e2e_doc_upload_');
  });
  tearDown(() async {
    await putServer.close(force: true);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  String presignUrl() =>
      'http://${putServer.address.host}:${putServer.port}/upload';

  testWidgets('DESKTOP e2e #1454: pick a document → store → upload (real PUT + stub '
      'done) → it appears as a DOCUMENT Item (doc card + file chip) with the '
      'stub summary in Contents and an editable Notes field', (tester) async {
    // Desktop / wide viewport — the two-pane home the shipping desktop uses.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A matome to attach the imported document Item to (the production import
    // path, addFile, files into the open matome).
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m1'),
        title: const Value('Doc upload matome'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );

    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');

    // ── REAL pipeline wiring ────────────────────────────────────────────────
    // Fake-Core repo whose uploadFile is the REAL implementation (PUTs to the
    // loopback server); only create/enqueue/fetch are faked. The terminal
    // `done` carries the stub document summary in `transcript` — the exact
    // field the ai-stub→Core callback fills and applyUploadResult routes to the
    // Drift `transcript` column the doc Contents renders.
    final repo = _StubCoreDocRepo(
      apiClient: ApiClient(
        tokenStore: store,
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
      presignUrl: presignUrl(),
      doneTranscript: _stubDocSummary,
    );

    // A durableCopy redirected into the test temp dir (production writes into
    // app docs). Keeps the REAL store semantics — copy bytes, opaque rename
    // that preserves the extension — without touching path_provider.
    Future<PickedUpload> testDurableCopy(PickedUpload picked) async {
      final basename = picked.file.path.split('/').last;
      final ext = basename.contains('.') ? basename.split('.').last : 'bin';
      final dest = File(
        '${tmp.path}/import_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      final durable = await picked.file.copy(dest.path);
      return PickedUpload(
        file: durable,
        title: picked.title,
        mediaType: picked.mediaType,
      );
    }

    await tester.pumpWidget(
      buildE2EApp(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          authRepositoryProvider.overrideWithValue(
            FakeE2EAuthRepository(store),
          ),
          recordingsRepositoryProvider.overrideWithValue(repo),
          uploadQueueProvider.overrideWith(UploadQueue.new),
          // The matome import controller copies through the test durableCopy.
          matomeDetailControllerProvider.overrideWith(
            (ref, id) =>
                MatomeDetailController(ref, id, durableCopy: testDurableCopy),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The app's own provider container — used to drive the PRODUCTION store +
    // upload code (not stubs of it).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // ── STEP 1 — PICK + STORE (production addFile) ─────────────────────────
    // A real on-disk source document (the "picked file"). addFile durable-copies
    // it, derives mediaType=document from the extension, persists the original
    // extension, and local-first inserts a `pending_upload` row under m1.
    final source = File('${tmp.path}/Report.pdf');
    final docBytes = utf8.encode('PDF body bytes for the e2e document');
    await source.writeAsBytes(docBytes);

    final matomeCtl = container.read(
      matomeDetailControllerProvider('m1').notifier,
    );
    await matomeCtl.addFile(file: source, name: 'Report.pdf');

    // The local-first row exists, is a document, pending_upload, ext preserved.
    var rows = await db.itemsDao.listForMatome('m1', '1');
    expect(
      rows,
      hasLength(1),
      reason: 'the imported document row was inserted',
    );
    final localId = rows.first.id;
    expect(
      rows.first.mediaType,
      'document',
      reason: 'extension-derived media type is document (not audio/image)',
    );
    expect(
      rows.first.originalExtension,
      'pdf',
      reason: 'original extension persisted through the durable rename',
    );
    expect(
      rows.first.processingStatus,
      'pending_upload',
      reason: 'stored local-first BEFORE any Core call',
    );

    // ── STEP 2 — UPLOAD (real queue drain: create → real PUT → enqueue → done)
    await container.read(uploadQueueProvider).drainRow(localId);
    await putReceived.future.timeout(const Duration(seconds: 5));

    // The real presigned PUT carried the EXACT document bytes to storage.
    expect(capturedMethod, 'PUT', reason: 'presigned PUT issued');
    expect(
      capturedBody,
      docBytes,
      reason: 'the document bytes were streamed through the real transport',
    );

    // The row reconciled to done; the stub summary landed in the machine
    // transcript column (the field the doc Contents reads).
    final doneRow = await db.itemsDao.getById(localId, '1');
    expect(
      doneRow!.processingStatus,
      'done',
      reason: 'the document upload pipeline reached terminal done',
    );
    expect(doneRow.coreId, repo.coreIdMinted, reason: 'coreId reconciled');
    expect(
      doneRow.transcript,
      _stubDocSummary,
      reason: 'the stub document summary was stored as the machine contents',
    );

    // ── STEP 3 — DRILL IN + RENDER assertions ──────────────────────────────
    // Open the matome hub, then tap the document card to drill into the doc
    // host through the REAL go_router `/items/document/:id` route.
    container.read(routerProvider).go('/matome/m1');
    await tester.pumpAndSettle();

    // The child Items list lives behind the matome's "show more" reveal in the
    // narrow/routed presentation — expand it so the document card is mounted.
    final showMore = find.byKey(const ValueKey('matome-show-more'));
    if (showMore.evaluate().isNotEmpty) {
      await tester.tap(showMore.first);
      await tester.pumpAndSettle();
    }

    // The document Item shows as a doc CARD (the shared recording card, not the
    // image media tile) — identified by the production Semantics label the
    // recording card carries. Find it, scroll it into view, and tap it.
    // The document Item shows as a doc CARD (the shared recording card, not the
    // image media tile). The card title text lives inside the card's tappable
    // InkWell; find that InkWell (the recording card wraps its title in one) and
    // tap it to drill into the doc host via `/items/document/:id`.
    final docCardInk = find.ancestor(
      of: find.text('Report'),
      matching: find.byType(InkWell),
    );
    expect(
      docCardInk,
      findsWidgets,
      reason: 'the document Item card is listed',
    );
    await tester.ensureVisible(docCardInk.first);
    await tester.pumpAndSettle();
    await tester.tap(docCardInk.first);
    await tester.pumpAndSettle();

    // (a) It rendered through the unified FileView doc host.
    expect(
      find.byKey(const ValueKey('file-detail-view')),
      findsOneWidget,
      reason: 'the document drilled into the unified file-detail view',
    );

    // (b) The DOCUMENT media header is the FileTypeChip (type icon + name +
    //     size + disabled "Open" — the doc card/file chip), NOT an image frame
    //     and NOT an audio player bar.
    expect(
      find.byKey(const ValueKey('file-type-chip')),
      findsOneWidget,
      reason: 'the doc media header is the file-type chip',
    );
    expect(
      find.byKey(const ValueKey('file-type-chip-open')),
      findsOneWidget,
      reason: 'the file chip renders its (disabled) Open affordance',
    );
    expect(
      find.byKey(const ValueKey('file-detail-image-header')),
      findsNothing,
      reason: 'a document must NOT render the image media header',
    );

    // (c) The stub summary renders in the Contents READY body — the live state,
    //     not the old hardcoded "No contents yet" empty body.
    final readyContents = find.byKey(
      const ValueKey('file-view-contents-ready'),
    );
    expect(
      readyContents,
      findsOneWidget,
      reason: 'doc Contents is in the READY state (machine summary present)',
    );
    expect(
      find.byKey(const ValueKey('file-view-contents-empty')),
      findsNothing,
      reason: 'the empty placeholder must NOT show once the summary arrived',
    );
    expect(
      find.text(_stubDocSummary),
      findsOneWidget,
      reason: 'the exact ai-stub document summary is shown in Contents',
    );

    // (d) The Notes field is present and EDITABLE — typing updates it.
    final notes = find.descendant(
      of: find.byKey(const ValueKey('file-view-notes')),
      matching: find.byType(EditableText),
    );
    expect(notes, findsOneWidget, reason: 'the Notes field is present');
    await tester.enterText(notes, 'my doc note');
    await tester.pump();
    expect(
      find.text('my doc note'),
      findsOneWidget,
      reason: 'the Notes field accepted user input (editable)',
    );
  });
}

/// Legacy injection seam retained by this integration harness. Device work
/// releases at Core acceptance and does not invoke it.
/// A repository whose Core API legs (create / enqueue / fetch) are faked but
/// whose `uploadFile` runs the REAL implementation (via `super`) so the genuine
/// `_uploadStream` PUTs the document bytes to the loopback presign URL. The
/// terminal `done` mirrors the ai-stub document `successPayload`: the stub
/// summary rides in `transcript` (the machine-owned field).
class _StubCoreDocRepo extends RecordingsRepository {
  _StubCoreDocRepo({
    required super.apiClient,
    required this.presignUrl,
    required this.doneTranscript,
  });

  final String presignUrl;
  final String doneTranscript;
  final int coreIdMinted = 9001;

  Recording _recording({required String status, String? transcript}) {
    return Recording.fromJson(<String, dynamic>{
      'id': coreIdMinted,
      'owner_id': 1,
      'title': 'Report',
      'status': status,
      'transcript': ?transcript,
    });
  }

  @override
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
    String? checksumSha256,
  }) async {
    return RecordingCreateResult(
      recording: _recording(status: 'pending'),
      upload: UploadDescriptor(
        method: 'PUT',
        url: presignUrl,
        storageKey: 'owners/1/recordings/$coreIdMinted/media',
        expiresIn: 900,
      ),
    );
  }

  // uploadFile is intentionally NOT overridden — the REAL transport runs.

  @override
  Future<Recording> enqueueProcessing(int id) async =>
      _recording(status: 'processing');

  @override
  Future<Recording?> fetchRecording(int id) async =>
      _recording(status: 'done', transcript: doneTranscript);
}
