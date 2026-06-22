import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/file_row.dart';

/// Builds a minimal [RecordingRow] for FileRow mapping tests. Only the fields the
/// mapping reads matter; the rest are filled with inert defaults.
RecordingRow _row({
  String id = 'r1',
  String title = 'A file',
  String mediaType = 'audio',
  int createdAt = 1,
  int? byteSize,
  String? originalExtension,
}) {
  return RecordingRow(
    id: id,
    title: title,
    timestamp: '00:00',
    duration: '1:23',
    badge: 'Inbox',
    isProcessing: 0,
    audioFilePath: '/tmp/$id.m4a',
    createdAt: createdAt,
    mediaType: mediaType,
    processingStatus: 'done',
    originalExtension: originalExtension,
    byteSize: byteSize,
  );
}

void main() {
  group('FileRow.formatBytes', () {
    test('null and negative are unknown (null → UI dash)', () {
      expect(FileRow.formatBytes(null), isNull);
      expect(FileRow.formatBytes(-1), isNull);
    });

    test('sub-KB renders whole bytes', () {
      expect(FileRow.formatBytes(0), '0 B');
      expect(FileRow.formatBytes(512), '512 B');
      expect(FileRow.formatBytes(1023), '1023 B');
    });

    test('KB boundary and trimming of trailing .0', () {
      expect(FileRow.formatBytes(1024), '1 KB'); // exactly 1 KB → no ".0"
      expect(FileRow.formatBytes(640 * 1024), '640 KB');
      // 1.5 KB keeps the decimal.
      expect(FileRow.formatBytes(1536), '1.5 KB');
    });

    test('MB range', () {
      expect(FileRow.formatBytes(1024 * 1024), '1 MB');
      // 2.4 MB (the canonical acceptance example).
      expect(FileRow.formatBytes((2.4 * 1024 * 1024).round()), '2.4 MB');
    });

    test('GB range', () {
      expect(FileRow.formatBytes(1024 * 1024 * 1024), '1 GB');
      expect(FileRow.formatBytes((1.3 * 1024 * 1024 * 1024).round()), '1.3 GB');
    });
  });

  group('FileRow.fromRow size mapping', () {
    test('a persisted byte size produces a human sizeLabel', () {
      final row = _row(byteSize: 2_516_582); // ~2.4 MB
      final file = FileRow.fromRow(row);
      expect(file.sizeLabel, '2.4 MB');
    });

    test('a legacy/null byte size leaves sizeLabel null (UI renders a dash)', () {
      final file = FileRow.fromRow(_row(byteSize: null));
      expect(file.sizeLabel, isNull);
    });
  });
}
