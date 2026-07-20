import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';

// ---------------------------------------------------------------------------
// On-disk native open + read-back (#815). The SQLCipher `setup` hook wraps
// exactly this native open/migration/read path; proving a real on-disk file
// opens, migrates, and reads back gives the keyed-open round-trip its
// foundation. (SQLCipher itself is not active in the lab build — FDE interim.
// The key lifecycle is covered by db_encryption_test.dart.)
// ---------------------------------------------------------------------------

void main() {
  test('native on-disk DB opens, migrates, and reads back', () async {
    final dir = Directory.systemTemp.createTempSync('matome_keyed_open');
    final file = File('${dir.path}/matome.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));

    // First open: creates + migrates the file on disk.
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.workspacesDao.createWorkspace('KeyedCheck');
    await db.close();

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));

    // Reopen the same file (mirrors a subsequent boot reusing the key) and read
    // the persisted row back.
    db = AppDatabase.forTesting(NativeDatabase(file));
    final names = (await db.workspacesDao.getWorkspaces())
        .map((w) => w.name)
        .toList();
    await db.close();

    expect(names, contains('KeyedCheck'));
    expect(names, contains('Pessoal')); // seeded default survives reopen
  });
}
