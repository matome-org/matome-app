import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/connection_native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

const _gateEnabled = bool.fromEnvironment('MATOME_SQLCIPHER_RESTART_GATE');
const _sentinel = 'MATOME-SQLCIPHER-RESTART-SENTINEL-2153';
const _secondSentinel = 'MATOME-SQLCIPHER-ACCOUNT-B-2147';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_gateEnabled || !kSqlCipherEnabled || !Platform.isAndroid) {
    throw StateError('Android SQLCipher restart gate is not enabled');
  }

  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}/sqlcipher_android_restart');
  dir.createSync(recursive: true);
  final result = File('${dir.path}/restart-result.json');

  try {
    final accountA = Directory('${dir.path}/account-a')..createSync();
    final accountB = Directory('${dir.path}/account-b')..createSync();
    final accountAKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final accountBKey = Uint8List.fromList(
      List<int>.generate(32, (index) => 255 - index),
    );
    final markerFile = File('${dir.path}/install.marker');
    final writerPidFile = File('${dir.path}/writer.pid');
    if (!markerFile.existsSync()) {
      final marker = '${DateTime.now().microsecondsSinceEpoch}-$pid';
      markerFile.writeAsStringSync(marker, flush: true);
      final db = AppDatabase.forTesting(
        await openEncryptedNativeConnectionWithKey(
          databaseKey: accountAKey,
          databaseDirectory: () async => accountA.path,
        ),
      );
      await db.workspacesDao.createWorkspace(_sentinel);
      await db.close();
      final second = AppDatabase.forTesting(
        await openEncryptedNativeConnectionWithKey(
          databaseKey: accountBKey,
          databaseDirectory: () async => accountB.path,
        ),
      );
      await second.workspacesDao.createWorkspace(_secondSentinel);
      await second.close();
      writerPidFile.writeAsStringSync('$pid', flush: true);
      _writeResult(result, {
        'phase': 'write',
        'status': 'ok',
        'pid': pid,
        'marker': marker,
      });
    } else {
      final marker = markerFile.readAsStringSync();
      final writerPid = int.parse(writerPidFile.readAsStringSync());
      if (writerPid == pid) {
        throw StateError('reader process reused writer PID $pid');
      }
      final db = AppDatabase.forTesting(
        await openEncryptedNativeConnectionWithKey(
          databaseKey: accountAKey,
          databaseDirectory: () async => accountA.path,
        ),
      );
      final names = (await db.workspacesDao.getWorkspaces()).map(
        (row) => row.name,
      );
      if (!names.contains(_sentinel)) {
        throw StateError('restart sentinel was not decrypted');
      }
      if (names.contains(_secondSentinel)) {
        throw StateError('account B data leaked into account A namespace');
      }
      await db.close();

      try {
        await openEncryptedNativeConnectionWithKey(
          databaseKey: accountBKey,
          databaseDirectory: () async => accountA.path,
        );
        throw StateError('wrong account key unexpectedly opened account A');
      } on SqliteException {
        // Expected fail-closed result.
      }

      final second = AppDatabase.forTesting(
        await openEncryptedNativeConnectionWithKey(
          databaseKey: accountBKey,
          databaseDirectory: () async => accountB.path,
        ),
      );
      final secondNames = (await second.workspacesDao.getWorkspaces()).map(
        (row) => row.name,
      );
      if (!secondNames.contains(_secondSentinel)) {
        throw StateError('account B sentinel was not decrypted');
      }
      await second.close();

      for (final file in [
        File('${accountA.path}/matome.sqlite'),
        File('${accountB.path}/matome.sqlite'),
      ]) {
        final scan = latin1.decode(file.readAsBytesSync(), allowInvalid: true);
        if (scan.contains('SQLite format 3') ||
            scan.contains(_sentinel) ||
            scan.contains(_secondSentinel)) {
          throw StateError('database plaintext detected after restart');
        }
      }
      _writeResult(result, {
        'phase': 'read',
        'status': 'ok',
        'pid': pid,
        'writerPid': writerPid,
        'marker': marker,
      });
    }
  } catch (error) {
    _writeResult(result, {
      'phase': 'failed',
      'status': 'error',
      'pid': pid,
      'error': error.runtimeType.toString(),
    });
  }

  runApp(const SizedBox.shrink());
}

void _writeResult(File result, Map<String, Object> value) {
  final temporary = File('${result.path}.tmp');
  temporary.writeAsStringSync(jsonEncode(value), flush: true);
  temporary.renameSync(result.path);
}
