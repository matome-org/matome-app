import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/documents/document_open_policy.dart';
import 'package:matome_flutter/features/documents/document_open_service.dart';

void main() {
  group('DocumentOpenService', () {
    test(
      'desktop opens an approved existing local file without a descriptor',
      () async {
        final source = _DescriptorSource();
        final launcher = _Launcher();
        final service = DocumentOpenService(
          descriptorSource: source.load,
          launcher: launcher,
          environment: DocumentOpenEnvironment.desktop,
          localFileExists: (_) async => true,
          localContentProbe: (_, _) async => _pdfBytes,
        );

        final result = await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            localPath: '/tmp/report.pdf',
            openPolicy: DocumentOpenPolicy.external,
            extension: 'pdf',
            mimeType: 'application/pdf',
          ),
        );

        expect(result, DocumentOpenResult.openedLocal);
        expect(source.calls, 0);
        expect(launcher.launched.single, Uri.file('/tmp/report.pdf'));
      },
    );

    test(
      'desktop falls back to a fresh remote descriptor after local failure',
      () async {
        final source = _DescriptorSource();
        final launcher = _Launcher(results: [false, true]);
        final service = DocumentOpenService(
          descriptorSource: source.load,
          launcher: launcher,
          environment: DocumentOpenEnvironment.desktop,
          localFileExists: (_) async => true,
          localContentProbe: (_, _) async => _pdfBytes,
        );

        final result = await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            localPath: '/tmp/report.pdf',
            openPolicy: DocumentOpenPolicy.external,
            extension: 'pdf',
            mimeType: 'application/pdf',
          ),
        );

        expect(result, DocumentOpenResult.openedRemote);
        expect(source.calls, 1);
        expect(launcher.launched.last, Uri.parse(_DescriptorSource.url));
      },
    );

    test(
      'mobile ignores local paths and requires a fresh HTTPS descriptor',
      () async {
        final source = _DescriptorSource();
        final launcher = _Launcher();
        final service = DocumentOpenService(
          descriptorSource: source.load,
          launcher: launcher,
          environment: DocumentOpenEnvironment.mobile,
          localFileExists: (_) async => true,
        );

        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            localPath: '/tmp/report.pdf',
            openPolicy: DocumentOpenPolicy.external,
          ),
        );
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            localPath: '/tmp/report.pdf',
            openPolicy: DocumentOpenPolicy.external,
          ),
        );

        expect(source.calls, 2);
        expect(
          launcher.launched,
          everyElement(Uri.parse(_DescriptorSource.url)),
        );
      },
    );

    test('web reserves its popup synchronously before awaiting Core', () async {
      final pending = Completer<DocumentOpenDescriptor>();
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: (_) => pending.future,
        launcher: launcher,
        environment: DocumentOpenEnvironment.web,
      );

      final opening = service.open(
        const DocumentOpenRequest(
          coreId: 7,
          openPolicy: DocumentOpenPolicy.external,
        ),
      );
      expect(launcher.reservations, 1);
      expect(launcher.launched, isEmpty);

      pending.complete(_DescriptorSource.descriptor);
      expect(await opening, DocumentOpenResult.openedRemote);
    });

    test('blocked files never reserve, fetch, or launch', () async {
      final source = _DescriptorSource();
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: source.load,
        launcher: launcher,
        environment: DocumentOpenEnvironment.mobile,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.blocked,
          ),
        ),
        DocumentOpenResult.blocked,
      );
      expect(source.calls, 0);
      expect(launcher.reservations, 0);
    });

    test('rejects non-HTTPS remote descriptors without launching', () async {
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: (_) async => _DescriptorSource.descriptor.copyWith(
          url: Uri.parse('http://storage.example/report.pdf'),
        ),
        launcher: launcher,
        environment: DocumentOpenEnvironment.mobile,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.external,
          ),
        ),
        DocumentOpenResult.unavailable,
      );
      expect(launcher.launched, isEmpty);
      expect(launcher.closed, 1);
    });

    test('reserve failures are contained by the service', () async {
      final service = DocumentOpenService(
        descriptorSource: _DescriptorSource().load,
        launcher: _ThrowingLauncher(),
        environment: DocumentOpenEnvironment.web,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.external,
          ),
        ),
        DocumentOpenResult.failed,
      );
    });

    test(
      'desktop local exceptions fall back to the remote descriptor',
      () async {
        final source = _DescriptorSource();
        final launcher = _Launcher();
        final service = DocumentOpenService(
          descriptorSource: source.load,
          launcher: launcher,
          environment: DocumentOpenEnvironment.desktop,
          localFileExists: (_) => throw FileSystemException('stale'),
        );

        expect(
          await service.open(
            const DocumentOpenRequest(
              coreId: 7,
              localPath: '/tmp/report.pdf',
              openPolicy: DocumentOpenPolicy.external,
              extension: 'pdf',
              mimeType: 'application/pdf',
            ),
          ),
          DocumentOpenResult.openedRemote,
        );
        expect(source.calls, 1);
      },
    );

    test('rejects non-GET and more-permissive descriptors', () async {
      final launcher = _Launcher();
      final nonGet = DocumentOpenService(
        descriptorSource: (_) async =>
            _DescriptorSource.descriptor.copyWith(method: 'POST'),
        launcher: launcher,
        environment: DocumentOpenEnvironment.mobile,
      );
      final permissive = DocumentOpenService(
        descriptorSource: (_) async => _DescriptorSource.descriptor,
        launcher: launcher,
        environment: DocumentOpenEnvironment.mobile,
      );

      expect(
        await nonGet.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.external,
          ),
        ),
        DocumentOpenResult.unavailable,
      );
      expect(
        await permissive.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.downloadOnly,
          ),
        ),
        DocumentOpenResult.unavailable,
      );
    });

    test(
      'rejects malformed HTTPS and inconsistent policy/action descriptors',
      () async {
        final launcher = _Launcher();
        final malformed = DocumentOpenService(
          descriptorSource: (_) async => _DescriptorSource.descriptor.copyWith(
            url: Uri.parse('https:///report.pdf'),
          ),
          launcher: launcher,
          environment: DocumentOpenEnvironment.mobile,
        );
        final inconsistent = DocumentOpenService(
          descriptorSource: (_) async => _DescriptorSource.descriptor.copyWith(
            openPolicy: DocumentOpenPolicy.attachmentOnly,
            action: DocumentOpenAction.open,
          ),
          launcher: launcher,
          environment: DocumentOpenEnvironment.mobile,
        );

        const request = DocumentOpenRequest(
          coreId: 7,
          openPolicy: DocumentOpenPolicy.external,
        );
        expect(await malformed.open(request), DocumentOpenResult.unavailable);
        expect(
          await inconsistent.open(request),
          DocumentOpenResult.unavailable,
        );
        expect(launcher.launched, isEmpty);
      },
    );

    test('rejects expired descriptors without launching', () async {
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: (_) async => _DescriptorSource.descriptor.copyWith(
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          ),
        ),
        launcher: launcher,
        environment: DocumentOpenEnvironment.web,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            openPolicy: DocumentOpenPolicy.external,
          ),
        ),
        DocumentOpenResult.unavailable,
      );
      expect(launcher.launched, isEmpty);
      expect(launcher.closed, 1);
    });

    test('attachment-only content never launches a local file', () async {
      final source = _DescriptorSource(
        descriptor: _DescriptorSource.descriptor.copyWith(
          openPolicy: DocumentOpenPolicy.attachmentOnly,
          action: DocumentOpenAction.download,
        ),
      );
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: source.load,
        launcher: launcher,
        environment: DocumentOpenEnvironment.desktop,
        localFileExists: (_) async => true,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            localPath: '/tmp/page.html',
            openPolicy: DocumentOpenPolicy.attachmentOnly,
          ),
        ),
        DocumentOpenResult.downloadStarted,
      );
      expect(launcher.launched.single.scheme, 'https');
    });

    test(
      'stale external request rejects attachment-only descriptor before launch',
      () async {
        final launcher = _Launcher();
        final service = DocumentOpenService(
          descriptorSource: (_) async => _DescriptorSource.descriptor.copyWith(
            openPolicy: DocumentOpenPolicy.attachmentOnly,
            action: DocumentOpenAction.download,
          ),
          launcher: launcher,
          environment: DocumentOpenEnvironment.mobile,
        );

        expect(
          await service.open(
            const DocumentOpenRequest(
              coreId: 7,
              openPolicy: DocumentOpenPolicy.external,
            ),
          ),
          DocumentOpenResult.unavailable,
        );
        expect(launcher.launched, isEmpty);
        expect(launcher.closed, 1);
      },
    );
  });
}

class _DescriptorSource {
  _DescriptorSource({DocumentOpenDescriptor? descriptor})
    : _descriptor = descriptor ?? _DescriptorSource.descriptor;

  static const url = 'https://storage.example/report.pdf?signature=secret';
  static final descriptor = DocumentOpenDescriptor(
    method: 'GET',
    url: Uri.parse(url),
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    openPolicy: DocumentOpenPolicy.external,
    action: DocumentOpenAction.open,
  );

  final DocumentOpenDescriptor _descriptor;
  int calls = 0;

  Future<DocumentOpenDescriptor> load(int id) async {
    calls += 1;
    return _descriptor;
  }
}

const _pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2d];

class _ThrowingLauncher implements ExternalDocumentLauncher {
  @override
  ExternalOpenReservation reserve() => throw StateError('popup denied');
}

class _Launcher implements ExternalDocumentLauncher {
  _Launcher({List<bool>? results}) : _results = results ?? <bool>[];

  final List<bool> _results;
  final List<Uri> launched = [];
  int reservations = 0;
  int closed = 0;

  @override
  ExternalOpenReservation reserve() {
    reservations += 1;
    return _Reservation(this);
  }
}

class _Reservation implements ExternalOpenReservation {
  _Reservation(this.owner);

  final _Launcher owner;

  @override
  Future<bool> launch(Uri uri) async {
    owner.launched.add(uri);
    return owner._results.isEmpty ? true : owner._results.removeAt(0);
  }

  @override
  void close() => owner.closed += 1;
}
