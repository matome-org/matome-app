import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Fake path_provider that points the app "documents" dir at a real temp dir,
/// so the REAL [durableImportCopy] (matomeStorageDir → getApplicationDocuments
/// Directory) runs against disk instead of hanging on the absent plugin channel.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// Fake file picker so the REAL Add-photo button can be tapped without a native
/// dialog: [pickFiles] returns a single file at [_path] (or null to simulate a
/// cancel).
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakeFilePicker(this._path);
  final String? _path;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (_path == null) return null;
    return FilePickerResult([
      PlatformFile(
        name: _path.split('/').last,
        path: _path,
        size: File(_path).lengthSync(),
      ),
    ]);
  }
}

/// End-to-end proof of the photo import path WITHOUT the GUI: the picker result
/// is fed straight into the controller, which runs the production durable copy
/// + local-first insert. Guards the "added a photo but nothing persisted"
/// report by exercising the actual file copy and the stored absolute path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory docsRoot;

  setUp(() {
    docsRoot = Directory.systemTemp.createTempSync('matome_e2e_docs_');
    PathProviderPlatform.instance = _FakePathProvider(docsRoot.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    if (docsRoot.existsSync()) docsRoot.deleteSync(recursive: true);
  });

  test('addPhoto copies the picked file into <documents>/Matome and inserts an '
      'image Item pointing at the durable copy', () async {
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_e2e'),
        title: const Value('Standup'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(matomeDetailControllerProvider('m_e2e'), (_, _) {});
    addTearDown(sub.close);
    final controller = c.read(matomeDetailControllerProvider('m_e2e').notifier);
    await controller.load();

    // A real source PNG OUTSIDE the documents dir — the durable copy must pull
    // it into <documents>/Matome and store THAT path.
    final source = File(
      '${Directory.systemTemp.path}/e2e_src_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);
    addTearDown(() {
      if (source.existsSync()) source.deleteSync();
    });

    await controller.addPhoto(file: source, name: 'whiteboard.png');

    // 1. An image Item row exists under THIS matome.
    final matome = await db.matomesDao.getMatomeWithRecordings('m_e2e');
    expect(matome!.recordings, hasLength(1));
    final item = matome.recordings.single;
    expect(item.mediaType, 'image');
    expect(item.title, 'whiteboard');

    // 2. The stored path is a REAL durable copy inside <documents>/Matome — not
    //    the original source path — and the file actually exists on disk.
    final row = await db.recordingsDao.getRecordingById(item.id);
    final storedPath = row!.audioFilePath;
    expect(storedPath, isNotNull);
    expect(storedPath, startsWith('${docsRoot.path}/Matome/'));
    expect(storedPath, isNot(source.path));
    expect(
      File(storedPath!).existsSync(),
      isTrue,
      reason: 'the durable copy must exist on disk',
    );

    // 3. The hub state reflects the new photo (what the screen renders).
    expect(controller.state.matome?.recordings, hasLength(1));
  });

  testWidgets('the detail screen shows the image tile after addPhoto without a '
      'manual reload (live add → render)', (tester) async {
    // Seed a matome with one audio Item so the screen starts with NO image.
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_live'),
        title: const Value('Standup'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_audio'),
        matomeId: const Value('m_live'),
        title: const Value('Audio note'),
        timestamp: const Value('9:00 AM'),
        duration: const Value('0:30'),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('audio'),
        processingStatus: const Value('done'),
      ),
    );

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_live'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No image tile before the import.
    expect(find.byType(Image), findsNothing);

    // Drive the SAME call the Add-photo button makes after the picker returns,
    // against a real source file + the production durable copy.
    // A REAL 1x1 PNG so Image.file decodes and pumpAndSettle settles (invalid
    // bytes route through errorBuilder but can leave the frame pump spinning).
    final source = File(
      '${Directory.systemTemp.path}/e2e_live_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          '+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
      );
    addTearDown(() {
      if (source.existsSync()) source.deleteSync();
    });
    // addPhoto does REAL file I/O (durable copy) — that only progresses inside
    // runAsync; under the default fake-async zone the copy future never
    // completes and the test would hang.
    await tester.runAsync(() async {
      await c
          .read(matomeDetailControllerProvider('m_live').notifier)
          .addPhoto(file: source, name: 'whiteboard.png');
    });

    // The screen reacts (ref.watch). A couple of bounded frames are enough for
    // the rebuild to mount the new tile — pumpAndSettle would block on the
    // Image.file decode stream, so avoid it here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final imageItem =
        (await db.matomesDao.getMatomeWithRecordings('m_live'))!
            .recordings
            .firstWhere((r) => r.mediaType == 'image');
    expect(
      find.byKey(ValueKey('matome-image-${imageItem.id}')),
      findsOneWidget,
      reason: 'the new photo tile must render without reopening the screen',
    );
    expect(
      find.byKey(ValueKey('matome-image-remove-${imageItem.id}')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('TAPPING the Add photo button imports the picked image and renders '
      'its tile — full GUI flow through _addPhoto + a fake picker', (
    tester,
  ) async {
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_btn'),
        title: const Value('Standup'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_btn_audio'),
        matomeId: const Value('m_btn'),
        title: const Value('Audio note'),
        timestamp: const Value('9:00 AM'),
        duration: const Value('0:30'),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('audio'),
        processingStatus: const Value('done'),
      ),
    );

    final source = File(
      '${Directory.systemTemp.path}/e2e_btn_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          '+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
      );
    addTearDown(() {
      if (source.existsSync()) source.deleteSync();
    });
    // The REAL button calls FilePicker.platform.pickFiles — swap in a fake that
    // returns our source file, so no native dialog is needed.
    FilePicker.platform = _FakeFilePicker(source.path);
    addTearDown(() => FilePicker.platform = _FakeFilePicker(null));

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_btn'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);

    // Tap the actual Add-photo button — drives _addPhoto end to end (real
    // durable copy needs runAsync for the file I/O).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('matome-add-photo')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final imageItem =
        (await db.matomesDao.getMatomeWithRecordings('m_btn'))!
            .recordings
            .firstWhere((r) => r.mediaType == 'image');
    expect(
      find.byKey(ValueKey('matome-image-${imageItem.id}')),
      findsOneWidget,
      reason: 'tapping Add photo must import the image and render its tile',
    );
  });
}
