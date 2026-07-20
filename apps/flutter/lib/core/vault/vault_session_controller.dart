import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_vault/matome_vault.dart';

import '../crypto/argon2id.dart';
import '../crypto/envelope.dart';
import '../crypto/kdf_params.dart';
import '../crypto/key_material.dart';
import '../crypto/key_unwrapper.dart';
import '../crypto/recovery_flow.dart';
import 'key_bundle_repository.dart';

enum VaultSessionPhase {
  signedOut,
  locked,
  unlocking,
  opening,
  ready,
  failedClosed,
}

enum VaultPlatform { web, native }

enum VaultLockReason { explicit, timeout }

final class VaultSessionSnapshot {
  const VaultSessionSnapshot(this.phase, {this.accountId, this.failure});

  final VaultSessionPhase phase;
  final VaultAccountId? accountId;
  final String? failure;
}

final class VaultUnlockException implements Exception {
  const VaultUnlockException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'VaultUnlockException: $message';
}

abstract interface class DeviceWrapGateway {
  Future<void> enroll(VaultAccountId accountId, Dek dek);
  Future<Dek> unwrap(VaultAccountId accountId);
  Future<void> clear(VaultAccountId accountId);
}

final class _GuardedKeyMaterial implements VaultKeyMaterial {
  _GuardedKeyMaterial(this.accountId, this._dek);

  @override
  final VaultAccountId accountId;
  Dek? _dek;
  bool _revoked = false;

  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) async {
    final dek = _dek;
    if (_revoked || dek == null) {
      throw const VaultFailure(VaultFailureCode.locked, 'Vault is locked.');
    }
    return operation(dek.bytes);
  }

  @override
  Future<void> dispose() async {
    _revoked = true;
    final dek = _dek;
    _dek = null;
    dek?.wipe();
  }

  void revoke() => _revoked = true;
}

final class VaultLockDeferral {
  VaultLockDeferral(this._owner, this._generation);
  VaultSessionController? _owner;
  final int _generation;

  bool get isActive => _owner?._isDeferralActive(_generation) ?? false;

  void release() {
    final owner = _owner;
    _owner = null;
    owner?._releaseDeferral(_generation);
  }
}

/// Owns only the unlocked account-key session. Physical Vault/Drift opening is
/// delegated to [openVault] and intentionally remains outside this task.
final class VaultSessionController extends StateNotifier<VaultSessionSnapshot> {
  factory VaultSessionController({
    required KeyBundleGateway keyBundles,
    required VaultPlatform platform,
    DeviceWrapGateway? deviceWraps,
    Future<void> Function(VaultKeyMaterial material)? openVault,
    Future<void> Function()? closeVault,
    Duration lockTimeout = const Duration(minutes: 15),
    Timer Function(Duration, void Function())? timerFactory,
  }) => VaultSessionController._(
    keyBundles,
    platform,
    deviceWraps,
    openVault ?? _noPhysicalStore,
    closeVault ?? _noPhysicalClose,
    lockTimeout,
    timerFactory ?? Timer.new,
  );

  VaultSessionController._(
    this._keyBundles,
    this._platform,
    this._deviceWraps,
    this._openVault,
    this._closeVault,
    this.lockTimeout,
    this._timerFactory,
  ) : super(const VaultSessionSnapshot(VaultSessionPhase.signedOut));

  final KeyBundleGateway _keyBundles;
  final VaultPlatform _platform;
  final DeviceWrapGateway? _deviceWraps;
  final Future<void> Function(VaultKeyMaterial material) _openVault;
  final Future<void> Function() _closeVault;
  final Duration lockTimeout;
  final Timer Function(Duration, void Function()) _timerFactory;

  _GuardedKeyMaterial? _keyMaterial;
  AccountKeyBundle? _bundle;
  String? _pendingRecoveryCode;
  bool _passwordRequired = false;
  int _deferralGeneration = 0;
  int _activeDeferrals = 0;
  VaultLockReason? _pendingLock;
  Timer? _lockTimer;

  VaultKeyMaterial? get keyMaterial =>
      state.phase == VaultSessionPhase.ready ? _keyMaterial : null;
  String? takePendingRecoveryCode() {
    final code = _pendingRecoveryCode;
    _pendingRecoveryCode = null;
    return code;
  }

  static Future<void> _noPhysicalStore(VaultKeyMaterial _) async {}
  static Future<void> _noPhysicalClose() async {}

  Future<void> restoreAuthenticated({required VaultAccountId accountId}) async {
    await _closeMaterial();
    state = VaultSessionSnapshot(
      VaultSessionPhase.locked,
      accountId: accountId,
    );
    if (_platform == VaultPlatform.native && _deviceWraps != null) {
      try {
        await unlockWithDevice(accountId: accountId, coldStart: true);
      } catch (_) {
        await _closeMaterial();
        state = VaultSessionSnapshot(
          VaultSessionPhase.locked,
          accountId: accountId,
        );
      }
    }
  }

  Future<void> unlockAfterPasswordLogin({
    required VaultAccountId accountId,
    required String password,
  }) async {
    if (state.accountId != null && state.accountId != accountId) {
      await _closeMaterial();
      _bundle = null;
      _pendingRecoveryCode = null;
    }
    state = VaultSessionSnapshot(
      VaultSessionPhase.unlocking,
      accountId: accountId,
    );
    try {
      final bundle = await _keyBundles.fetch(accountId);
      final Dek dek;
      if (bundle == null) {
        final enrollment = await _enroll(accountId, password);
        dek = enrollment.$1;
        _bundle = enrollment.$2;
      } else {
        if (bundle.accountId != accountId) {
          throw StateError('keybundle owner mismatch');
        }
        _validateBundle(bundle);
        final params = Argon2idParams.fromJson(bundle.kdfParams);
        final unwrapper = PasswordKeyUnwrapper(
          password: password,
          saltEnc: base64Decode(bundle.saltEnc),
          params: params,
        );
        dek = await unwrapper.unwrapDek(
          WrappedEnvelope.fromBase64(bundle.wrappedDekPw),
        );
        _bundle = bundle;
      }
      _passwordRequired = false;
      if (_platform == VaultPlatform.native && _deviceWraps != null) {
        await _deviceWraps.enroll(accountId, dek);
      }
      await _adoptAndOpen(accountId, dek);
    } catch (error) {
      await _failClosed(accountId, error);
    }
  }

  Future<void> unlockWithDevice({
    required VaultAccountId accountId,
    bool coldStart = false,
  }) async {
    if (_platform != VaultPlatform.native || _deviceWraps == null) {
      throw const VaultUnlockException('Device unlock is unavailable.');
    }
    if (_passwordRequired || !coldStart) {
      throw const VaultUnlockException('Password proof is required.');
    }
    state = VaultSessionSnapshot(
      VaultSessionPhase.unlocking,
      accountId: accountId,
    );
    try {
      final dek = await _deviceWraps.unwrap(accountId);
      await _adoptAndOpen(accountId, dek);
    } catch (error) {
      await _failClosed(accountId, error);
    }
  }

  Future<(Dek, AccountKeyBundle)> _enroll(
    VaultAccountId accountId,
    String password,
  ) async {
    final dek = Dek.generate();
    try {
      final params = Argon2idParams.portableV1;
      final saltEnc = secureRandomBytes(kArgon2SaltLen);
      final saltAuth = secureRandomBytes(kArgon2SaltLen);
      final kekBytes = await deriveArgon2id(
        password: password,
        salt: saltEnc,
        params: params,
      );
      final kek = Kek(kekBytes);
      late final WrappedEnvelope passwordWrap;
      try {
        passwordWrap = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: kek.bytes,
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );
      } finally {
        kek.wipe();
      }
      final recovery = await enrollRecovery(dek: dek, params: params);
      final candidate = AccountKeyBundle(
        accountId: accountId,
        wrappedDekPw: passwordWrap.toBase64(),
        wrappedDekRecovery: recovery.wrappedDekRecovery.toBase64(),
        saltEnc: base64Encode(saltEnc),
        saltRec: base64Encode(recovery.saltRec),
        saltAuth: base64Encode(saltAuth),
        kdfParams: params.toJson(),
      );
      final uploaded = await _keyBundles.put(candidate);
      if (uploaded.accountId != accountId) {
        throw StateError('uploaded keybundle owner mismatch');
      }
      _validateBundle(uploaded);
      if (!_sameBundleMaterial(candidate, uploaded)) {
        throw StateError('uploaded keybundle material mismatch');
      }
      _pendingRecoveryCode = recovery.code.formatted;
      return (dek, uploaded);
    } catch (_) {
      dek.wipe();
      rethrow;
    }
  }

  Future<void> _adoptAndOpen(VaultAccountId accountId, Dek dek) async {
    await _closeMaterial();
    final material = _GuardedKeyMaterial(accountId, dek);
    _keyMaterial = material;
    state = VaultSessionSnapshot(
      VaultSessionPhase.opening,
      accountId: accountId,
    );
    try {
      await _openVault(material);
      state = VaultSessionSnapshot(
        VaultSessionPhase.ready,
        accountId: accountId,
      );
      noteActivity();
    } catch (_) {
      await material.dispose();
      _keyMaterial = null;
      rethrow;
    }
  }

  Future<void> rewrapPassword({required String newPassword}) async {
    final material = _keyMaterial;
    final bundle = _bundle;
    if (state.phase != VaultSessionPhase.ready ||
        material == null ||
        bundle == null) {
      throw const VaultUnlockException('Vault must be ready to rewrap.');
    }
    final params = Argon2idParams.fromJson(bundle.kdfParams);
    final salt = secureRandomBytes(kArgon2SaltLen);
    final kek = Kek(
      await deriveArgon2id(password: newPassword, salt: salt, params: params),
    );
    try {
      final wrap = await material.use(
        (dek) => wrapKey(
          plaintext: dek,
          wrappingKey: kek.bytes,
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        ),
      );
      _bundle = await _keyBundles.put(
        bundle.copyWith(
          wrappedDekPw: wrap.toBase64(),
          saltEnc: base64Encode(salt),
        ),
      );
    } finally {
      kek.wipe();
    }
  }

  VaultLockDeferral deferLock() {
    if (state.phase != VaultSessionPhase.ready) {
      throw StateError('Vault must be ready before deferring lock.');
    }
    _activeDeferrals++;
    return VaultLockDeferral(this, _deferralGeneration);
  }

  void noteActivity() {
    if (state.phase != VaultSessionPhase.ready) return;
    _lockTimer?.cancel();
    _lockTimer = _timerFactory(
      lockTimeout,
      () => unawaited(lockAndWait(reason: VaultLockReason.timeout)),
    );
  }

  bool _isDeferralActive(int generation) =>
      generation == _deferralGeneration && _activeDeferrals > 0;

  void _releaseDeferral(int generation) {
    if (generation != _deferralGeneration || _activeDeferrals == 0) return;
    _activeDeferrals--;
    if (_activeDeferrals == 0 && _pendingLock != null) {
      final reason = _pendingLock!;
      _pendingLock = null;
      unawaited(lockAndWait(reason: reason));
    }
  }

  void lock({VaultLockReason reason = VaultLockReason.explicit}) {
    if (_activeDeferrals > 0) {
      _pendingLock = reason;
      return;
    }
    _passwordRequired = true;
    _pendingRecoveryCode = null;
    final accountId = state.accountId;
    state = VaultSessionSnapshot(
      VaultSessionPhase.locked,
      accountId: accountId,
    );
    unawaited(_closeMaterial());
  }

  Future<void> lockAndWait({
    VaultLockReason reason = VaultLockReason.explicit,
  }) async {
    if (_activeDeferrals > 0) {
      _pendingLock = reason;
      return;
    }
    _passwordRequired = true;
    _pendingRecoveryCode = null;
    final accountId = state.accountId;
    state = VaultSessionSnapshot(
      VaultSessionPhase.locked,
      accountId: accountId,
    );
    await _closeMaterial();
  }

  void logout() {
    _bundle = null;
    _pendingRecoveryCode = null;
    _passwordRequired = false;
    state = const VaultSessionSnapshot(VaultSessionPhase.signedOut);
    unawaited(_closeMaterial());
  }

  Future<void> logoutAndWait() async {
    _bundle = null;
    _pendingRecoveryCode = null;
    _passwordRequired = false;
    state = const VaultSessionSnapshot(VaultSessionPhase.signedOut);
    await _closeMaterial();
  }

  Future<Never> _failClosed(VaultAccountId accountId, Object error) async {
    try {
      await _closeMaterial();
    } catch (_) {
      // The material is revoked synchronously and wiped in _closeMaterial's
      // finally path. Preserve the original unlock/open failure for the UI.
    }
    _bundle = null;
    _pendingRecoveryCode = null;
    state = VaultSessionSnapshot(
      VaultSessionPhase.failedClosed,
      accountId: accountId,
      failure: 'unlock_failed',
    );
    throw VaultUnlockException('The Vault could not be unlocked.', error);
  }

  void _validateBundle(AccountKeyBundle bundle) {
    final saltEnc = base64Decode(bundle.saltEnc);
    final saltRec = base64Decode(bundle.saltRec);
    final saltAuth = base64Decode(bundle.saltAuth);
    if (saltEnc.length != kArgon2SaltLen ||
        saltRec.length != kArgon2SaltLen ||
        saltAuth.length != kArgon2SaltLen) {
      throw const FormatException('invalid keybundle salt length');
    }
    final passwordWrap = WrappedEnvelope.fromBase64(bundle.wrappedDekPw);
    final recoveryWrap = WrappedEnvelope.fromBase64(bundle.wrappedDekRecovery);
    if (passwordWrap.payloadType != PayloadType.dek.byteValue ||
        passwordWrap.wrapperType != WrapperType.passwordKek.byteValue ||
        recoveryWrap.payloadType != PayloadType.dek.byteValue ||
        recoveryWrap.wrapperType != WrapperType.recoveryKek.byteValue) {
      throw const FormatException('invalid keybundle envelope slot');
    }
    Argon2idParams.fromJson(bundle.kdfParams);
  }

  bool _sameBundleMaterial(AccountKeyBundle a, AccountKeyBundle b) =>
      a.wrappedDekPw == b.wrappedDekPw &&
      a.wrappedDekRecovery == b.wrappedDekRecovery &&
      a.saltEnc == b.saltEnc &&
      a.saltRec == b.saltRec &&
      a.saltAuth == b.saltAuth &&
      jsonEncode(a.kdfParams) == jsonEncode(b.kdfParams);

  Future<void> _closeMaterial() async {
    _lockTimer?.cancel();
    _lockTimer = null;
    final material = _keyMaterial;
    _keyMaterial = null;
    material?.revoke();
    _activeDeferrals = 0;
    _pendingLock = null;
    _deferralGeneration++;
    try {
      await _closeVault();
    } finally {
      await material?.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_closeMaterial());
    super.dispose();
  }
}

/// Stable opaque namespace. Raw Core owner ids never become Vault paths.
VaultAccountId vaultAccountIdForOwner(int ownerId) {
  final digest = sha256.convert(utf8.encode('matome-vault-owner-v1:$ownerId'));
  return VaultAccountId(base64UrlEncode(digest.bytes).replaceAll('=', ''));
}
