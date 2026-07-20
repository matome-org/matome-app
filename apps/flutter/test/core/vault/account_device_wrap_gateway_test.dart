import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:matome_flutter/core/vault/account_device_wrap_gateway.dart';
import 'package:matome_vault/matome_vault.dart';

final class _MemorySecureStore implements SecureKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test(
    'device wraps are account-scoped and preserve the supplied Account DEK',
    () async {
      final store = _MemorySecureStore();
      final gateway = AccountDeviceWrapGateway(store);
      final ownerA = VaultAccountId('owner_a');
      final ownerB = VaultAccountId('owner_b');
      final dekA = Dek.generate();
      final dekB = Dek.generate();
      final expectedA = List<int>.from(dekA.bytes);
      final expectedB = List<int>.from(dekB.bytes);

      await gateway.enroll(ownerA, dekA);
      await gateway.enroll(ownerB, dekB);

      expect((await gateway.unwrap(ownerA)).bytes, expectedA);
      expect((await gateway.unwrap(ownerB)).bytes, expectedB);
      expect(
        store.values.keys.where((key) => key.contains('wrapped_dek_device')),
        hasLength(2),
      );
    },
  );

  test(
    'missing owner wrap fails instead of minting a replacement DEK',
    () async {
      final gateway = AccountDeviceWrapGateway(_MemorySecureStore());

      await expectLater(
        gateway.unwrap(VaultAccountId('not_enrolled')),
        throwsStateError,
      );
    },
  );
}
