import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Single durable folder that holds ALL of Matome's local files — the Drift
/// database, imported media, and recorded audio segments — instead of scattering
/// them across the user's Documents root.
///
/// On mobile `getApplicationDocumentsDirectory()` is already sandboxed; on
/// desktop it resolves to the real `~/Documents`, so without this subfolder the
/// app would litter the user's personal directory. Everything now lives under
/// `<documents>/Matome/`.
const String kMatomeFolderName = 'Matome';

/// True under `flutter test`, where the path_provider platform channel has no
/// handler and `getApplicationDocumentsDirectory()` HANGS (rather than throws),
/// so the one-time storage relocation must be skipped entirely.
bool get isRunningFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');

/// The dedicated Matome storage directory (`<documents>/Matome`), created if
/// missing. Native only — callers on web use cloud-direct storage.
Future<Directory> matomeStorageDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$kMatomeFolderName');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

const List<String> _dbFileNames = [
  'matome.sqlite',
  'matome.sqlite-wal',
  'matome.sqlite-shm',
];

bool _isLegacyMedia(String basename) =>
    basename.startsWith('import_') || basename.startsWith('segment_');

/// One-time: move a pre-existing `matome.sqlite` (+ WAL/SHM) from the Documents
/// root into [matomeDir] BEFORE Drift opens the database, so existing data
/// survives the relocation. Idempotent and best-effort. Must run before the
/// database file is opened.
Future<void> moveLegacyDatabaseInto(Directory matomeDir) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    if (docs.path == matomeDir.path) return;
    for (final name in _dbFileNames) {
      final src = File('${docs.path}/$name');
      final dst = File('${matomeDir.path}/$name');
      if (await src.exists() && !await dst.exists()) {
        await src.rename(dst.path);
      }
    }
  } catch (_) {
    // Best-effort: a fresh install (no legacy file) or a platform without the
    // documents dir simply skips the move.
  }
}

/// One-time: move pre-existing `import_*` / `segment_*` media from the Documents
/// root into [matomeDir]. Returns the `(oldDir, newDir)` prefixes so the caller
/// can rewrite the absolute paths stored in the database. Idempotent.
Future<({String oldDir, String newDir})?> moveLegacyMediaInto(
  Directory matomeDir,
) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    if (docs.path == matomeDir.path) return null;
    await for (final entity in docs.list(followLinks: false)) {
      if (entity is! File) continue;
      final basename = entity.path.split('/').last;
      if (!_isLegacyMedia(basename)) continue;
      final dst = '${matomeDir.path}/$basename';
      if (!await File(dst).exists()) {
        await entity.rename(dst);
      }
    }
    return (oldDir: docs.path, newDir: matomeDir.path);
  } catch (_) {
    return null;
  }
}
