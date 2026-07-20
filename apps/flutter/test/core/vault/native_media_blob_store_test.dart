@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/vault/native_media_blob_store.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  test(
    'host supplies Application Support without exposing a package dependency',
    () async {
      final support = await Directory.systemTemp.createTemp(
        'matome-host-vault-',
      );
      addTearDown(() => support.delete(recursive: true));
      final accountId = VaultAccountId('opaque-account');
      final keys = _Keys(accountId);
      addTearDown(keys.dispose);

      final store = await openNativeMediaBlobStore(
        accountId: accountId,
        keyMaterial: keys,
        resolveApplicationSupport: () async => support.uri,
      );
      final stat = await store.ingest(_Input());

      expect(stat.state, VaultBlobState.ready);
      expect(support.listSync(recursive: true).whereType<File>(), isNotEmpty);
    },
  );

  test('host rejects non-file support locations', () async {
    final accountId = VaultAccountId('opaque-account');
    final keys = _Keys(accountId);
    addTearDown(keys.dispose);

    await expectLater(
      openNativeMediaBlobStore(
        accountId: accountId,
        keyMaterial: keys,
        resolveApplicationSupport: () async =>
            Uri.parse('https://example.test/vault'),
      ),
      throwsArgumentError,
    );
  });
}

final class _Input implements MediaInput {
  @override
  String? get contentType => 'application/octet-stream';
  @override
  String get filename => 'never-a-physical-name.bin';
  @override
  int get knownLength => 3;
  @override
  Stream<List<int>> openRead() => Stream.value([1, 2, 3]);
}

final class _Keys implements VaultKeyMaterial {
  _Keys(this.accountId);
  @override
  final VaultAccountId accountId;
  final bytes = Uint8List.fromList(List<int>.generate(32, (index) => index));

  @override
  Future<void> dispose() async => bytes.fillRange(0, bytes.length, 0);

  @override
  Future<T> use<T>(
    FutureOr<T> Function(Uint8List accountDek) operation,
  ) async => await operation(bytes);
}
