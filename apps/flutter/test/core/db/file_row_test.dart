import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/file_row.dart';

import '../../support/item_fixtures.dart';

void main() {
  test('canonical file payload maps to the Files view model', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await insertTestFileItem(
      db,
      id: 'document',
      title: 'Budget',
      filename: 'budget.pdf',
      mediaType: 'document',
      byteSize: 2500,
      createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
    );

    final file = (await db.itemsDao.filesForOwner('1')).single;
    expect(file.name, 'Budget');
    expect(file.kind, FileKind.document);
    expect(file.ext, 'pdf');
    expect(file.sizeLabel, '2.4 KB');
    expect(file.unfiled, isTrue);
  });

  test('formatBytes rejects poison values and formats binary units', () {
    expect(FileRow.formatBytes(null), isNull);
    expect(FileRow.formatBytes(-1), isNull);
    expect(FileRow.formatBytes(512), '512 B');
    expect(FileRow.formatBytes(1024), '1 KB');
    expect(FileRow.formatBytes(2_516_582), '2.4 MB');
  });
}
