import 'package:matome_vault/matome_vault.dart';

import '../crypto/envelope.dart';
import '../crypto/key_material.dart';
import '../crypto/key_unwrapper.dart';
import '../db/db_encryption.dart';
import 'vault_session_controller.dart';

/// Account-scoped device wrapping. It stores no Vault data and never mints an
/// Account DEK; enrollment only wraps the DEK recovered from the keybundle.
final class AccountDeviceWrapGateway implements DeviceWrapGateway {
  AccountDeviceWrapGateway(this._store);

  final SecureKeyStore _store;

  String _wrapKey(VaultAccountId accountId) =>
      'matome.vault.${accountId.value}.wrapped_dek_device';

  @override
  Future<void> enroll(VaultAccountId accountId, Dek dek) async {
    final existing = await _store.read(DeviceKeystoreKeyUnwrapper.storageKey);
    final Kek kek;
    if (existing == null || existing.isEmpty) {
      final bytes = secureRandomBytes(kSymmetricKeyLength);
      await _store.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hexEncodeKeyBytes(bytes),
      );
      kek = Kek(bytes);
    } else {
      kek = await DeviceKeystoreKeyUnwrapper(_store).deriveKEK();
    }
    try {
      final wrapped = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek.bytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );
      await _store.write(_wrapKey(accountId), wrapped.toBase64());
    } finally {
      kek.wipe();
    }
  }

  @override
  Future<Dek> unwrap(VaultAccountId accountId) async {
    final encoded = await _store.read(_wrapKey(accountId));
    if (encoded == null || encoded.isEmpty) {
      throw StateError('device wrap is not enrolled for this account');
    }
    final wrapped = WrappedEnvelope.fromBase64(encoded);
    final KeyUnwrapper unwrapper = DeviceKeystoreKeyUnwrapper(_store);
    return unwrapper.unwrapDek(wrapped);
  }

  @override
  Future<void> clear(VaultAccountId accountId) =>
      _store.write(_wrapKey(accountId), '');
}
