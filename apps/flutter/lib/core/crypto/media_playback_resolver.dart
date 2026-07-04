// Playback SOURCE-RESOLUTION seam for encrypted media — task #1866
// (okt-audit media-read warning, pinned aggregate verdict on #1857).
//
// THE GAP THIS CLOSES: `inbox_upload.dart` already writes encrypted media
// (`.enc` + wrapped FEK, under `kMediaEncryptionEnabled`) and
// `media_cipher.dart` already has `decryptFileStream`/`decryptToFile` — but
// nothing on the READ side ever called them. Every playback caller (the
// Details screen's audio source resolution) opened the recording's stored
// path directly as a plaintext file; only `media_migration.dart`'s ROLLBACK
// path (a one-shot restore, not playback) ever decrypted anything. Flipping
// `kMediaEncryptionEnabled` on today, with no read-side change, would make
// every newly-imported recording open as undecodable ciphertext the instant
// a player tried to read it — permanently unplayable, not just briefly
// broken.
//
// THE SEAM: gate strictly on whether the recording's `wrapped_fek` column is
// non-null (mirrors `RecordingsDaoMediaMigrationStore.fetchCandidates`'s
// identical gate on the write/migration side):
//   wrappedFekBase64 == null -> passthrough. Returns [sourcePath] unchanged
//                               — byte-identical to the pre-#1866 behavior,
//                               so this is a no-op for every recording until
//                               the write flag actually flips.
//   wrappedFekBase64 != null -> decrypt-to-scratch-file FIRST. The raw
//                               ciphertext path is never handed back to a
//                               caller that expects a playable file.
//
// KNOWN TRADE-OFF (same one `media_cipher.dart`'s `decryptToFile` doc already
// flags): the decrypted scratch file is transiently PLAINTEXT on disk for
// the player's use. Callers MUST point [PlaybackScratchDirSource] at a
// private cache/temp directory, never the durable Matome storage folder.
//
// REMAINING WIRING (flagged, not silently swallowed — AC allows shipping the
// resolution function + test alone when full player integration is large):
//   * `details_controller.dart`'s `_resolveAudioSource` calls this function
//     directly (see that file) using the SAME `NativeDekProvisioner
//     (FlutterSecureKeyStore.deviceKek()).obtainDek()` dekSource
//     `inbox_upload.dart` already uses for the write side, so a real DEK is
//     available the moment `kMediaEncryptionEnabled` flips on.
//
// SCRATCH-FILE LIFECYCLE (task #1867, okt-audit PASS-2 FINDING-1 — closes the
// gap the comment above used to accept): a decrypted scratch file is no
// longer left to accumulate forever. Three eviction points, all in this file
// so there is exactly one place that knows the `<recordingId>.playback`
// naming scheme:
//   * A FAILED decrypt (tamper, wrong/rotated DEK, malformed envelope, ...)
//     now unlinks whatever `decryptToFile` left behind (even a zero-byte
//     stray — `File.openWrite()` creates the file the instant it is opened,
//     before any bytes are written) before the exception propagates. See the
//     try/catch in [resolvePlaybackPath] below.
//   * [evictPlaybackScratch] deletes ONE recording's scratch file — wired to
//     `DetailsController.dispose()` (screen closed == this app's "player
//     stopped" boundary, since `AudioPlayerBar` only exists while its owning
//     Details screen is mounted).
//   * [evictAllPlaybackScratch] wipes the WHOLE cache directory — wired to
//     `AuthController.logout()` (and the forced-signout path), the session
//     boundary that stands in for "account-switch" until this app grows a
//     real multi-account feature (there is none today — grepped, confirmed).
import 'dart:io';

import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

import 'envelope.dart' show WrappedEnvelope;
import 'key_material.dart' show Dek;
import 'media_cipher.dart' show decryptToFile;

/// Supplies the private cache/temp directory decrypted scratch files should
/// live under. Injectable (mirrors `inbox_upload.dart`'s `dekSource` pattern)
/// so this module is unit-testable without a `path_provider` platform
/// channel; real callers wire this to `getTemporaryDirectory()` (or a
/// dedicated subdirectory under it).
typedef PlaybackScratchDirSource = Future<Directory> Function();

/// The real, production [PlaybackScratchDirSource]: a dedicated subdirectory
/// of the OS-managed temp/cache area. Shared by every real caller
/// (`DetailsController`'s default, `AuthController.logout()`'s full-cache
/// sweep) so there is one canonical answer to "where do playback scratch
/// files live" — never duplicated as a string literal a second time.
Future<Directory> defaultPlaybackScratchDir() async {
  final tmp = await getTemporaryDirectory();
  return Directory('${tmp.path}/matome_playback_cache');
}

/// Resolves the on-disk path a player should actually open for a recording
/// whose stored media path is [sourcePath].
///
/// * [wrappedFekBase64] `null` — the file is plaintext (today's exact
///   behavior): returns [sourcePath] unmodified. Neither [dekSource] nor
///   [scratchDirSource] is invoked in this branch.
/// * [wrappedFekBase64] non-null — the file is `media_cipher.dart`
///   ciphertext: unwraps the FEK via [dekSource], decrypts (streaming, via
///   [decryptToFile]) into `<scratchDir>/<recordingId>.playback`, and returns
///   THAT path. A repeat call for the same [recordingId] overwrites the same
///   scratch file rather than accumulating one per resolution.
///
/// The returned [Dek] from [dekSource] is wiped before this function returns,
/// win or lose — mirrors every other DEK consumer in this codebase
/// (`inbox_upload.dart`'s `encryptedDurableImportCopy`,
/// `media_migration.dart`'s per-step decrypt/encrypt calls).
Future<String> resolvePlaybackPath({
  required String recordingId,
  required String sourcePath,
  required String? wrappedFekBase64,
  required Future<Dek> Function() dekSource,
  required PlaybackScratchDirSource scratchDirSource,
}) async {
  if (wrappedFekBase64 == null) {
    return sourcePath;
  }

  final wrapped = WrappedEnvelope.fromBase64(wrappedFekBase64);
  final scratchDir = await scratchDirSource();
  if (!await scratchDir.exists()) {
    await scratchDir.create(recursive: true);
  }
  final destination = File('${scratchDir.path}/$recordingId.playback');

  final dek = await dekSource();
  try {
    final decrypted = await decryptToFile(
      source: File(sourcePath),
      wrappedFek: wrapped,
      dek: dek,
      destination: destination,
    );
    return decrypted.path;
  } catch (_) {
    // okt-audit PASS-2 FINDING-1 (secondary): a failed decrypt must not
    // leave a partial — or even zero-byte — plaintext scratch file behind.
    // `decryptToFile`'s own `finally` already closed the sink by the time
    // this catch runs, so it is safe to unlink here. Best-effort: if the
    // delete itself fails (e.g. permission), the original decrypt error is
    // still what the caller sees — never mask it with a cleanup failure.
    try {
      if (await destination.exists()) {
        await destination.delete();
      }
    } catch (_) {
      // Swallow — surfacing the ORIGINAL decrypt failure below is what
      // matters; a stray scratch file we couldn't remove is a secondary
      // concern already logged by the caller (`details_controller.dart`).
    }
    rethrow;
  } finally {
    dek.wipe();
  }
}

/// Deletes the private scratch file for [recordingId] if one exists.
/// Idempotent — a missing file (already evicted, or never resolved) is not
/// an error. Wired to `DetailsController.dispose()` so no plaintext survives
/// past the lifetime of the screen/player that needed it (okt-audit PASS-2
/// FINDING-1).
Future<void> evictPlaybackScratch({
  required String recordingId,
  required PlaybackScratchDirSource scratchDirSource,
}) async {
  final scratchDir = await scratchDirSource();
  final file = File('${scratchDir.path}/$recordingId.playback');
  if (await file.exists()) {
    await file.delete();
  }
}

/// Deletes the ENTIRE playback scratch cache directory — every recording's
/// decrypted scratch file, not just one. Wired to session-boundary events
/// (`AuthController.logout()` / forced signout) so no decrypted media
/// survives a logout or account switch (okt-audit PASS-2 FINDING-1).
/// Idempotent — a missing directory is not an error.
Future<void> evictAllPlaybackScratch({
  required PlaybackScratchDirSource scratchDirSource,
}) async {
  final scratchDir = await scratchDirSource();
  if (await scratchDir.exists()) {
    await scratchDir.delete(recursive: true);
  }
}
