// Storage-agnostic seam for the encrypted DB image — task #1860, plan #131
// (web wave). Kept as a tiny interface (mirrors `SecureKeyStore` in
// db_encryption.dart) so the cold-start decision logic in
// `web_store_opener.dart` is testable under plain `flutter test` (Dart VM)
// with an in-memory fake, while the real implementation
// (`web_opfs_blob_store.dart`, `dart:js_interop` + `package:web`) is web-only
// and can only be exercised in an actual browser.
//
// Every byte this interface reads/writes/persists is ciphertext (produced by
// `core/crypto/db_image_cipher.dart`) — nothing that implements or calls this
// interface should ever pass plaintext through it.
import 'dart:typed_data';

abstract class EncryptedBlobStore {
  /// Returns the persisted ciphertext blob, or `null` if none exists yet
  /// (fresh install / never persisted on this device+browser).
  Future<Uint8List?> read();

  /// Persists [bytes] (already ciphertext — callers must encrypt first),
  /// replacing any previously persisted blob.
  Future<void> write(Uint8List bytes);

  /// Removes any persisted blob (e.g. on explicit logout / "forget this
  /// device").
  Future<void> delete();
}

/// In-memory [EncryptedBlobStore] test double. It must never be selected as a
/// runtime fallback after OPFS, password unwrap, or ciphertext validation
/// fails: those failures block encrypted startup instead of creating a fresh
/// plaintext/non-durable store.
class InMemoryBlobStore implements EncryptedBlobStore {
  Uint8List? _bytes;

  @override
  Future<Uint8List?> read() async => _bytes;

  @override
  Future<void> write(Uint8List bytes) async {
    _bytes = Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete() async {
    _bytes = null;
  }
}
