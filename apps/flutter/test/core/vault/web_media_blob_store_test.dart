import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/vault/web_media_blob_store.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  test('VM adapter reports unavailable and never falls back', () async {
    final capability = await probeWebMediaBlobStoreCapability();
    expect(capability.capability, WebVaultCapability.opfsUnavailable);

    final keys = _Keys(VaultAccountId('adapter-test'));
    addTearDown(keys.dispose);
    await expectLater(
      openWebMediaBlobStore(accountId: keys.accountId, keyMaterial: keys),
      throwsA(
        isA<VaultFailure>().having(
          (failure) => failure.code,
          'code',
          VaultFailureCode.backendUnavailable,
        ),
      ),
    );
  });
}

final class _Keys implements VaultKeyMaterial {
  _Keys(this.accountId) : _bytes = Uint8List(32);

  @override
  final VaultAccountId accountId;
  Uint8List? _bytes;

  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) =>
      Future.sync(() => operation(_bytes!));

  @override
  Future<void> dispose() async {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
  }
}
