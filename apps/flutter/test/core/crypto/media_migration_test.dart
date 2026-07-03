// Task #1856 (plan #131 W4) — TDD coverage for the re-encrypt migration of
// EXISTING plaintext media. Written BEFORE `lib/core/crypto/media_migration.dart`
// per the task's mandatory "crash-replay fixture FIRST" rule.
//
// Coverage map:
//   * crash-replay — the core requirement. Each test durably commits the
//     manifest to EXACTLY one named interruption point (via a fault-injection
//     hook that throws right after that step is recorded — a real crash could
//     not have gotten any further, and could not have recorded any less),
//     then constructs a FRESH [MediaMigrationRunner] (simulating a process
//     restart) and asserts the next run recovers with ZERO data loss.
//   * idempotency — re-running a fully migrated set is a no-op; a partially
//     migrated set converges.
//   * canary — a bounded batch leaves the rest untouched until a later call.
//   * dry-run — counts only, touches nothing.
//   * zero-plaintext-remaining assertion — passes for a clean migration,
//     throws if a plaintext file resurfaces or hashing/structure disagrees.
//   * rollback — restores from backup, reverts the DB row, verifies the
//     restored bytes, fails loudly if the backup is missing.
//   * no best-effort swallow — verification/missing-file failures propagate
//     as exceptions instead of being silently skipped (explicit contrast with
//     `app_storage.dart`'s `moveLegacyMediaInto`, which swallows everything).
//   * gating — `run()` refuses while the `kMediaEncryptionEnabled`-style flag
//     is dark; `dryRun`/`rollback` are not gated.
//   * production wiring — `RecordingsDaoMediaMigrationStore` against a real
//     (in-memory) Drift `AppDatabase`/`RecordingsDao`, not just the fake.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart' show WrappedEnvelope;
import 'package:matome_flutter/core/crypto/key_material.dart' show Dek;
import 'package:matome_flutter/core/crypto/media_cipher.dart'
    show decryptFileStream, kMediaMagic;
import 'package:matome_flutter/core/crypto/media_migration.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/media_migration_store.dart';

/// Thrown by test fault-injection hooks to simulate "the process was killed
/// right here" — never a real production exception type.
class _SimulatedCrash implements Exception {
  const _SimulatedCrash(this.atStep);
  final Object atStep;
  @override
  String toString() => '_SimulatedCrash(at $atStep)';
}

class _FakeRow {
  _FakeRow(this.path);
  String path;
  String? wrappedFek;
  String? fileNoncePrefix;
}

/// In-memory fake [MediaMigrationRecordStore] — lets the crash-replay/
/// idempotency/rollback tests run fast, without a real database, while still
/// exercising the exact same production runner code path.
class FakeRecordStore implements MediaMigrationRecordStore {
  final Map<String, _FakeRow> rows = {};

  void seed(String id, String path) => rows[id] = _FakeRow(path);

  @override
  Future<List<MediaMigrationCandidate>> fetchCandidates() async {
    final out = rows.entries
        .where((e) => e.value.wrappedFek == null)
        .map(
          (e) => MediaMigrationCandidate(
            recordingId: e.key,
            plaintextPath: e.value.path,
          ),
        )
        .toList();
    out.sort((a, b) => a.recordingId.compareTo(b.recordingId));
    return out;
  }

  @override
  Future<void> markMigrated(
    String recordingId, {
    required String newPath,
    required String wrappedFekBase64,
    required String fileNoncePrefixBase64,
  }) async {
    final row = rows[recordingId]!;
    row.path = newPath;
    row.wrappedFek = wrappedFekBase64;
    row.fileNoncePrefix = fileNoncePrefixBase64;
  }

  @override
  Future<void> markRolledBack(
    String recordingId, {
    required String originalPath,
  }) async {
    final row = rows[recordingId]!;
    row.path = originalPath;
    row.wrappedFek = null;
    row.fileNoncePrefix = null;
  }
}

Uint8List _randomBytes(int length, {int seed = 1}) {
  final rng = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
}

/// Fresh 32-byte [Dek] copy each call — [Dek.wipe] zeroes ITS OWN array only,
/// so returning a brand-new `Uint8List.fromList` clone every time means
/// wiping one call's key never affects a later call's.
Future<Dek> _fixedDekSource() async =>
    Dek(Uint8List.fromList(List.filled(32, 0x5A)));

void main() {
  late Directory tmp;
  late Directory workDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_migration_test_');
    workDir = Directory('${tmp.path}/matome')..createSync(recursive: true);
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  Future<File> writePlaintext(String name, Uint8List bytes) async {
    final f = File('${workDir.path}/$name');
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<Uint8List> decryptFinal(FakeRecordStore store, String id) async {
    final manifest = await MediaMigrationManifestStore.load(
      File('${workDir.path}/$kMediaMigrationManifestFileName'),
    );
    final entry = manifest.entries[id]!;
    final dek = await _fixedDekSource();
    final bytes = <int>[];
    await for (final chunk in decryptFileStream(
      source: File(entry.finalPath),
      wrappedFek: WrappedEnvelope.fromBase64(entry.wrappedFekBase64!),
      dek: dek,
    )) {
      bytes.addAll(chunk);
    }
    dek.wipe();
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------------------
  // crash-replay — the mandatory-first fixture group.
  // ---------------------------------------------------------------------------
  group('crash-replay: interrupted migration recovers with zero data loss', () {
    test('crash right after backup (before write-new/encrypt)', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_a.m4a', _randomBytes(200003));
      store.seed('rec_a', original.path);

      var crashed = false;
      final runner1 = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
        onStepCommitted: (id, step) async {
          if (!crashed && step == MediaMigrationStep.backedUp) {
            crashed = true;
            throw _SimulatedCrash(step);
          }
        },
      );
      await expectLater(runner1.run(), throwsA(isA<_SimulatedCrash>()));

      // Crash-consistent state: original untouched, backup exists, DB row
      // still plaintext, nothing encrypted yet.
      expect(await original.exists(), isTrue);
      expect(store.rows['rec_a']!.wrappedFek, isNull);
      final backup = File(
        '${workDir.path}/$kMediaMigrationBackupDirName/rec_a.orig.bak',
      );
      expect(await backup.exists(), isTrue);

      // "process restart": fresh runner instance, no crash hook.
      final runner2 = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      final result = await runner2.run();

      expect(result.migratedRecordingIds, ['rec_a']);
      expect(await original.exists(), isFalse, reason: 'plaintext unlinked');
      expect(store.rows['rec_a']!.wrappedFek, isNotNull);
      expect(store.rows['rec_a']!.path, endsWith('rec_a.enc'));

      final roundTrip = await decryptFinal(store, 'rec_a');
      expect(roundTrip, _randomBytes(200003), reason: 'zero data loss');
    });

    test(
      'crash right after write-new is fsynced (before atomic-swap)',
      () async {
        final store = FakeRecordStore();
        final original = await writePlaintext('rec_b.m4a', _randomBytes(150001, seed: 2));
        store.seed('rec_b', original.path);

        var crashed = false;
        final runner1 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
          onStepCommitted: (id, step) async {
            if (!crashed && step == MediaMigrationStep.encrypted) {
              crashed = true;
              throw _SimulatedCrash(step);
            }
          },
        );
        await expectLater(runner1.run(), throwsA(isA<_SimulatedCrash>()));

        // tmp file exists (fsynced), final does not yet, original untouched.
        expect(await original.exists(), isTrue);
        expect(File('${workDir.path}/rec_b.enc.tmp').existsSync(), isTrue);
        expect(File('${workDir.path}/rec_b.enc').existsSync(), isFalse);

        final runner2 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        final result = await runner2.run();

        expect(result.migratedRecordingIds, ['rec_b']);
        expect(await original.exists(), isFalse);
        expect(File('${workDir.path}/rec_b.enc.tmp').existsSync(), isFalse);
        final roundTrip = await decryptFinal(store, 'rec_b');
        expect(roundTrip, _randomBytes(150001, seed: 2));
      },
    );

    test('crash right after atomic-swap (before verify)', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_c.m4a', _randomBytes(90007, seed: 3));
      store.seed('rec_c', original.path);

      var crashed = false;
      final runner1 = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
        onStepCommitted: (id, step) async {
          if (!crashed && step == MediaMigrationStep.swapped) {
            crashed = true;
            throw _SimulatedCrash(step);
          }
        },
      );
      await expectLater(runner1.run(), throwsA(isA<_SimulatedCrash>()));

      expect(File('${workDir.path}/rec_c.enc').existsSync(), isTrue);
      expect(File('${workDir.path}/rec_c.enc.tmp').existsSync(), isFalse);
      expect(await original.exists(), isTrue, reason: 'not unlinked pre-verify');
      expect(store.rows['rec_c']!.wrappedFek, isNull, reason: 'DB not yet repointed');

      final runner2 = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      final result = await runner2.run();

      expect(result.migratedRecordingIds, ['rec_c']);
      expect(await original.exists(), isFalse);
      final roundTrip = await decryptFinal(store, 'rec_c');
      expect(roundTrip, _randomBytes(90007, seed: 3));
    });

    test(
      'crash right after verify (after swap, before DB-update/unlink)',
      () async {
        final store = FakeRecordStore();
        final original = await writePlaintext('rec_d.m4a', _randomBytes(65537, seed: 4));
        store.seed('rec_d', original.path);

        var crashed = false;
        final runner1 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
          onStepCommitted: (id, step) async {
            if (!crashed && step == MediaMigrationStep.verified) {
              crashed = true;
              throw _SimulatedCrash(step);
            }
          },
        );
        await expectLater(runner1.run(), throwsA(isA<_SimulatedCrash>()));

        // Verified but not yet finished: original STILL present (the whole
        // point — never unlink before this point), DB still plaintext.
        expect(await original.exists(), isTrue);
        expect(store.rows['rec_d']!.wrappedFek, isNull);

        final runner2 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        final result = await runner2.run();

        expect(result.migratedRecordingIds, ['rec_d']);
        expect(await original.exists(), isFalse);
        expect(store.rows['rec_d']!.wrappedFek, isNotNull);
        final roundTrip = await decryptFinal(store, 'rec_d');
        expect(roundTrip, _randomBytes(65537, seed: 4));
      },
    );

    test(
      'crash at the point of no return: DB already repointed, plaintext '
      'original not yet unlinked',
      () async {
        final store = FakeRecordStore();
        final original = await writePlaintext('rec_e.m4a', _randomBytes(4096, seed: 5));
        store.seed('rec_e', original.path);

        var crashed = false;
        final runner1 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
          onAfterDbUpdateBeforeUnlink: (id) async {
            if (!crashed) {
              crashed = true;
              throw _SimulatedCrash('db-updated-not-unlinked');
            }
          },
        );
        await expectLater(runner1.run(), throwsA(isA<_SimulatedCrash>()));

        // DB already points at ciphertext, but the plaintext original is
        // still sitting on disk (harmless leftover, not data loss).
        expect(store.rows['rec_e']!.wrappedFek, isNotNull);
        expect(await original.exists(), isTrue);

        final runner2 = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        final result = await runner2.run();

        expect(result.migratedRecordingIds, ['rec_e']);
        expect(await original.exists(), isFalse, reason: 'leftover now cleaned up');
        final roundTrip = await decryptFinal(store, 'rec_e');
        expect(roundTrip, _randomBytes(4096, seed: 5));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // idempotency
  // ---------------------------------------------------------------------------
  group('idempotency', () {
    test('re-running a fully migrated set is a no-op', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_f.m4a', _randomBytes(777, seed: 6));
      store.seed('rec_f', original.path);

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      final first = await runner.run();
      expect(first.migratedRecordingIds, ['rec_f']);

      final pathBefore = store.rows['rec_f']!.path;
      final wrappedBefore = store.rows['rec_f']!.wrappedFek;

      final second = await runner.run();
      expect(second.migratedRecordingIds, isEmpty);
      expect(store.rows['rec_f']!.path, pathBefore);
      expect(store.rows['rec_f']!.wrappedFek, wrappedBefore);
    });

    test(
      'a partially migrated set (mix of done + untouched) converges on the '
      'next run',
      () async {
        final store = FakeRecordStore();
        final doneOriginal = await writePlaintext(
          'rec_g.m4a',
          _randomBytes(321, seed: 7),
        );
        final untouchedOriginal = await writePlaintext(
          'rec_h.m4a',
          _randomBytes(654, seed: 8),
        );
        store.seed('rec_g', doneOriginal.path);
        store.seed('rec_h', untouchedOriginal.path);

        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
          // Only migrate rec_g this pass (canary of 1, deterministic order).
        );
        final firstPass = await runner.run(canaryLimit: 1);
        expect(firstPass.migratedRecordingIds, ['rec_g']);
        expect(store.rows['rec_h']!.wrappedFek, isNull);
        expect(await untouchedOriginal.exists(), isTrue);

        final secondPass = await runner.run();
        expect(secondPass.migratedRecordingIds, ['rec_h']);
        expect(store.rows['rec_g']!.wrappedFek, isNotNull);
        expect(store.rows['rec_h']!.wrappedFek, isNotNull);
        expect(await doneOriginal.exists(), isFalse);
        expect(await untouchedOriginal.exists(), isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // canary
  // ---------------------------------------------------------------------------
  group('canary batch', () {
    test('canaryLimit bounds the batch to a subset', () async {
      final store = FakeRecordStore();
      for (final id in ['rec_i', 'rec_j', 'rec_k']) {
        final f = await writePlaintext('$id.m4a', _randomBytes(100, seed: id.hashCode));
        store.seed(id, f.path);
      }

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      final result = await runner.run(canaryLimit: 2);
      expect(result.migratedRecordingIds.length, 2);
      final untouched = store.rows.values.where((r) => r.wrappedFek == null);
      expect(untouched.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // dry run
  // ---------------------------------------------------------------------------
  group('dry run', () {
    test('counts candidates without touching filesystem or DB', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_l.m4a', _randomBytes(50, seed: 9));
      store.seed('rec_l', original.path);

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      final dry = await runner.dryRun();
      expect(dry.count, 1);
      expect(dry.recordingIds, ['rec_l']);

      // Nothing touched.
      expect(await original.exists(), isTrue);
      expect(store.rows['rec_l']!.wrappedFek, isNull);
      expect(
        File('${workDir.path}/$kMediaMigrationManifestFileName').existsSync(),
        isFalse,
      );
    });

    test('dryRun works even while the gate is closed', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_m.m4a', _randomBytes(50, seed: 10));
      store.seed('rec_m', original.path);

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: false,
      );
      final dry = await runner.dryRun();
      expect(dry.count, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // zero-plaintext-remaining assertion
  // ---------------------------------------------------------------------------
  group('zero-plaintext-remaining assertion', () {
    test('passes for a cleanly migrated recording', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_n.m4a', _randomBytes(999, seed: 11));
      store.seed('rec_n', original.path);

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      await runner.run();

      await expectLater(runner.assertNoPlaintextRemains(['rec_n']), completes);
    });

    test(
      'throws if a plaintext file resurfaces at the original path after '
      'migration (residual-copy bug class)',
      () async {
        final store = FakeRecordStore();
        final original = await writePlaintext('rec_o.m4a', _randomBytes(999, seed: 12));
        store.seed('rec_o', original.path);

        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        await runner.run();

        // Simulate a bug/attack that resurrected a plaintext copy at the old
        // path.
        await File(original.path).writeAsBytes(_randomBytes(10, seed: 99));

        await expectLater(
          runner.assertNoPlaintextRemains(['rec_o']),
          throwsA(isA<MediaMigrationPlaintextRemainsException>()),
        );
      },
    );

    test('throws for an id that was never migrated', () async {
      final store = FakeRecordStore();
      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      await expectLater(
        runner.assertNoPlaintextRemains(['never_migrated']),
        throwsA(isA<MediaMigrationPlaintextRemainsException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // rollback
  // ---------------------------------------------------------------------------
  group('rollback', () {
    test(
      'restores the plaintext original from backup, reverts the DB row, '
      'deletes the ciphertext, and the restored file is byte-identical + '
      'readable',
      () async {
        final store = FakeRecordStore();
        final originalBytes = _randomBytes(12345, seed: 13);
        final original = await writePlaintext('rec_p.m4a', originalBytes);
        store.seed('rec_p', original.path);

        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        await runner.run();
        expect(await original.exists(), isFalse);
        expect(store.rows['rec_p']!.wrappedFek, isNotNull);

        await runner.rollback('rec_p');

        expect(await original.exists(), isTrue);
        final restoredBytes = await original.readAsBytes();
        expect(restoredBytes, originalBytes, reason: 'byte-identical restore');
        expect(store.rows['rec_p']!.wrappedFek, isNull);
        expect(store.rows['rec_p']!.path, original.path);
        expect(File('${workDir.path}/rec_p.enc').existsSync(), isFalse);
      },
    );

    test('throws and changes nothing if no backup exists for the id', () async {
      final store = FakeRecordStore();
      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      await expectLater(
        runner.rollback('never_migrated'),
        throwsA(isA<MediaMigrationRollbackException>()),
      );
    });

    test('rollback works even while the gate is closed', () async {
      final store = FakeRecordStore();
      final originalBytes = _randomBytes(200, seed: 14);
      final original = await writePlaintext('rec_q.m4a', originalBytes);
      store.seed('rec_q', original.path);

      final openRunner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: true,
      );
      await openRunner.run();

      final closedRunner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: false,
      );
      await closedRunner.rollback('rec_q');
      expect(await original.exists(), isTrue);
      expect(await original.readAsBytes(), originalBytes);
    });
  });

  // ---------------------------------------------------------------------------
  // no best-effort swallow — the explicit contrast with `moveLegacyMediaInto`
  // ---------------------------------------------------------------------------
  group('no best-effort swallow (contrast with moveLegacyMediaInto)', () {
    test(
      'a tampered final ciphertext fails verification LOUDLY instead of '
      'being silently skipped',
      () async {
        final store = FakeRecordStore();
        final original = await writePlaintext('rec_r.m4a', _randomBytes(4321, seed: 15));
        store.seed('rec_r', original.path);

        var crashedAfterSwap = false;
        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
          onStepCommitted: (id, step) async {
            if (!crashedAfterSwap && step == MediaMigrationStep.swapped) {
              crashedAfterSwap = true;
              throw _SimulatedCrash(step);
            }
          },
        );
        await expectLater(runner.run(), throwsA(isA<_SimulatedCrash>()));

        // Tamper with the swapped-but-not-yet-verified ciphertext.
        final finalFile = File('${workDir.path}/rec_r.enc');
        final bytes = await finalFile.readAsBytes();
        bytes[bytes.length - 1] ^= 0xFF; // flip a byte in the last GCM tag
        await finalFile.writeAsBytes(bytes);

        final retryRunner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        // Propagates — never silently skipped/continued past.
        await expectLater(
          retryRunner.run(),
          throwsA(isA<MediaMigrationVerificationException>()),
        );

        // Original is STILL present — no data lost by the failed attempt.
        expect(await original.exists(), isTrue);
        expect(store.rows['rec_r']!.wrappedFek, isNull);
      },
    );

    test(
      'a missing plaintext original at the backup step propagates as '
      'MediaMigrationOriginalMissingException',
      () async {
        final store = FakeRecordStore();
        // Seed a candidate whose file was never actually written.
        store.seed('rec_s', '${workDir.path}/does_not_exist.m4a');

        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );
        await expectLater(
          runner.run(),
          throwsA(isA<MediaMigrationOriginalMissingException>()),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // gating
  // ---------------------------------------------------------------------------
  group('gating (mirrors the kMediaEncryptionEnabled dark-flag pattern)', () {
    test('run() refuses when encryptionEnabled is false', () async {
      final store = FakeRecordStore();
      final original = await writePlaintext('rec_t.m4a', _randomBytes(10, seed: 16));
      store.seed('rec_t', original.path);

      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: store,
        dekSource: _fixedDekSource,
        encryptionEnabled: false,
      );
      await expectLater(runner.run(), throwsA(isA<StateError>()));

      // Nothing touched.
      expect(await original.exists(), isTrue);
      expect(store.rows['rec_t']!.wrappedFek, isNull);
    });

    test('defaults to the real kMediaEncryptionEnabled compile flag (dark)', () {
      final runner = MediaMigrationRunner(
        workDir: workDir,
        store: FakeRecordStore(),
        dekSource: _fixedDekSource,
      );
      expect(() => runner.run(), throwsA(isA<StateError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // production wiring — real Drift AppDatabase/RecordingsDao, not the fake.
  // ---------------------------------------------------------------------------
  group('RecordingsDaoMediaMigrationStore (real Drift DB)', () {
    test(
      'migrates a real recording row end-to-end: DB columns + ciphertext '
      'file are correct, and rollback restores the row',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final originalBytes = _randomBytes(8192, seed: 17);
        final original = await writePlaintext('rec_real.m4a', originalBytes);

        await db.recordingsDao.insertLooseRecording(
          RecordingsCompanion.insert(
            id: 'rec_real',
            title: 'Real row',
            timestamp: '9:00 AM',
            duration: '0:10',
            audioFilePath: original.path,
            createdAt: 1000,
          ),
        );

        final store = RecordingsDaoMediaMigrationStore(db.recordingsDao);
        final runner = MediaMigrationRunner(
          workDir: workDir,
          store: store,
          dekSource: _fixedDekSource,
          encryptionEnabled: true,
        );

        final dry = await runner.dryRun();
        expect(dry.recordingIds, ['rec_real']);

        final result = await runner.run();
        expect(result.migratedRecordingIds, ['rec_real']);

        final row = await db.recordingsDao.getRecordingById('rec_real');
        expect(row, isNotNull);
        expect(row!.wrappedFek, isNotNull);
        expect(row.fileNoncePrefix, isNotNull);
        expect(row.audioFilePath, endsWith('rec_real.enc'));
        expect(await original.exists(), isFalse);

        final cipherFile = File(row.audioFilePath);
        expect(await cipherFile.exists(), isTrue);
        final header = await cipherFile.openRead(0, 4).expand((e) => e).toList();
        expect(header, kMediaMagic);

        await runner.rollback('rec_real');
        final revertedRow = await db.recordingsDao.getRecordingById('rec_real');
        expect(revertedRow!.wrappedFek, isNull);
        expect(revertedRow.fileNoncePrefix, isNull);
        expect(revertedRow.audioFilePath, original.path);
        expect(await File(original.path).exists(), isTrue);
        expect(await File(original.path).readAsBytes(), originalBytes);
      },
    );
  });
}
