// Offline cache of the non-secret `/keybundle` fields needed to re-derive
// the password-KEK without a network round trip — task #1860, plan #131 (web
// wave), implementing the "cache {wrapped_dek_pw, salt_enc, kdf_params} in
// OPFS" step of .docs/internal/at-rest-key-flow.md §2/§4.
//
// Reuses the existing [SecureKeyStore] abstraction (`core/db/db_encryption.dart`)
// rather than hand-rolling a second OPFS-JSON mechanism: every field cached
// here is explicitly NOT secret (Appendix A.2/A.6 — salts and wrapped blobs
// are opaque-but-public-safe; only the password and the derived DEK/KEK are
// secret, and neither is ever written here), so any persistent per-origin
// key/value store the platform already has works. On web, [SecureKeyStore]
// is backed by `flutter_secure_storage`'s web backend, which is already wired
// up for the session token (see `connection_web.dart`'s historical comment)
// — one persistence mechanism instead of two.
//
// **CF-1 (flagged, not solved here):** this cache can only be populated AFTER
// at least one successful online `GET /keybundle` (or the enrollment
// `PUT /keybundle`). A browser that has NEVER completed that round trip has
// nothing to read here — first-ever login on a given device+browser
// necessarily needs network (there is no salt to derive a KEK from until the
// server hands one out, or the client mints one at enrollment). This is
// inherent to the zero-knowledge design, not a gap introduced by this file:
// a RETURNING user (one who has logged in online at least once) gets full
// offline cold-start; a brand-new device/browser does not, and that is
// expected/documented behavior, not a bug to silently paper over.
import 'dart:convert';
import 'dart:typed_data';

import '../crypto/envelope.dart' show WrappedEnvelope;
import '../crypto/kdf_params.dart' show Argon2idParams;
import 'db_encryption.dart' show SecureKeyStore;

/// The subset of a `/keybundle` response needed to re-derive the
/// password-KEK and unwrap the DEK offline: `wrapped_dek_pw`, `salt_enc`, and
/// `kdf_params`. Deliberately does NOT include `wrapped_dek_recovery` /
/// `salt_rec` / `salt_auth` / `auth_secret` — those aren't needed for the
/// password-unlock path this cache serves (recovery has its own pre-auth
/// bootstrap, task #1854's `RecoveryRepository`).
class CachedKeyBundleSaltInfo {
  const CachedKeyBundleSaltInfo({
    required this.wrappedDekPw,
    required this.saltEnc,
    required this.kdfParams,
  });

  final WrappedEnvelope wrappedDekPw;
  final Uint8List saltEnc;
  final Argon2idParams kdfParams;
}

/// Caches (and reads back) [CachedKeyBundleSaltInfo] via a [SecureKeyStore],
/// so a returning web user can re-derive their password-KEK and unwrap the
/// DEK with zero network access (§4 of the design doc).
class WebKeyBundleCache {
  WebKeyBundleCache(this._store);

  final SecureKeyStore _store;

  /// Secure-store key the cached keybundle JSON is kept under.
  static const String storageKey = 'matome.web.keybundle_cache_v1';

  Future<void> write(CachedKeyBundleSaltInfo info) async {
    final json = {
      'wrapped_dek_pw': info.wrappedDekPw.toBase64(),
      'salt_enc': base64.encode(info.saltEnc),
      'kdf_params': info.kdfParams.toJson(),
    };
    await _store.write(storageKey, jsonEncode(json));
  }

  /// Returns the cached info, or `null` if nothing has been cached yet on
  /// this device+browser (see the CF-1 note above).
  Future<CachedKeyBundleSaltInfo?> read() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CachedKeyBundleSaltInfo(
      wrappedDekPw: WrappedEnvelope.fromBase64(
        json['wrapped_dek_pw'] as String,
      ),
      saltEnc: base64.decode(json['salt_enc'] as String),
      kdfParams: Argon2idParams.fromJson(
        json['kdf_params'] as Map<String, dynamic>,
      ),
    );
  }

  Future<void> clear() async {
    // SecureKeyStore has no delete(); an empty write is the documented
    // "treated as missing" convention already used by DbEncryptionKeyManager
    // (see db_encryption_test.dart: "an empty stored value is treated as
    // missing and regenerated").
    await _store.write(storageKey, '');
  }
}
