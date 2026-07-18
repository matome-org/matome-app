import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/documents/document_open_policy.dart';

void main() {
  group('DocumentOpenPolicy', () {
    test('sanitizes the source name and derives persisted metadata', () {
      final metadata = DocumentMetadata.fromImport(
        filename: '../private/Q3\r\nreport.PDF',
        mimeType: 'application/pdf',
        probeBytes: ascii.encode('%PDF-1.7'),
      );

      expect(metadata.filename, 'Q3__report.PDF');
      expect(metadata.extension, 'pdf');
      expect(metadata.mimeType, 'application/pdf');
      expect(metadata.openPolicy, DocumentOpenPolicy.external);
    });

    test('classifies Office, active content, mismatch, and unknown types', () {
      expect(
        DocumentMetadata.fromImport(
          filename: 'budget.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          probeBytes: const [0x50, 0x4b, 0x03, 0x04],
        ).openPolicy,
        DocumentOpenPolicy.systemApp,
      );
      expect(
        DocumentMetadata.fromImport(
          filename: 'page.html',
          mimeType: 'text/html',
        ).openPolicy,
        DocumentOpenPolicy.attachmentOnly,
      );
      expect(
        DocumentMetadata.fromImport(
          filename: 'report.pdf',
          mimeType: 'text/plain',
        ).openPolicy,
        DocumentOpenPolicy.downloadOnly,
      );
      final injectedMime = DocumentMetadata.fromImport(
        filename: 'report.pdf',
        mimeType: 'application/pdf\r\nx-injected: yes',
      );
      expect(injectedMime.mimeType, 'application/octet-stream');
      expect(injectedMime.openPolicy, DocumentOpenPolicy.downloadOnly);
      expect(
        DocumentMetadata.fromImport(
          filename: 'archive.xyz',
          mimeType: 'application/octet-stream',
        ).openPolicy,
        DocumentOpenPolicy.downloadOnly,
      );
    });

    test('bounded probe recognizes the explicit safe format allow-list', () {
      expect(
        probeDocumentOpenPolicy('doc', 'application/msword', const [
          0xd0,
          0xcf,
          0x11,
          0xe0,
          0xa1,
          0xb1,
          0x1a,
          0xe1,
        ]),
        DocumentOpenPolicy.systemApp,
      );
      expect(
        probeDocumentOpenPolicy(
          'rtf',
          'application/rtf',
          ascii.encode(r'{\rtf1 hello}'),
        ),
        DocumentOpenPolicy.systemApp,
      );
      expect(
        probeDocumentOpenPolicy(
          'odt',
          'application/vnd.oasis.opendocument.text',
          const [0x50, 0x4b, 0x03, 0x04],
        ),
        DocumentOpenPolicy.systemApp,
      );
      expect(
        probeDocumentOpenPolicy(
          'txt',
          'text/plain',
          utf8.encode('Meeting notes\nこんにちは'),
        ),
        DocumentOpenPolicy.external,
      );
    });

    test('signature mismatch, binary text, and active markup downgrade', () {
      for (final bytes in <List<int>>[
        ascii.encode('not a PDF'),
        const [0x25, 0x50, 0x44],
      ]) {
        expect(
          probeDocumentOpenPolicy('pdf', 'application/pdf', bytes),
          DocumentOpenPolicy.downloadOnly,
        );
      }
      expect(
        probeDocumentOpenPolicy('txt', 'text/plain', const [0x61, 0, 0x62]),
        DocumentOpenPolicy.downloadOnly,
      );
      expect(
        probeDocumentOpenPolicy(
          'txt',
          'text/plain',
          ascii.encode('<html>active</html>'),
        ),
        DocumentOpenPolicy.downloadOnly,
      );
    });

    test('rejects executable or script extension and MIME', () {
      expect(
        () => DocumentMetadata.fromImport(
          filename: 'install.sh',
          mimeType: 'text/plain',
        ),
        throwsA(isA<UnsafeDocumentTypeException>()),
      );
      expect(
        () => DocumentMetadata.fromImport(
          filename: 'notes.txt',
          mimeType: 'application/x-sh',
        ),
        throwsA(isA<UnsafeDocumentTypeException>()),
      );
    });
  });
}
