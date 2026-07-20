// Cold-start orchestration for the web encrypted store — task #1860, plan
// #131 (web wave). This is the pure-Dart decision logic behind §3/§4 of
// .docs/internal/at-rest-key-flow.md's "STANDARD DECRYPTION CORE": obtain the
// wrapped DEK -> unwrap via the SAME shared [KeyUnwrapper] core every
// platform uses (`core/crypto/key_unwrapper.dart` — no web-specific fork) ->
// read the persisted ciphertext blob -> decrypt it. Deliberately factored out
// of `connection_web.dart` so this logic — the actual security-relevant
// surface (fails-closed behavior, offline cache use) — is exercised by plain
// `flutter test` (Dart VM) against an [EncryptedBlobStore] fake, independent
// of the real OPFS/js_interop glue which can only run in a browser.
import 'dart:typed_data';

import '../crypto/db_image_cipher.dart' show decryptDbImage, encryptDbImage;
import '../crypto/envelope.dart' show WrappedEnvelope;
import '../crypto/key_material.dart' show Dek;
import '../crypto/key_unwrapper.dart' show KeyUnwrapper, KeyUnwrapperUnwrap;
import 'encrypted_blob_store.dart' show EncryptedBlobStore;

/// Result of a cold-start [WebStoreOpener.open] call.
class WebColdStartResult {
  const WebColdStartResult({required this.plaintextImage, required this.dek});

  /// The decrypted DB image bytes to load into a fresh in-memory sqlite3
  /// instance, or `null` if no store has ever been persisted on this
  /// device+browser (fresh install — the caller should create a brand-new
  /// empty database, then [WebStoreOpener.persist] it once initialized).
  final Uint8List? plaintextImage;

  /// The recovered DEK. Callers should [Dek.wipe] it once it is no longer
  /// needed for this session's persist calls (§1 of the design doc's
  /// wipe-on-use posture) — this class does not wipe it automatically
  /// because callers legitimately need to keep using it for later
  /// [WebStoreOpener.persist] calls during the session.
  final Dek dek;
}

/// Orchestrates the web store's cold-start open and later persist calls
/// against an [EncryptedBlobStore] (real: OPFS; test/fallback: in-memory).
class WebStoreOpener {
  WebStoreOpener({required this.blobStore});

  final EncryptedBlobStore blobStore;

  /// Cold-start open: unwraps the DEK from [wrappedDekPw] via [unwrapper]
  /// (the shared [KeyUnwrapperUnwrap.unwrapDek] core — identical to every
  /// other platform/backend), then reads + decrypts whatever ciphertext blob
  /// is currently persisted.
  ///
  /// **Fails closed** — this method NEVER returns a "successful" result with
  /// plaintext substituted by an empty database:
  /// - A wrong password (or a tampered `wrapped_dek_pw`) makes `unwrapDek`
  ///   throw an [EnvelopeUnwrapException] subtype (`envelope.dart`) — thrown
  ///   here, not swallowed.
  /// - A tampered/corrupted persisted blob (or a decrypt under the wrong DEK,
  ///   which cannot happen here since the DEK just came from a verified
  ///   unwrap, but IS possible if the blob predates a DEK rotation gone
  ///   wrong) makes [decryptDbImage] throw a [DbImageDecryptException]
  ///   subtype (`db_image_cipher.dart`) — also propagated, never caught.
  /// - Only a genuinely absent blob ([EncryptedBlobStore.read] returning
  ///   `null` — i.e. nothing has ever been persisted) is treated as the
  ///   legitimate "fresh install" case, distinct from every failure above.
  Future<WebColdStartResult> open({
    required KeyUnwrapper unwrapper,
    required WrappedEnvelope wrappedDekPw,
  }) async {
    final dek = await unwrapper.unwrapDek(wrappedDekPw);

    final cipherBytes = await blobStore.read();
    if (cipherBytes == null) {
      return WebColdStartResult(plaintextImage: null, dek: dek);
    }

    final plaintext = await decryptDbImage(
      ciphertext: cipherBytes,
      dek: dek.bytes,
    );
    return WebColdStartResult(plaintextImage: plaintext, dek: dek);
  }

  /// Opens with an already-unlocked account DEK. This is the production boot
  /// path: the DB layer neither retains a password nor derives a KEK again.
  Future<WebColdStartResult> openWithDek(Dek dek) async {
    final cipherBytes = await blobStore.read();
    if (cipherBytes == null) {
      return WebColdStartResult(plaintextImage: null, dek: dek);
    }
    final plaintext = await decryptDbImage(
      ciphertext: cipherBytes,
      dek: dek.bytes,
    );
    return WebColdStartResult(plaintextImage: plaintext, dek: dek);
  }

  /// Encrypts [plaintextImage] under [dek] and persists the ciphertext,
  /// replacing whatever was previously stored. The bytes handed to
  /// [EncryptedBlobStore.write] are ALWAYS ciphertext — this function is the
  /// only write path into the blob store, and it never calls `write` with
  /// [plaintextImage] directly.
  Future<void> persist({
    required Uint8List plaintextImage,
    required Dek dek,
  }) async {
    final cipher = await encryptDbImage(
      plaintext: plaintextImage,
      dek: dek.bytes,
    );
    await blobStore.write(cipher);
  }
}
