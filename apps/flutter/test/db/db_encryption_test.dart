import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';

// ---------------------------------------------------------------------------
// SQLCipher key lifecycle (SEC audit-fix #815).
//
// Proves the first-boot-generates / subsequent-boot-reuses contract against a
// fake in-memory secure store (no flutter_secure_storage platform channel), and
// the PRAGMA key statement shape.
// ---------------------------------------------------------------------------

/// In-memory [SecureKeyStore] for tests; counts writes to assert persistence.
class _FakeKeyStore implements SecureKeyStore {
  final Map<String, String> _data = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    _data[key] = value;
  }
}

/// Deterministic Random so the generated key is predictable in tests.
class _SeededRandom implements Random {
  _SeededRandom(this._delegate);
  final Random _delegate;
  @override
  int nextInt(int max) => _delegate.nextInt(max);
  @override
  bool nextBool() => _delegate.nextBool();
  @override
  double nextDouble() => _delegate.nextDouble();
}

void main() {
  group('DbEncryptionKeyManager', () {
    test('first boot generates a 256-bit key and persists it', () async {
      final store = _FakeKeyStore();
      final mgr = DbEncryptionKeyManager(store);

      final key = await mgr.obtainKey();

      // 32 bytes -> 64 hex chars.
      expect(key, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
      // Persisted under the documented key, exactly one write.
      expect(store.writes, 1);
      expect(await store.read(DbEncryptionKeyManager.storageKey), key);
    });

    test('subsequent boot reuses the stored key (no regenerate, no new write)',
        () async {
      final store = _FakeKeyStore();

      final first = await DbEncryptionKeyManager(store).obtainKey();
      // Fresh manager instance == a fresh app boot reading the same store.
      final second = await DbEncryptionKeyManager(store).obtainKey();

      expect(second, first); // same key -> the encrypted DB keeps opening
      expect(store.writes, 1); // only the first boot wrote
    });

    test('two independent stores generate different keys (entropy sanity)',
        () async {
      final a = await DbEncryptionKeyManager(_FakeKeyStore()).obtainKey();
      final b = await DbEncryptionKeyManager(_FakeKeyStore()).obtainKey();
      expect(a, isNot(b));
    });

    test('an empty stored value is treated as missing and regenerated',
        () async {
      final store = _FakeKeyStore();
      await store.write(DbEncryptionKeyManager.storageKey, '');

      final key = await DbEncryptionKeyManager(store).obtainKey();
      expect(key, isNotEmpty);
      expect(key, hasLength(64));
    });

    test('respects an injected Random for deterministic generation', () async {
      final store = _FakeKeyStore();
      final mgr =
          DbEncryptionKeyManager(store, random: _SeededRandom(Random(42)));
      final mgr2 = DbEncryptionKeyManager(
        _FakeKeyStore(),
        random: _SeededRandom(Random(42)),
      );
      expect(await mgr.obtainKey(), await mgr2.obtainKey());
    });

    test('pragmaKeyStatement wraps the hex key as a raw SQLCipher key', () {
      const hex = 'deadbeef';
      expect(
        DbEncryptionKeyManager.pragmaKeyStatement(hex),
        'PRAGMA key = "x\'deadbeef\'"',
      );
    });
  });
}
