# Matome Vault v1 threat model

Status: contract baseline for the shared Vault implementations. The native
backend implements this boundary without activating imports/captures or moving
the existing app crypto code under `apps/flutter/lib/core/crypto`.

## Assets and trust boundary

The protected assets are durable local media plaintext, per-blob FEKs and the
unlocked Account DEK. The app owns authentication, keybundle retrieval,
password/recovery/passkey/device KEKs and biometric UI. It gives the package an
already-unlocked `VaultKeyMaterial` capability bound to a `VaultAccountId`.
The Vault must never derive meaning from an authentication method.

Each account has a separate logical and physical namespace. A session and store
are account-bound; blob IDs are resolved only inside that namespace. Account
switch must close the old session, wipe/release its key capability, revoke all
plaintext leases and only then open the new account. Cross-account lookup must
fail as missing, never search another namespace.

The adversary can read, copy, truncate, reorder or replace durable local bytes;
interrupt the process at any operation boundary; provide a wrong key; exhaust
or remove storage; and inspect expired temporary files. Encryption at rest does
not defend a currently unlocked process against root/malware, same-origin XSS,
a malicious extension, screenshots or an explicit user export.

## MEC1 invariants

MEC1 remains the media format specified by the existing
`media_cipher.dart` and `at-rest-key-flow.md`: magic/version header, one random
FEK per blob, AES-256-GCM, 64 KiB plaintext chunks, a 4-byte random nonce prefix
plus 8-byte big-endian chunk counter, chunk index as AAD, and independent
authentication tags. This task defines no cipher implementation or format
migration.

Implementations must stream with bounded memory. Range reads expand internally
to complete MEC1 chunk boundaries, authenticate each complete chunk, then emit
only the requested half-open plaintext range. No plaintext from a failing chunk
may be emitted. Wrong DEK/FEK, header/tag/ciphertext corruption, truncation,
reordering, unsupported version or impossible framing raises a closed failure;
there is no plaintext retry path.

## Durable lifecycle and crash boundaries

The only durable states are:

| State | Meaning | Allowed next state |
| --- | --- | --- |
| `staging` | Ciphertext ingest is incomplete or not committed | `ready`, cleanup |
| `ready` | Ciphertext and required metadata are durably committed | `deleting`, `missing` |
| `deleting` | Tombstone is durable; physical removal may be incomplete | complete removal |
| `missing` | Metadata expected an object but safe ciphertext is unavailable | explicit reset/recovery |

Filesystem/OPFS writes and metadata commits are not one atomic transaction.
The durable journal records ingest, delete and lease progress through `started`,
`objectDurable`, `metadataCommitted` and `cleanupPending`. Startup reconciliation
must be idempotent and conservative:

- Remove abandoned staging only when it cannot be a committed ready object.
- Mark a row with no ciphertext `missing`; never fabricate an empty blob.
- Preserve or quarantine an unreferenced ready object rather than destroy the
  only possible copy automatically.
- Resume a durable deleting tombstone to completion.
- Revoke expired plaintext leases.
- Quarantine size mismatches and report corruption instead of correcting facts.

A crash-recovery state that cannot be classified safely returns
`crashRecoveryRequired`; normal reads remain blocked until reconciliation.

## Temporary plaintext

Durable package-owned plaintext is forbidden. Materialized plaintext exists
only through a `VaultBlobLease` with an explicit `VaultLeasePurpose` and bounded
TTL. Playback/preview may use a private cache file or browser object URL;
explicit export is user-authorized but still not Vault identity. Dispose,
expiry, lock, logout, account switch and startup reconciliation revoke/delete
lease material best-effort. Flash/SSD secure erasure is not promised.

Recorders may require private plaintext staging until a container is finalized.
The session allocates that staging as a `VaultPlaintextLease` with
`recorderFinalization` purpose and TTL; it has no source blob ID and never
becomes Vault identity. Finalized output must be ingested promptly and staging
removed after durable commit. Whether active capture delays automatic app lock
is app policy, not a Vault API decision.

## Failure matrix

| Condition | Required behavior |
| --- | --- |
| Wrong Account DEK | Authentication fails; expose `wrongKey`; emit no failing-chunk plaintext; no reset/fallback |
| Lost/unavailable DEK | Expose `keyUnavailable`; Vault remains unreadable; only explicit app reset may discard it |
| Cipher/header/tag corruption | Expose `corruptCiphertext` or `unsupportedFormat`; quarantine/preserve evidence |
| Interrupted ingest/delete | Block unsafe reads; reconcile journal to a conservative durable state |
| Account switch | Close old session and leases before opening isolated new namespace |
| OPFS/backend absent | Expose `backendUnavailable`; never silently use in-memory or plaintext persistence |
| Blob/object absent | Mark/expose `missing`; never return empty bytes or fetch from another namespace |
| Lease expired | Revoke material and expose `leaseExpired`; never extend implicitly |

Reset is an explicit destructive app decision after unlock/key-loss messaging.
The package provides no automatic reset on wrong key, corruption, transient
backend errors or account switch.

## Explicit non-goals

- Flutter/Riverpod integration, Drift schemas, SQLCipher and auth/unlock UI.
- Web OPFS backend implementation and Apple/Windows host validation.
- MEC1 implementation or movement of existing app crypto code.
- Uploads, Core repositories/endpoints and plaintext HTTPS upload behavior.
- Cloud E2EE or changing what Core/S3/AI can read.
- Mounted filesystems or direct browsing by other applications.
- Migration of legacy local paths/data; v1 adoption may use an explicit reset.
- Retention, quota, upload completion and storage-pressure policy.
- Guaranteed physical secure deletion on flash/SSD.
