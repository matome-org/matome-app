import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/documents/document_open_policy.dart';
import 'package:matome_flutter/features/documents/document_open_service.dart';
import 'package:matome_vault/matome_vault.dart';

import '../support/fake_media_blob_store.dart';

void main() {
  test('local-only Vault document opens a revocable temporary lease', () async {
    final launcher = _Launcher();
    final blobs = FakeMediaBlobStore();
    final stat = await blobs.ingest(const _Input([1, 2, 3]));
    final service = DocumentOpenService(
      descriptorSource: (_) => throw UnimplementedError(),
      launcher: launcher,
      environment: DocumentOpenEnvironment.desktop,
      blobStore: () => blobs,
    );

    final result = await service.open(
      DocumentOpenRequest(
        coreId: null,
        blobId: stat.id.value,
        openPolicy: DocumentOpenPolicy.external,
      ),
    );

    expect(result, DocumentOpenResult.openedLocal);
    expect(launcher.reservation.launched.single.scheme, 'blob');
    expect(blobs.activeLeaseCount, 1);
    await service.releaseLocalLease();
    expect(blobs.activeLeaseCount, 0);
  });

  test(
    'oversized local document requires explicit export and creates no lease',
    () async {
      final launcher = _Launcher();
      final blobs = FakeMediaBlobStore();
      final stat = await blobs.ingest(const _Input([1, 2, 3]));
      final service = DocumentOpenService(
        descriptorSource: (_) => throw UnimplementedError(),
        launcher: launcher,
        environment: DocumentOpenEnvironment.desktop,
        blobStore: () => blobs,
      );

      final result = await service.open(
        DocumentOpenRequest(
          coreId: null,
          blobId: stat.id.value,
          byteSize: kMaxVaultDocumentOpenBytes + 1,
          openPolicy: DocumentOpenPolicy.external,
        ),
      );

      expect(result, DocumentOpenResult.unavailable);
      expect(blobs.activeLeaseCount, 0);
      expect(launcher.reservation.launched, isEmpty);
    },
  );

  test(
    'validated Core descriptor opens without a local path fallback',
    () async {
      final launcher = _Launcher();
      final service = DocumentOpenService(
        descriptorSource: (_) async => DocumentOpenDescriptor(
          method: 'GET',
          url: Uri.parse('https://core.example/document'),
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          openPolicy: DocumentOpenPolicy.external,
          action: DocumentOpenAction.open,
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
        DocumentOpenResult.openedRemote,
      );
      expect(launcher.reservation.launched.single.scheme, 'https');
    },
  );

  test(
    'missing local blob falls back to a validated Core descriptor',
    () async {
      final launcher = _Launcher();
      final blobs = FakeMediaBlobStore();
      final service = DocumentOpenService(
        descriptorSource: (_) async => DocumentOpenDescriptor(
          method: 'GET',
          url: Uri.parse('https://core.example/document'),
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          openPolicy: DocumentOpenPolicy.external,
          action: DocumentOpenAction.open,
        ),
        launcher: launcher,
        environment: DocumentOpenEnvironment.desktop,
        blobStore: () => blobs,
      );

      expect(
        await service.open(
          const DocumentOpenRequest(
            coreId: 7,
            blobId: 'missing-blob',
            openPolicy: DocumentOpenPolicy.external,
          ),
        ),
        DocumentOpenResult.openedRemote,
      );
      expect(launcher.reservation.launched.single.scheme, 'https');
    },
  );
}

final class _Input implements MediaInput {
  const _Input(this.value);
  final List<int> value;
  @override
  String get filename => 'document.pdf';
  @override
  String? get contentType => 'application/pdf';
  @override
  int get knownLength => value.length;
  @override
  Stream<List<int>> openRead() => Stream.value(value);
}

final class _Launcher implements ExternalDocumentLauncher {
  final reservation = _Reservation();

  @override
  ExternalOpenReservation reserve() => reservation;
}

final class _Reservation implements ExternalOpenReservation {
  final List<Uri> launched = [];

  @override
  void close() {}

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}
