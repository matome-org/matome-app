// Re-encrypt migration for EXISTING plaintext media — task #1856, plan #131
// W4. Highest-data-risk task in the plan: it rewrites user media files
// in-place from plaintext to ciphertext. Read this whole header before
// touching the pipeline below.
//
// ---------------------------------------------------------------------------
// WHY THIS EXISTS
// ---------------------------------------------------------------------------
// Task #1855 (`media_cipher.dart`) built the streaming per-file AEAD cipher
// and wired it into the WRITE path for brand-new imports (dark behind
// `kMediaEncryptionEnabled`). It explicitly did NOT touch pre-existing
// plaintext `import_*`/`segment_*` files already sitting on disk with a NULL
// `recordings.wrapped_fek` — see `tables.dart`'s m020 doc: "Re-encrypting
// EXISTING plaintext media is task #1856 — out of scope here." This module
// is that migration.
//
// ---------------------------------------------------------------------------
// CRASH-SAFE PER-FILE PIPELINE (the whole point of this file)
// ---------------------------------------------------------------------------
// Six durable states, persisted to a JSON manifest after EVERY transition
// (see [MediaMigrationManifestStore] — itself written via temp-file +
// atomic-rename, so the manifest can never be torn/partially written):
//
//   pending -> backedUp -> encrypted -> swapped -> verified -> done
//
//   1. pending   -> backedUp   backup-before-encrypt: copy the plaintext
//                              original to a dedicated backup dir (itself
//                              tmp+rename — see [_stepBackup]) and record its
//                              SHA-256 in the manifest.
//   2. backedUp  -> encrypted  write-new: stream-encrypt the STILL-PRESENT
//                              original into `<id>.enc.tmp` via
//                              `media_cipher.dart`'s [encryptFileToFile], then
//                              fsync it ([_fsyncPath]) before recording the
//                              wrapped FEK/nonce prefix.
//   3. encrypted -> swapped    atomic-swap: `tmp.rename(final)` — a single
//                              rename syscall on the same filesystem, atomic.
//   4. swapped   -> verified   verify checksum: decrypt the FINAL ciphertext
//                              end-to-end and compare its SHA-256 against the
//                              hash recorded at step 1. Any mismatch THROWS
//                              (never silently accepted).
//   5. verified  -> done       repoint the DB row at the ciphertext (so a
//                              crash right after this still leaves a working,
//                              VERIFIED row), THEN unlink the plaintext
//                              original, THEN record `done`.
//
// The plaintext original is NEVER deleted before step 5, and step 5 only
// runs after step 4's verification passed — i.e. "never unlink the plaintext
// original until the ciphertext is durably written AND verified" holds by
// construction, not by convention.
//
// Because every transition is (a) preceded by the actual filesystem effect
// completing (encrypt/fsync/rename) and (b) recorded atomically, RESUMING
// after a crash at ANY point is just: reload the manifest, see which step a
// recording is stuck at, and continue from there ([MediaMigrationRunner._advance]
// dispatches purely on the persisted step). A crash before step 1 ever
// commits simply restarts step 1 (harmless: the backup copy is
// tmp+rename, so a half-written backup is never mistaken for a real one).
//
// ---------------------------------------------------------------------------
// IDEMPOTENCY / RESUMABILITY
// ---------------------------------------------------------------------------
// The manifest ([MediaMigrationManifestStore], one JSON file under the
// Matome storage dir) IS the progress marker. [MediaMigrationRunner.run]:
//   - fetches candidates (rows with `wrapped_fek IS NULL` whose
//     `audio_file_path` still exists on local disk — see
//     [RecordingsDaoMediaMigrationStore.fetchCandidates]),
//   - skips any candidate whose manifest entry is already `done`,
//   - drives every other candidate through [_advance] until `done`.
// Re-running a fully migrated set is a no-op: `wrapped_fek` is no longer
// NULL for those rows, so they never even reach the candidate list again. A
// partially migrated set converges: untouched rows migrate fully, in-flight
// rows resume from their last durably-recorded step, done rows are skipped.
//
// ---------------------------------------------------------------------------
// CONTRAST WITH `moveLegacyMediaInto` (app_storage.dart) — NO SWALLOWING
// ---------------------------------------------------------------------------
// `moveLegacyMediaInto` is a best-effort, one-time file relocation that
// SWALLOWS every error (`catch (_) { return null; }`) because losing the
// relocation is harmless — the file just stays where it was. Silently
// swallowing a CRYPTO migration error is not harmless: it can strand a file
// half-migrated or, worse, hide a verification failure and let a corrupted
// ciphertext become the row's only reference. Every exception type below
// ([MediaMigrationException] and subtypes) is allowed to propagate all the
// way out of [MediaMigrationRunner.run] — there is no catch-and-continue
// anywhere in this file. A failing file halts the run; the manifest already
// captured everything durable up to that point, so a fixed retry resumes
// cleanly instead of silently missing files.
//
// ---------------------------------------------------------------------------
// CANARY + GATING
// ---------------------------------------------------------------------------
// [MediaMigrationRunner.run] takes an optional `canaryLimit` — a bounded
// batch instead of "migrate everything on first boot". [MediaMigrationRunner]
// also refuses to run at all while `kMediaEncryptionEnabled` is dark (mirrors
// the exact dark-flag discipline `media_cipher.dart`/`inbox_upload.dart`
// established): [dryRun] (read-only, safe) and [rollback] (a safety valve)
// are NOT gated — only the mutating forward migration is.
//
// ---------------------------------------------------------------------------
// HONEST LIMIT (documented, not solved)
// ---------------------------------------------------------------------------
// Unlinking the plaintext original removes the FILE SYSTEM's reference to
// it, but on SSD/flash media the underlying physical blocks are not
// overwritten synchronously (wear-leveling, TRIM is asynchronous/best-effort,
// and the OS/filesystem layer this app runs above gives no portable
// "secure-erase a file" primitive). A plaintext remnant of the original bytes
// MAY persist in free blocks until the device reclaims/overwrites them. This
// migration deletes the file through the normal OS `unlink` call — it does
// NOT attempt disk-level secure erase, and no fix is attempted here. This is
// a known, accepted limit, not an oversight.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart' show Digest, sha256;

import 'envelope.dart' show WrappedEnvelope;
import 'key_material.dart' show Dek;
import 'media_cipher.dart'
    show
        EncryptedMediaResult,
        MediaCipherException,
        decryptFileStream,
        encodeNoncePrefix,
        encryptFileToFile,
        kMediaEncryptionEnabled,
        kMediaMagic,
        kMediaMagicLength;

/// Manifest JSON file name, created directly under the Matome storage dir.
const String kMediaMigrationManifestFileName = 'media_migration_manifest.json';

/// Backup directory name, directly under the Matome storage dir. Holds one
/// `<recordingId>.orig.bak` per in-flight/completed migration — the ONLY
/// rollback path (§ Rollback below).
const String kMediaMigrationBackupDirName = '.media_migration_backups';

/// The six durable states a single recording's migration passes through, in
/// order. See the module doc "CRASH-SAFE PER-FILE PIPELINE" for what each
/// transition durably guarantees before it is recorded.
enum MediaMigrationStep { pending, backedUp, encrypted, swapped, verified, done }

// ---------------------------------------------------------------------------
// Exceptions — every one of these is allowed to propagate (see module doc
// "NO SWALLOWING"). None is ever caught-and-ignored inside this file.
// ---------------------------------------------------------------------------

abstract class MediaMigrationException implements Exception {
  const MediaMigrationException();
}

/// The plaintext original vanished from disk before the backup step could
/// copy it (or, if it reappears missing at the encrypt step, which should be
/// impossible under this pipeline's own invariants — surfaced loudly either
/// way rather than silently skipping the file).
class MediaMigrationOriginalMissingException extends MediaMigrationException {
  final String recordingId;
  const MediaMigrationOriginalMissingException(this.recordingId);

  @override
  String toString() =>
      'MediaMigrationOriginalMissingException: plaintext original missing '
      'for recording $recordingId before it could be backed up/re-read';
}

/// Neither the `.enc.tmp` nor the final `.enc` ciphertext exists where the
/// manifest says the swap step should find one. This is NOT a normal crash
/// point this pipeline produces on its own (the tmp file is fsynced and
/// recorded durably before this step ever runs) — it signals external
/// interference (e.g. something else deleted the tmp file), so it is
/// reported explicitly rather than silently re-encrypted.
class MediaMigrationMissingArtifactException extends MediaMigrationException {
  final String recordingId;
  final String reason;
  const MediaMigrationMissingArtifactException(this.recordingId, this.reason);

  @override
  String toString() =>
      'MediaMigrationMissingArtifactException: $recordingId: $reason';
}

/// Decrypting the final ciphertext and re-hashing it did NOT match the
/// SHA-256 recorded at the backup step. The plaintext original is still
/// present at this point (never unlinked before verification passes), so no
/// data is lost — the run simply halts instead of unlinking a file this
/// migration cannot prove round-trips correctly.
class MediaMigrationVerificationException extends MediaMigrationException {
  final String recordingId;
  const MediaMigrationVerificationException(this.recordingId);

  @override
  String toString() =>
      'MediaMigrationVerificationException: post-swap decrypt hash mismatch '
      'for recording $recordingId — halting before unlink';
}

/// [MediaMigrationRunner.rollback] was asked to restore a recording with no
/// manifest entry, a missing backup, or a backup whose bytes fail to match
/// the recorded plaintext hash.
class MediaMigrationRollbackException extends MediaMigrationException {
  final String recordingId;
  final String reason;
  const MediaMigrationRollbackException(this.recordingId, this.reason);

  @override
  String toString() => 'MediaMigrationRollbackException: $recordingId: $reason';
}

/// [MediaMigrationRunner.assertNoPlaintextRemains] found a recording that is
/// not fully migrated, still has a readable plaintext original, or whose
/// "ciphertext" file does not even start with the media-cipher magic header
/// (a residual-plaintext-copy bug class this check exists to catch).
class MediaMigrationPlaintextRemainsException extends MediaMigrationException {
  final String recordingId;
  final String path;
  const MediaMigrationPlaintextRemainsException(this.recordingId, this.path);

  @override
  String toString() =>
      'MediaMigrationPlaintextRemainsException: $recordingId at $path';
}

// ---------------------------------------------------------------------------
// Manifest entry + persistence
// ---------------------------------------------------------------------------

/// One recording's migration progress record — the unit persisted by
/// [MediaMigrationManifestStore].
class MediaMigrationEntry {
  const MediaMigrationEntry({
    required this.recordingId,
    required this.step,
    required this.originalPath,
    required this.backupPath,
    required this.tmpPath,
    required this.finalPath,
    this.plaintextSha256Base64,
    this.wrappedFekBase64,
    this.fileNoncePrefixBase64,
  });

  final String recordingId;
  final MediaMigrationStep step;

  /// The plaintext file's path at the time migration started for this row.
  final String originalPath;
  final String backupPath;
  final String tmpPath;
  final String finalPath;

  /// SHA-256 of the plaintext original, base64, recorded at the backup step
  /// — the ground truth [MediaMigrationRunner] verifies the ciphertext
  /// against after the atomic swap.
  final String? plaintextSha256Base64;
  final String? wrappedFekBase64;
  final String? fileNoncePrefixBase64;

  MediaMigrationEntry copyWith({
    MediaMigrationStep? step,
    String? plaintextSha256Base64,
    String? wrappedFekBase64,
    String? fileNoncePrefixBase64,
  }) {
    return MediaMigrationEntry(
      recordingId: recordingId,
      step: step ?? this.step,
      originalPath: originalPath,
      backupPath: backupPath,
      tmpPath: tmpPath,
      finalPath: finalPath,
      plaintextSha256Base64: plaintextSha256Base64 ?? this.plaintextSha256Base64,
      wrappedFekBase64: wrappedFekBase64 ?? this.wrappedFekBase64,
      fileNoncePrefixBase64: fileNoncePrefixBase64 ?? this.fileNoncePrefixBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'recordingId': recordingId,
    'step': step.name,
    'originalPath': originalPath,
    'backupPath': backupPath,
    'tmpPath': tmpPath,
    'finalPath': finalPath,
    'plaintextSha256Base64': plaintextSha256Base64,
    'wrappedFekBase64': wrappedFekBase64,
    'fileNoncePrefixBase64': fileNoncePrefixBase64,
  };

  factory MediaMigrationEntry.fromJson(Map<String, dynamic> json) {
    return MediaMigrationEntry(
      recordingId: json['recordingId'] as String,
      step: MediaMigrationStep.values.byName(json['step'] as String),
      originalPath: json['originalPath'] as String,
      backupPath: json['backupPath'] as String,
      tmpPath: json['tmpPath'] as String,
      finalPath: json['finalPath'] as String,
      plaintextSha256Base64: json['plaintextSha256Base64'] as String?,
      wrappedFekBase64: json['wrappedFekBase64'] as String?,
      fileNoncePrefixBase64: json['fileNoncePrefixBase64'] as String?,
    );
  }
}

/// Loads/saves the migration manifest as ONE JSON file, written via
/// temp-file + atomic rename ([_saveAtomic]) so a crash mid-write leaves
/// either the complete PREVIOUS manifest or the complete NEW one — never a
/// torn file. This is the "progress marker" the whole resumability story
/// depends on: [MediaMigrationRunner] reloads it fresh on every [run] call.
class MediaMigrationManifestStore {
  MediaMigrationManifestStore(this.file);

  final File file;
  Map<String, MediaMigrationEntry> _entries = {};

  /// Read-only snapshot of every recording's progress.
  Map<String, MediaMigrationEntry> get entries => Map.unmodifiable(_entries);

  static Future<MediaMigrationManifestStore> load(File file) async {
    final store = MediaMigrationManifestStore(file);
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        store._entries = decoded.map(
          (key, value) => MapEntry(
            key,
            MediaMigrationEntry.fromJson(value as Map<String, dynamic>),
          ),
        );
      }
    }
    return store;
  }

  Future<void> put(MediaMigrationEntry entry) async {
    _entries[entry.recordingId] = entry;
    await _saveAtomic();
  }

  Future<void> remove(String recordingId) async {
    _entries.remove(recordingId);
    await _saveAtomic();
  }

  Future<void> _saveAtomic() async {
    final tmp = File('${file.path}.tmp');
    final encoded = jsonEncode(_entries.map((k, v) => MapEntry(k, v.toJson())));
    await tmp.writeAsString(encoded, flush: true);
    await _fsyncPath(tmp.path);
    await tmp.rename(file.path);
  }
}

// ---------------------------------------------------------------------------
// Candidate row + the DB-facing seam (kept abstract so this module is
// unit-testable without a real Drift database; [RecordingsDaoMediaMigrationStore]
// below is the real production adapter).
// ---------------------------------------------------------------------------

class MediaMigrationCandidate {
  const MediaMigrationCandidate({
    required this.recordingId,
    required this.plaintextPath,
  });

  final String recordingId;
  final String plaintextPath;
}

/// The DB-facing seam this migration needs: find candidates, and the two
/// writes a migration/rollback performs on a recording's row.
abstract class MediaMigrationRecordStore {
  /// Every recording whose `wrapped_fek` is NULL (i.e. `audio_file_path`
  /// names a PLAINTEXT file) AND whose file still exists locally. Ordered
  /// deterministically (by [MediaMigrationCandidate.recordingId]) so a
  /// `canaryLimit` bound is stable across runs.
  Future<List<MediaMigrationCandidate>> fetchCandidates();

  /// Repoints the row at the migrated ciphertext + wrap metadata. Called
  /// AFTER verification passes, BEFORE the plaintext original is unlinked.
  Future<void> markMigrated(
    String recordingId, {
    required String newPath,
    required String wrappedFekBase64,
    required String fileNoncePrefixBase64,
  });

  /// Reverts the row to its pre-migration (plaintext) shape. Called by
  /// [MediaMigrationRunner.rollback].
  Future<void> markRolledBack(String recordingId, {required String originalPath});
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class MediaMigrationDryRunResult {
  const MediaMigrationDryRunResult(this.recordingIds);
  final List<String> recordingIds;
  int get count => recordingIds.length;
}

class MediaMigrationRunResult {
  const MediaMigrationRunResult({
    required this.migratedRecordingIds,
    required this.alreadyDoneRecordingIds,
  });
  final List<String> migratedRecordingIds;
  final List<String> alreadyDoneRecordingIds;
}

// ---------------------------------------------------------------------------
// The runner
// ---------------------------------------------------------------------------

/// Drives the crash-safe per-file pipeline (module doc) across every
/// candidate recording, bounded by an optional canary [run]-time limit.
///
/// Gated: [run] refuses outright unless `encryptionEnabled` (defaulting to
/// the real [kMediaEncryptionEnabled] compile flag) is `true` — mirrors the
/// exact dark-flag discipline `media_cipher.dart`/`inbox_upload.dart`
/// established, so this migration cannot accidentally fire in a production
/// build before the Core Blobs API + consent flow it depends on exists. The
/// constructor parameter exists so tests can exercise the real pipeline
/// without a `--dart-define` build flip; [dryRun] and [rollback] are NOT
/// gated (read-only / safety-valve, respectively).
class MediaMigrationRunner {
  MediaMigrationRunner({
    required Directory workDir,
    required MediaMigrationRecordStore store,
    required Future<Dek> Function() dekSource,
    bool encryptionEnabled = kMediaEncryptionEnabled,
    // Test-only fault-injection hook: invoked right after each manifest
    // transition durably commits, so a test can throw at that exact point to
    // simulate "the process was killed the instant this step became durable"
    // and then verify a fresh [MediaMigrationRunner] resumes correctly. Never
    // set in production call sites.
    Future<void> Function(String recordingId, MediaMigrationStep committedStep)?
    onStepCommitted,
    // Test-only fault-injection hook: invoked right after [markMigrated]
    // durably repoints the DB row, before the plaintext original is
    // unlinked — lets a test simulate a crash at that exact "point of no
    // return" boundary. Never set in production call sites.
    Future<void> Function(String recordingId)? onAfterDbUpdateBeforeUnlink,
  }) : _workDir = workDir,
       _manifestFile = File('${workDir.path}/$kMediaMigrationManifestFileName'),
       _backupDir = Directory('${workDir.path}/$kMediaMigrationBackupDirName'),
       _store = store,
       _dekSource = dekSource,
       _encryptionEnabled = encryptionEnabled,
       _onStepCommitted = onStepCommitted ?? _noopStepHook,
       _onAfterDbUpdateBeforeUnlink =
           onAfterDbUpdateBeforeUnlink ?? _noopIdHook;

  final Directory _workDir;
  final File _manifestFile;
  final Directory _backupDir;
  final MediaMigrationRecordStore _store;
  final Future<Dek> Function() _dekSource;
  final bool _encryptionEnabled;
  final Future<void> Function(String, MediaMigrationStep) _onStepCommitted;
  final Future<void> Function(String) _onAfterDbUpdateBeforeUnlink;

  static Future<void> _noopStepHook(String _, MediaMigrationStep _) async {}
  static Future<void> _noopIdHook(String _) async {}

  void _assertGateOpen() {
    if (!_encryptionEnabled) {
      throw StateError(
        'MediaMigrationRunner.run() refused: kMediaEncryptionEnabled is dark '
        'for this build. The pipeline is real and tested (task #1856) but '
        'must not auto-run in production until the Core Blobs API + '
        'opt-in cloud-transcription consent gate this depends on ships '
        '(see media_cipher.dart kMediaEncryptionEnabled doc). Construct with '
        '`encryptionEnabled: true` explicitly once that gate is ready — this '
        'is never flipped implicitly.',
      );
    }
  }

  /// Read-only: counts what [run] would migrate, touching neither the
  /// filesystem nor the DB. Safe to call regardless of the gate.
  Future<MediaMigrationDryRunResult> dryRun() async {
    final candidates = await _store.fetchCandidates();
    return MediaMigrationDryRunResult(
      candidates.map((c) => c.recordingId).toList(),
    );
  }

  /// Migrates every candidate (or the first [canaryLimit] of them, for a
  /// bounded canary batch) through the crash-safe pipeline. Resumable: a
  /// candidate already at `done` in the manifest is skipped (belt-and-
  /// suspenders — the candidate query itself already excludes migrated rows
  /// since their `wrapped_fek` is no longer NULL).
  Future<MediaMigrationRunResult> run({int? canaryLimit}) async {
    _assertGateOpen();
    await _backupDir.create(recursive: true);
    final manifest = await MediaMigrationManifestStore.load(_manifestFile);

    // IN-FLIGHT FIRST: any manifest entry not yet `done` must be resumed
    // regardless of whether its row still looks like a fresh candidate. A
    // crash between the DB update and the unlink (step 5) already set
    // `wrapped_fek` on the row, so it would otherwise silently drop out of
    // `fetchCandidates()` (which selects on `wrapped_fek IS NULL`) forever,
    // stranding its pending unlink + manifest close-out.
    final inFlight = manifest.entries.values
        .where((e) => e.step != MediaMigrationStep.done)
        .map(
          (e) => MediaMigrationCandidate(
            recordingId: e.recordingId,
            plaintextPath: e.originalPath,
          ),
        )
        .toList();
    final inFlightIds = {for (final c in inFlight) c.recordingId};

    final fresh = await _store.fetchCandidates();
    final freshOnly = fresh
        .where((c) => !inFlightIds.contains(c.recordingId))
        .toList();

    final combined = [...inFlight, ...freshOnly];
    final bounded =
        canaryLimit == null ? combined : combined.take(canaryLimit).toList();

    final migrated = <String>[];
    final alreadyDone = <String>[];
    for (final candidate in bounded) {
      final existing = manifest.entries[candidate.recordingId];
      if (existing != null && existing.step == MediaMigrationStep.done) {
        alreadyDone.add(candidate.recordingId);
        continue;
      }
      await _migrateOne(candidate, manifest);
      migrated.add(candidate.recordingId);
    }
    return MediaMigrationRunResult(
      migratedRecordingIds: migrated,
      alreadyDoneRecordingIds: alreadyDone,
    );
  }

  Future<void> _migrateOne(
    MediaMigrationCandidate candidate,
    MediaMigrationManifestStore manifest,
  ) async {
    final backupFile = File(
      '${_backupDir.path}/${candidate.recordingId}.orig.bak',
    );
    final finalFile = File('${_workDir.path}/${candidate.recordingId}.enc');
    final tmpFile = File('${finalFile.path}.tmp');

    var entry =
        manifest.entries[candidate.recordingId] ??
        MediaMigrationEntry(
          recordingId: candidate.recordingId,
          step: MediaMigrationStep.pending,
          originalPath: candidate.plaintextPath,
          backupPath: backupFile.path,
          tmpPath: tmpFile.path,
          finalPath: finalFile.path,
        );

    while (entry.step != MediaMigrationStep.done) {
      entry = await _advance(entry, candidate);
      await manifest.put(entry);
      await _onStepCommitted(candidate.recordingId, entry.step);
    }
  }

  Future<MediaMigrationEntry> _advance(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) {
    switch (entry.step) {
      case MediaMigrationStep.pending:
        return _stepBackup(entry, candidate);
      case MediaMigrationStep.backedUp:
        return _stepEncrypt(entry, candidate);
      case MediaMigrationStep.encrypted:
        return _stepSwap(entry, candidate);
      case MediaMigrationStep.swapped:
        return _stepVerify(entry, candidate);
      case MediaMigrationStep.verified:
        return _stepFinish(entry, candidate);
      case MediaMigrationStep.done:
        return Future.value(entry);
    }
  }

  /// Step 1 — backup-before-encrypt. Always re-copies via temp+rename (never
  /// trusts a pre-existing backup file blindly — a crash mid-copy on a prior
  /// attempt must not be mistaken for a complete backup).
  Future<MediaMigrationEntry> _stepBackup(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) async {
    final originalFile = File(candidate.plaintextPath);
    if (!await originalFile.exists()) {
      throw MediaMigrationOriginalMissingException(candidate.recordingId);
    }
    final backupFile = File(entry.backupPath);
    final backupTmp = File('${backupFile.path}.tmp');
    await originalFile.copy(backupTmp.path);
    await _fsyncPath(backupTmp.path);
    await backupTmp.rename(backupFile.path);

    final plaintextHash = await _sha256OfFile(originalFile);
    return entry.copyWith(
      step: MediaMigrationStep.backedUp,
      plaintextSha256Base64: base64.encode(plaintextHash),
    );
  }

  /// Step 2 — write-new: stream-encrypt the STILL-PRESENT original into
  /// `<id>.enc.tmp`, then fsync it. [encryptFileToFile]'s destination sink
  /// opens in (truncating) write mode, so re-running this step after a crash
  /// mid-encrypt safely overwrites any partial tmp file from before.
  Future<MediaMigrationEntry> _stepEncrypt(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) async {
    final originalFile = File(candidate.plaintextPath);
    if (!await originalFile.exists()) {
      // Should be impossible under this pipeline's own invariants (the
      // original is untouched until step 5) — surfaced loudly rather than
      // silently trusting the backup copy instead.
      throw MediaMigrationOriginalMissingException(candidate.recordingId);
    }
    final tmpFile = File(entry.tmpPath);
    final dek = await _dekSource();
    final EncryptedMediaResult result;
    try {
      result = await encryptFileToFile(
        source: originalFile,
        destination: tmpFile,
        dek: dek,
      );
    } finally {
      dek.wipe();
    }
    await _fsyncPath(tmpFile.path);
    return entry.copyWith(
      step: MediaMigrationStep.encrypted,
      wrappedFekBase64: result.wrappedFek.toBase64(),
      fileNoncePrefixBase64: encodeNoncePrefix(result.noncePrefix),
    );
  }

  /// Step 3 — atomic-swap. Tolerates resuming exactly at the instant the
  /// rename succeeded but the manifest write recording it did not (final
  /// already present); otherwise requires the fsynced tmp file to still be
  /// there (guaranteed by step 2 having committed durably) and renames it.
  Future<MediaMigrationEntry> _stepSwap(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) async {
    final tmpFile = File(entry.tmpPath);
    final finalFile = File(entry.finalPath);
    if (await finalFile.exists()) {
      // Rename already happened in a prior attempt; only the manifest update
      // recording it was lost to the crash.
    } else if (await tmpFile.exists()) {
      await tmpFile.rename(finalFile.path);
    } else {
      throw MediaMigrationMissingArtifactException(
        candidate.recordingId,
        'neither tmp nor final ciphertext present at the swap step',
      );
    }
    return entry.copyWith(step: MediaMigrationStep.swapped);
  }

  /// Step 4 — verify checksum: decrypt the FINAL ciphertext end-to-end and
  /// compare its SHA-256 against the hash recorded at the backup step.
  /// Throws (never silently accepts) on any mismatch OR on the ciphertext
  /// failing to decrypt at all (a per-chunk AEAD tamper failure from
  /// `media_cipher.dart` is itself a verification failure at this layer, so
  /// it is normalized to [MediaMigrationVerificationException] rather than
  /// leaking a lower-level cipher exception type — still fully propagated,
  /// never swallowed).
  Future<MediaMigrationEntry> _stepVerify(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) async {
    final finalFile = File(entry.finalPath);
    final dek = await _dekSource();
    final Uint8List actual;
    try {
      try {
        actual = await _sha256OfStream(
          decryptFileStream(
            source: finalFile,
            wrappedFek: WrappedEnvelope.fromBase64(entry.wrappedFekBase64!),
            dek: dek,
          ),
        );
      } on MediaCipherException {
        throw MediaMigrationVerificationException(candidate.recordingId);
      }
    } finally {
      dek.wipe();
    }
    final expected = base64.decode(entry.plaintextSha256Base64!);
    if (!_constantTimeEquals(actual, Uint8List.fromList(expected))) {
      throw MediaMigrationVerificationException(candidate.recordingId);
    }
    return entry.copyWith(step: MediaMigrationStep.verified);
  }

  /// Step 5 — repoint the DB row at the ciphertext FIRST (a crash right
  /// after this still leaves a working, VERIFIED row + a harmless leftover
  /// plaintext file that the next resume simply unlinks), THEN unlink the
  /// plaintext original, THEN mark `done`.
  Future<MediaMigrationEntry> _stepFinish(
    MediaMigrationEntry entry,
    MediaMigrationCandidate candidate,
  ) async {
    await _store.markMigrated(
      candidate.recordingId,
      newPath: entry.finalPath,
      wrappedFekBase64: entry.wrappedFekBase64!,
      fileNoncePrefixBase64: entry.fileNoncePrefixBase64!,
    );
    await _onAfterDbUpdateBeforeUnlink(candidate.recordingId);
    final originalFile = File(entry.originalPath);
    if (await originalFile.exists()) {
      await originalFile.delete();
    }
    return entry.copyWith(step: MediaMigrationStep.done);
  }

  /// Restores [recordingId]'s plaintext original from its backup, reverts
  /// the DB row, and deletes the ciphertext + any leftover tmp file.
  /// Verifies the restored bytes against the recorded plaintext hash before
  /// touching the DB — a corrupt/mismatched backup aborts loudly instead of
  /// "restoring" garbage. NOT gated by `encryptionEnabled`: reversing a
  /// migration must always be possible.
  Future<void> rollback(String recordingId) async {
    final manifest = await MediaMigrationManifestStore.load(_manifestFile);
    final entry = manifest.entries[recordingId];
    if (entry == null) {
      throw MediaMigrationRollbackException(
        recordingId,
        'no migration record — nothing to roll back',
      );
    }
    final backupFile = File(entry.backupPath);
    if (!await backupFile.exists()) {
      throw MediaMigrationRollbackException(recordingId, 'backup file missing');
    }

    final restoredFile = File(entry.originalPath);
    final restoreTmp = File('${restoredFile.path}.rollback.tmp');
    await backupFile.copy(restoreTmp.path);
    await _fsyncPath(restoreTmp.path);

    final expectedHashBase64 = entry.plaintextSha256Base64;
    if (expectedHashBase64 != null) {
      final actual = await _sha256OfFile(restoreTmp);
      final expected = Uint8List.fromList(base64.decode(expectedHashBase64));
      if (!_constantTimeEquals(actual, expected)) {
        await restoreTmp.delete();
        throw MediaMigrationRollbackException(
          recordingId,
          'restored bytes do not match the recorded plaintext hash — backup '
          'may be corrupt; refusing to overwrite',
        );
      }
    }
    await restoreTmp.rename(restoredFile.path);

    await _store.markRolledBack(recordingId, originalPath: entry.originalPath);

    final finalFile = File(entry.finalPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    final tmpFile = File(entry.tmpPath);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    await manifest.remove(recordingId);
  }

  /// Post-run assertion: for every id in [recordingIds], the manifest must
  /// show `done`, the plaintext original must be GONE from disk, and the
  /// ciphertext file must start with the media-cipher magic header (a cheap
  /// structural plaintext-scan — catches the bug class where a plaintext
  /// copy is left behind under the `.enc` name instead of real ciphertext).
  /// Throws [MediaMigrationPlaintextRemainsException] on the first
  /// violation found.
  Future<void> assertNoPlaintextRemains(Iterable<String> recordingIds) async {
    final manifest = await MediaMigrationManifestStore.load(_manifestFile);
    for (final id in recordingIds) {
      final entry = manifest.entries[id];
      if (entry == null || entry.step != MediaMigrationStep.done) {
        throw MediaMigrationPlaintextRemainsException(id, '(not fully migrated)');
      }
      if (await File(entry.originalPath).exists()) {
        throw MediaMigrationPlaintextRemainsException(id, entry.originalPath);
      }
      final finalFile = File(entry.finalPath);
      if (!await finalFile.exists()) {
        throw MediaMigrationPlaintextRemainsException(id, entry.finalPath);
      }
      final header = await _readHeaderBytes(finalFile, kMediaMagicLength);
      final magic = Uint8List.fromList(kMediaMagic);
      if (header.length != kMediaMagicLength ||
          !_constantTimeEquals(Uint8List.fromList(header), magic)) {
        throw MediaMigrationPlaintextRemainsException(id, entry.finalPath);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Small file/hash helpers
// ---------------------------------------------------------------------------

/// Forces the OS to durably persist [path]'s contents (fsync/FlushFileBuffers
/// equivalent) — `RandomAccessFile.flush()` per the dart:io contract. Opened
/// in append mode purely so nothing is truncated/overwritten; no bytes are
/// written by this call.
Future<void> _fsyncPath(String path) async {
  final raf = await File(path).open(mode: FileMode.append);
  try {
    await raf.flush();
  } finally {
    await raf.close();
  }
}

Future<Uint8List> _sha256OfFile(File file) => _sha256OfStream(file.openRead());

/// Incremental (streaming) SHA-256 — `sha256.startChunkedConversion` hashes
/// chunk-by-chunk with O(1) memory, matching `media_cipher.dart`'s own
/// never-buffer-the-whole-file discipline instead of reading the whole file
/// into one buffer first.
Future<Uint8List> _sha256OfStream(Stream<List<int>> stream) async {
  final output = AccumulatorSink<Digest>();
  final input = sha256.startChunkedConversion(output);
  await for (final chunk in stream) {
    input.add(chunk);
  }
  input.close();
  return Uint8List.fromList(output.events.single.bytes);
}

Future<List<int>> _readHeaderBytes(File file, int length) async {
  final raf = await file.open();
  try {
    return await raf.read(length);
  } finally {
    await raf.close();
  }
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
