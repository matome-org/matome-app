import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/vault/key_bundle_repository.dart';
import 'package:matome_flutter/core/vault/vault_session_controller.dart';
import 'package:matome_vault/matome_vault.dart';

final class _MemoryBundles implements KeyBundleGateway {
  final Map<VaultAccountId, AccountKeyBundle> bundles = {};
  AccountKeyBundle? fetchOverride;
  int uploads = 0;

  @override
  Future<AccountKeyBundle?> fetch(VaultAccountId accountId) async =>
      fetchOverride ?? bundles[accountId];

  @override
  Future<AccountKeyBundle> put(AccountKeyBundle bundle) async {
    uploads++;
    bundles[bundle.accountId] = bundle;
    return bundle;
  }
}

final class _MemoryDeviceWraps implements DeviceWrapGateway {
  final Map<VaultAccountId, Uint8List> deks = {};

  @override
  Future<void> enroll(VaultAccountId accountId, Dek dek) async {
    deks[accountId] = Uint8List.fromList(dek.bytes);
  }

  @override
  Future<Dek> unwrap(VaultAccountId accountId) async {
    final bytes = deks[accountId];
    if (bytes == null) throw StateError('not enrolled');
    return Dek(Uint8List.fromList(bytes));
  }

  @override
  Future<void> clear(VaultAccountId accountId) async {}
}

final class _ManualTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

Future<Uint8List> _readDek(VaultSessionController controller) {
  return controller.keyMaterial!.use(Uint8List.fromList);
}

void main() {
  const password = 'correct horse battery staple';
  final ownerA = VaultAccountId('owner_a');
  final ownerB = VaultAccountId('owner_b');

  test('login without a keybundle enrolls and uploads before ready', () async {
    final bundles = _MemoryBundles();
    var openedAfterUpload = false;
    final controller = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
      openVault: (material) async {
        openedAfterUpload = bundles.uploads == 1;
      },
    );

    await controller.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: password,
    );

    expect(controller.state.phase, VaultSessionPhase.ready);
    expect(openedAfterUpload, isTrue);
    expect(controller.takePendingRecoveryCode(), isNotNull);
    expect(controller.takePendingRecoveryCode(), isNull);
    expect(bundles.bundles[ownerA], isNotNull);
    controller.logout();
  });

  test('two clients unwrap the same account DEK', () async {
    final bundles = _MemoryBundles();
    final first = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await first.unlockAfterPasswordLogin(accountId: ownerA, password: password);
    final expected = await _readDek(first);
    first.logout();

    final second = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await second.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: password,
    );

    expect(await _readDek(second), expected);
    second.logout();
  });

  test('wrong password, owner, and corrupt envelope fail closed', () async {
    final bundles = _MemoryBundles();
    final enrolled = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await enrolled.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: password,
    );
    enrolled.logout();

    final wrongPassword = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await expectLater(
      wrongPassword.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: 'wrong password',
      ),
      throwsA(isA<VaultUnlockException>()),
    );
    expect(wrongPassword.state.phase, VaultSessionPhase.failedClosed);
    expect(wrongPassword.keyMaterial, isNull);

    bundles.fetchOverride = bundles.bundles[ownerA]!.copyWith(
      accountId: ownerB,
    );
    final wrongOwner = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await expectLater(
      wrongOwner.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      ),
      throwsA(isA<VaultUnlockException>()),
    );
    expect(wrongOwner.keyMaterial, isNull);

    final original = bundles.bundles[ownerA]!;
    bundles.fetchOverride = original.copyWith(wrappedDekPw: 'not-base64');
    final corrupt = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await expectLater(
      corrupt.unlockAfterPasswordLogin(accountId: ownerA, password: password),
      throwsA(isA<VaultUnlockException>()),
    );
    expect(corrupt.keyMaterial, isNull);
  });

  test('web restored JWT remains locked until password proof', () async {
    final controller = VaultSessionController(
      keyBundles: _MemoryBundles(),
      platform: VaultPlatform.web,
    );

    await controller.restoreAuthenticated(accountId: ownerA);

    expect(controller.state.phase, VaultSessionPhase.locked);
    expect(controller.keyMaterial, isNull);
  });

  test(
    'native cold start may use device wrap but timeout requires password',
    () async {
      final bundles = _MemoryBundles();
      final devices = _MemoryDeviceWraps();
      final enrollment = VaultSessionController(
        keyBundles: bundles,
        deviceWraps: devices,
        platform: VaultPlatform.native,
      );
      await enrollment.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      );
      enrollment.logout();

      final restored = VaultSessionController(
        keyBundles: bundles,
        deviceWraps: devices,
        platform: VaultPlatform.native,
      );
      await restored.restoreAuthenticated(accountId: ownerA);
      expect(restored.state.phase, VaultSessionPhase.ready);

      restored.lock(reason: VaultLockReason.timeout);
      expect(restored.state.phase, VaultSessionPhase.locked);
      await expectLater(
        restored.unlockWithDevice(accountId: ownerA),
        throwsA(isA<VaultUnlockException>()),
      );
      await restored.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      );
      expect(restored.state.phase, VaultSessionPhase.ready);
      restored.logout();
    },
  );

  test('configured inactivity timeout locks a ready session', () async {
    void Function()? fireTimeout;
    final controller = VaultSessionController(
      keyBundles: _MemoryBundles(),
      platform: VaultPlatform.web,
      lockTimeout: const Duration(minutes: 3),
      timerFactory: (duration, callback) {
        expect(duration, const Duration(minutes: 3));
        fireTimeout = callback;
        return _ManualTimer();
      },
    );
    await controller.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: password,
    );

    fireTimeout!();

    expect(controller.state.phase, VaultSessionPhase.locked);
    expect(controller.keyMaterial, isNull);
  });

  test(
    'logout and account switch invalidate key material and deferrals',
    () async {
      final bundles = _MemoryBundles();
      final controller = VaultSessionController(
        keyBundles: bundles,
        platform: VaultPlatform.web,
      );
      await controller.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      );
      final oldMaterial = controller.keyMaterial!;
      final lease = controller.deferLock();

      controller.logout();

      expect(controller.state.phase, VaultSessionPhase.signedOut);
      await expectLater(oldMaterial.use((_) {}), throwsA(isA<VaultFailure>()));
      expect(lease.isActive, isFalse);

      await controller.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      );
      final switchedMaterial = controller.keyMaterial!;
      await controller.unlockAfterPasswordLogin(
        accountId: ownerB,
        password: password,
      );
      await expectLater(
        switchedMaterial.use((_) {}),
        throwsA(isA<VaultFailure>()),
      );
      expect(controller.state.accountId, ownerB);
      controller.logout();
    },
  );

  test(
    'capture defers timeout lock until finish or cancel releases lease',
    () async {
      final controller = VaultSessionController(
        keyBundles: _MemoryBundles(),
        platform: VaultPlatform.web,
      );
      await controller.unlockAfterPasswordLogin(
        accountId: ownerA,
        password: password,
      );
      final lease = controller.deferLock();

      controller.lock(reason: VaultLockReason.timeout);
      expect(controller.state.phase, VaultSessionPhase.ready);

      lease.release();
      expect(controller.state.phase, VaultSessionPhase.locked);
      expect(controller.keyMaterial, isNull);
    },
  );

  test('password rewrap keeps the account DEK unchanged', () async {
    final bundles = _MemoryBundles();
    final controller = VaultSessionController(
      keyBundles: bundles,
      platform: VaultPlatform.web,
    );
    await controller.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: password,
    );
    final before = await _readDek(controller);

    await controller.rewrapPassword(newPassword: 'new password long enough');
    controller.logout();
    await controller.unlockAfterPasswordLogin(
      accountId: ownerA,
      password: 'new password long enough',
    );

    expect(await _readDek(controller), before);
    controller.logout();
  });
}
