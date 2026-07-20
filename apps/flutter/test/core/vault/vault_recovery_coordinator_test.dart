import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/vault/key_bundle_repository.dart';
import 'package:matome_flutter/core/vault/vault_recovery_coordinator.dart';
import 'package:matome_flutter/core/vault/vault_session_controller.dart';
import 'package:matome_flutter/features/auth/recovery_repository.dart';
import 'package:matome_vault/matome_vault.dart';

final class _Bundles implements KeyBundleGateway, RecoveryKeyBundleGateway {
  AccountKeyBundle? bundle;
  bool uploadedRecovery = false;

  @override
  Future<AccountKeyBundle?> fetch(VaultAccountId accountId) async => bundle;

  @override
  Future<AccountKeyBundle> put(AccountKeyBundle value) async {
    bundle = value;
    return value;
  }

  @override
  Future<RecoveryKeyBundle> fetchRecoveryBundle({
    required String resetToken,
  }) async => RecoveryKeyBundle.fromJson(bundle!.toJson());

  @override
  Future<void> uploadRotatedBundle({
    required String resetToken,
    required String wrappedDekPw,
    required String wrappedDekRecovery,
    required String saltEnc,
    required String saltRec,
    required String saltAuth,
    required Map<String, dynamic> kdfParams,
  }) async {
    uploadedRecovery = true;
    bundle = bundle!.copyWith(
      wrappedDekPw: wrappedDekPw,
      wrappedDekRecovery: wrappedDekRecovery,
      saltEnc: saltEnc,
      saltRec: saltRec,
      saltAuth: saltAuth,
      kdfParams: kdfParams,
    );
  }
}

void main() {
  test('recovery reset rotates wraps but preserves the Account DEK', () async {
    final gateway = _Bundles();
    final owner = VaultAccountId('owner');
    final session = VaultSessionController(
      keyBundles: gateway,
      platform: VaultPlatform.web,
    );
    await session.unlockAfterPasswordLogin(
      accountId: owner,
      password: 'old password',
    );
    final before = await session.keyMaterial!.use(Uint8List.fromList);
    final recoveryCode = session.takePendingRecoveryCode()!;
    session.logout();
    var corePasswordUpdatedBeforeBundle = false;

    final result = await VaultRecoveryCoordinator(gateway).rewrapAndReset(
      resetToken: 'reset-token',
      recoveryCode: recoveryCode,
      newPassword: 'new password',
      updateCorePassword: () async {
        corePasswordUpdatedBeforeBundle = !gateway.uploadedRecovery;
      },
    );

    expect(corePasswordUpdatedBeforeBundle, isTrue);
    expect(result.rotatedRecoveryCode, isNot(recoveryCode));
    await session.unlockAfterPasswordLogin(
      accountId: owner,
      password: 'new password',
    );
    expect(await session.keyMaterial!.use(Uint8List.fromList), before);
    session.logout();
  });
}
