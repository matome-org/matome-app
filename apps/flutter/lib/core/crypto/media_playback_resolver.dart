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
//   * There is deliberately NO proactive eviction/cleanup policy for scratch
//     files beyond "the next resolution for the same recordingId overwrites
//     it" — an app-lifecycle cache-clearing sweep (e.g. on background/logout)
//     is a separate follow-up, not required before the write flag can safely
//     flip (a stale scratch file is a disk-space concern, not a correctness
//     or data-loss one).
import 'dart:io';

import 'envelope.dart' show WrappedEnvelope;
import 'key_material.dart' show Dek;
import 'media_cipher.dart' show decryptToFile;

/// Supplies the private cache/temp directory decrypted scratch files should
/// live under. Injectable (mirrors `inbox_upload.dart`'s `dekSource` pattern)
/// so this module is unit-testable without a `path_provider` platform
/// channel; real callers wire this to `getTemporaryDirectory()` (or a
/// dedicated subdirectory under it).
typedef PlaybackScratchDirSource = Future<Directory> Function();

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
  } finally {
    dek.wipe();
  }
}
