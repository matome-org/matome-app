import 'dart:convert';

import '../../features/auth/recovery_repository.dart';
import '../crypto/envelope.dart';
import '../crypto/kdf_params.dart';
import '../crypto/recovery_code.dart';
import '../crypto/recovery_flow.dart';

final class VaultRecoveryResult {
  const VaultRecoveryResult({required this.rotatedRecoveryCode});

  /// Must be shown exactly once and never logged or persisted in plaintext.
  final String rotatedRecoveryCode;
}

/// Coordinates the reset-token boundary without opening a Vault store. The
/// Core credentials are updated before the still-valid reset token rotates the
/// keybundle, and the recovered DEK is always wiped before returning.
final class VaultRecoveryCoordinator {
  const VaultRecoveryCoordinator(this._gateway);

  final RecoveryKeyBundleGateway _gateway;

  Future<VaultRecoveryResult> rewrapAndReset({
    required String resetToken,
    required String recoveryCode,
    required String newPassword,
    required Future<void> Function() updateCorePassword,
  }) async {
    final bundle = await _gateway.fetchRecoveryBundle(resetToken: resetToken);
    final params = Argon2idParams.fromJson(bundle.kdfParams);
    final enteredCode = RecoveryCode.parse(recoveryCode);
    final result = await resetPasswordWithRecoveryCode(
      enteredCode: enteredCode,
      saltRec: base64Decode(bundle.saltRec),
      wrappedDekRecovery: WrappedEnvelope.fromBase64(bundle.wrappedDekRecovery),
      newPassword: newPassword,
      params: params,
    );
    try {
      // If the following PUT fails, the old recovery bundle remains retryable.
      // The opposite order can publish new wraps and then lose the only new
      // recovery code if the Core credential update fails.
      await updateCorePassword();
      await _gateway.uploadRotatedBundle(
        resetToken: resetToken,
        wrappedDekPw: result.wrappedDekPw.toBase64(),
        wrappedDekRecovery: result.rotatedRecovery.wrappedDekRecovery
            .toBase64(),
        saltEnc: base64Encode(result.saltEnc),
        saltRec: base64Encode(result.rotatedRecovery.saltRec),
        saltAuth: bundle.saltAuth,
        kdfParams: params.toJson(),
      );
      final rotatedCode = result.rotatedRecovery.code.formatted;
      return VaultRecoveryResult(rotatedRecoveryCode: rotatedCode);
    } finally {
      result.dek.wipe();
      enteredCode.rawBytes.fillRange(0, enteredCode.rawBytes.length, 0);
      result.rotatedRecovery.code.rawBytes.fillRange(
        0,
        result.rotatedRecovery.code.rawBytes.length,
        0,
      );
    }
  }
}
