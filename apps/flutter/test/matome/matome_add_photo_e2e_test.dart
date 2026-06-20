import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';

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
}
