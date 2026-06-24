import 'package:drift/drift.dart';

import 'db_encryption.dart';
// Conditional impl: native (ffi/SQLCipher-capable) vs web (wasm, no SQLCipher).
import 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart' as impl;

/// Opens the platform-appropriate lazy connection for the app database.
///
/// ## At-rest encryption (SEC audit-fix #815)
/// The Drift store holds recordings/transcripts/summaries — the largest at-rest
/// exposure for an audio/transcript app. The intended production protection is
/// **SQLCipher** on native, with a 256-bit key generated on first boot and kept
/// in `flutter_secure_storage` (see [DbEncryptionKeyManager]).
///
/// In the current version set, `sqlcipher_flutter_libs` cannot be co-built with
/// `drift_flutter` (Android plugin-namespace collision; Linux static-OpenSSL
/// requirement), so the lab build **relies on OS full-disk encryption (FDE)**
/// as the documented interim decision. The keying machinery is shipped and
/// unit-tested; enabling SQLCipher is a localized flip — see
/// `connection_native.dart` (`kSqlCipherEnabled`).
///
/// On **web** there is no SQLCipher equivalent for the drift wasm worker, so the
/// web DB is never encrypted at-rest; the browser storage sandbox (OPFS /
/// IndexedDB, same-origin) plus OS/disk encryption is the documented mitigation.
QueryExecutor openConnection({SecureKeyStore? keyStore}) =>
    impl.openPlatformConnection(keyStore: keyStore);
