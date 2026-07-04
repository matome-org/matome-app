// Tests for DekSessionGuard — task #1861, plan #131 (web wave).
//
// Written FIRST per TDD. This is the mechanism that minimizes how long the
// decrypted DEK sits live in the JS heap on web (the exact exposure #1861
// hardens): a live browser tab always holds SOME decrypted key while the
// store is open (that is unavoidable — see the honest-limit note in
// .docs/internal/at-rest-key-flow.md §6), but this guard bounds *how long*
// by wiping the key (`Dek.wipe()`, zeroing the bytes in place) on explicit
// lock, explicit logout, and an idle timeout — and requires a fresh
// `adopt()` (i.e. a full re-unlock through the password flow) before the
// store can be used again. No path in this class ever resurrects a wiped
// key.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/dek_session_guard.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';

void main() {
  group('DekSessionGuard.adopt', () {
    test('makes the DEK current and reports unlocked', () {
      final guard = DekSessionGuard();
      final dek = Dek.generate();

      guard.adopt(dek);

      expect(guard.isUnlocked, isTrue);
      expect(guard.current, same(dek));

      guard.dispose();
    });

    test(
        'wipes the PREVIOUSLY-live DEK before swapping in a new one when '
        'adopt() is called again without an intervening lock/logout '
        '(okt-audit B3 info follow-up)', () {
      final guard = DekSessionGuard();
      final firstDek = Dek.generate();
      expect(firstDek.bytes.any((b) => b != 0), isTrue); // sanity

      guard.adopt(firstDek);
      expect(guard.current, same(firstDek));

      final secondDek = Dek.generate();
      guard.adopt(secondDek);

      // The new key is live and untouched...
      expect(guard.current, same(secondDek));
      expect(guard.isUnlocked, isTrue);
      expect(secondDek.bytes.any((b) => b != 0), isTrue);
      // ...but the OLD reference — which nothing else can reach anymore —
      // must have been zeroed rather than left live in the heap.
      expect(
        firstDek.bytes.every((b) => b == 0),
        isTrue,
        reason:
            'adopt() must wipe a previously-live DEK before replacing it; '
            'a non-zero byte here means the old key was silently dropped '
            'instead of wiped',
      );

      guard.dispose();
    });

    test('adopting the SAME instance again is a harmless no-op wipe-wise',
        () {
      final guard = DekSessionGuard();
      final dek = Dek.generate();
      guard.adopt(dek);

      guard.adopt(dek);

      expect(guard.current, same(dek));
      expect(
        dek.bytes.any((b) => b != 0),
        isTrue,
        reason: 're-adopting the identical instance must not wipe it',
      );

      guard.dispose();
    });
  });

  group('DekSessionGuard.lock', () {
    test('wipes the DEK bytes to zero (same instance) and clears current', () {
      final guard = DekSessionGuard();
      final dek = Dek.generate();
      expect(dek.bytes.any((b) => b != 0), isTrue); // sanity: CSPRNG, not all-zero
      guard.adopt(dek);

      guard.lock();

      expect(guard.isUnlocked, isFalse);
      expect(guard.current, isNull);
      expect(dek.bytes.every((b) => b == 0), isTrue);
    });

    test('re-unlock after lock requires a fresh adopt() — the guard never '
        'resurrects the wiped key', () {
      final guard = DekSessionGuard();
      final dek = Dek.generate();
      guard.adopt(dek);
      guard.lock();

      expect(guard.current, isNull);

      final freshDek = Dek.generate();
      guard.adopt(freshDek);
      expect(guard.isUnlocked, isTrue);
      expect(guard.current, same(freshDek));
      expect(guard.current, isNot(same(dek)));
    });

    test('is a no-op (does not throw) when nothing is unlocked yet', () {
      final guard = DekSessionGuard();
      expect(guard.lock, returnsNormally);
      expect(guard.isUnlocked, isFalse);
    });
  });

  group('DekSessionGuard.logout', () {
    test('wipes the DEK bytes to zero and clears current', () {
      final guard = DekSessionGuard();
      final dek = Dek.generate();
      guard.adopt(dek);

      guard.logout();

      expect(guard.isUnlocked, isFalse);
      expect(guard.current, isNull);
      expect(dek.bytes.every((b) => b == 0), isTrue);
    });
  });

  group('DekSessionGuard idle timeout', () {
    test('wipes the DEK automatically once idleTimeout elapses with no '
        'activity', () {
      fakeAsync((async) {
        final guard = DekSessionGuard(idleTimeout: const Duration(minutes: 5));
        final dek = Dek.generate();
        guard.adopt(dek);

        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(guard.isUnlocked, isTrue, reason: 'not idle long enough yet');

        async.elapse(const Duration(seconds: 2));
        expect(guard.isUnlocked, isFalse, reason: 'idle timeout should fire');
        expect(dek.bytes.every((b) => b == 0), isTrue);

        guard.dispose();
      });
    });

    test('noteActivity() resets the idle timer so an active session never '
        'gets wiped', () {
      fakeAsync((async) {
        final guard = DekSessionGuard(idleTimeout: const Duration(minutes: 5));
        final dek = Dek.generate();
        guard.adopt(dek);

        async.elapse(const Duration(minutes: 4));
        guard.noteActivity();
        async.elapse(const Duration(minutes: 4));
        expect(
          guard.isUnlocked,
          isTrue,
          reason: 'activity at t=4m should have pushed the timeout to t=9m',
        );

        async.elapse(const Duration(minutes: 2));
        expect(guard.isUnlocked, isFalse);
        expect(dek.bytes.every((b) => b == 0), isTrue);

        guard.dispose();
      });
    });

    test('noteActivity() before any adopt() is a harmless no-op', () {
      fakeAsync((async) {
        final guard = DekSessionGuard(idleTimeout: const Duration(minutes: 5));
        expect(guard.noteActivity, returnsNormally);
        async.elapse(const Duration(minutes: 10));
        expect(guard.isUnlocked, isFalse);
        guard.dispose();
      });
    });

    test('dispose() cancels the pending idle timer without wiping the key',
        () {
      fakeAsync((async) {
        final guard = DekSessionGuard(idleTimeout: const Duration(minutes: 5));
        final dek = Dek.generate();
        guard.adopt(dek);

        guard.dispose();
        async.elapse(const Duration(minutes: 10));

        // dispose() intentionally does not wipe — callers that want a wipe
        // call lock()/logout() explicitly first. This assertion just proves
        // no dangling Timer fires after dispose (no crash / no stray wipe by
        // a leaked callback racing after teardown).
        expect(dek.bytes.any((b) => b != 0), isTrue);
      });
    });
  });

  group('DekSessionGuard.onWipe', () {
    test('reports DekWipeReason.lock', () {
      DekWipeReason? seen;
      final guard = DekSessionGuard(onWipe: (r) => seen = r);
      guard.adopt(Dek.generate());
      guard.lock();
      expect(seen, DekWipeReason.lock);
    });

    test('reports DekWipeReason.logout', () {
      DekWipeReason? seen;
      final guard = DekSessionGuard(onWipe: (r) => seen = r);
      guard.adopt(Dek.generate());
      guard.logout();
      expect(seen, DekWipeReason.logout);
    });

    test('reports DekWipeReason.idleTimeout', () {
      fakeAsync((async) {
        DekWipeReason? seen;
        final guard = DekSessionGuard(
          idleTimeout: const Duration(minutes: 1),
          onWipe: (r) => seen = r,
        );
        guard.adopt(Dek.generate());
        async.elapse(const Duration(minutes: 2));
        expect(seen, DekWipeReason.idleTimeout);
        guard.dispose();
      });
    });

    test('re-adopting after a wipe restarts the idle window (does not fire '
        'early using stale timing)', () {
      fakeAsync((async) {
        final guard = DekSessionGuard(idleTimeout: const Duration(minutes: 5));
        guard.adopt(Dek.generate());
        async.elapse(const Duration(minutes: 3));
        guard.logout();

        final freshDek = Dek.generate();
        guard.adopt(freshDek);
        async.elapse(const Duration(minutes: 4));
        expect(guard.isUnlocked, isTrue);

        async.elapse(const Duration(minutes: 2));
        expect(guard.isUnlocked, isFalse);
        expect(freshDek.bytes.every((b) => b == 0), isTrue);

        guard.dispose();
      });
    });
  });
}
