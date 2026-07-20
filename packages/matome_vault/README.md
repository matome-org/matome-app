# matome_vault

Private, unpublished, pure-Dart contracts and storage engines for Matome's
account-scoped encrypted media vault. The Flutter host supplies platform roots
and unlocked key capabilities; imports/captures and Drift remain unwired.

```yaml
dependencies:
  matome_vault:
    path: ../../packages/matome_vault
```

## Frozen v1 boundary

- `MediaInput` adapts picker, provider or finalized capture streams without
  transferring ownership of the source.
- `VaultKeyMaterial` accepts an already-unlocked Account DEK capability. Unlock
  methods, KEKs, password/passkey/biometric UI, recovery and keybundles stay in
  the app.
- `VaultSession` binds one unlocked capability to exactly one `VaultAccountId`
  namespace. It can allocate purpose-and-TTL-bound recorder staging; account
  switch closes the old session and its leases first.
- `MediaBlobStore` owns encrypted ingest, authenticated full/range reads,
  purpose-and-TTL-bound plaintext leases, delete preflight, tombstoned deletion,
  journal inspection and reconciliation. `prepareDelete` waits for active
  readers and blocks new leases without removing ciphertext; the app performs
  its durable remote delete before calling `delete`.
- Durable blob states are `staging`, `ready`, `deleting` and `missing`. Only
  `ready` may be read or leased.
- `VaultBlobId` is an opaque CSPRNG identifier, never a content hash or physical
  path. `VaultBlobStat` keeps plaintext and ciphertext sizes distinct.
- Expected security failures use `VaultFailure` and must fail closed. No backend
  may silently substitute plaintext or another account namespace.

The contracts do not define retention. The app decides whether a ready blob
should be deleted, calls `prepareDelete`, completes its remote durable delete,
then calls `delete`; the package only enforces lease exclusion and performs the
durable local state transition safely.

## MEC1 core

The package exposes pure-Dart MEC1 stream encryption and authenticated full or
plaintext-range reads through reopenable `Mec1CiphertextSource` and async
`Mec1CiphertextSink` abstractions. See [MEC1 compatibility](doc/mec1.md) for the
frozen format, deterministic vector, range offset and memory bound.

## Native backend

`NativeMediaBlobStore` is selected only for `dart.library.io`; Web receives an
unsupported stub so the public entrypoint remains compilable. The host passes
an absolute app-private Application Support root. The backend canonicalizes it,
derives a SHA-256 account directory, and never returns a durable physical path.
Temporary plaintext paths exist only through explicit TTL-bound leases.

Each random `VaultBlobId` owns one `.mec1` object. User filenames and content
types are never used in physical names or plaintext journal metadata. Ingest
streams into staging, flushes, decrypt-verifies, atomically renames, and commits
a two-slot manifest. Tombstones remain durable until object and stale-manifest
cleanup completes. `reconcile()` removes partial staging and leases, completes
deletes, promotes a verified post-rename object, and quarantines corruption or
unreferenced objects idempotently. Wrong account keys and transient backend
failures preserve ciphertext.

## Web backend

`WebMediaBlobStore` is selected only for `dart.library.js_interop`; VM builds
receive a fail-closed stub. `probeWebMediaBlobStore()` reports a typed blocking
capability when durable OPFS is unavailable. No memory or plaintext fallback is
provided.

The browser backend derives an opaque SHA-256 account namespace and uses only
random blob identifiers as physical names. Ingest writes `next`, verifies MEC1,
transactionally publishes `current`, commits a two-slot manifest, then removes
staging. A durable deleting manifest acts as the tombstone. `reconcile()`
converges interrupted writes/deletes, quarantines authenticated corruption and
unknown objects, and never exposes an OPFS handle or path through the public API.
Plaintext leases are revocable browser object URLs and are never persisted.

## Verification

From this directory:

```bash
dart pub get
dart analyze
dart test
CHROME_EXECUTABLE=/usr/bin/chromium dart test -p chrome --concurrency=1 \
  test/web_blob_store_test.dart
dart run tool/public_api_smoke.dart
dart compile exe tool/public_api_smoke.dart -o /tmp/matome_vault_smoke
dart compile js tool/public_api_smoke.dart -o /tmp/matome_vault_smoke.js
```

The executable and JavaScript compilations prove that the same public API is
usable from Dart VM and Web targets. `test/architecture_test.dart` permits
`dart:io` only in the conditionally
exported backend and rejects Flutter, Riverpod, Drift, app/domain, endpoint and
`dart:ffi` imports from package source.

See [the threat model](doc/threat-model.md) before implementing a backend or
crypto adapter.
