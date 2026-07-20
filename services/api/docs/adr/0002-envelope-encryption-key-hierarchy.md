# ADR 0002: Envelope Encryption Key Hierarchy for At-Rest Client Data

## Status

Accepted.

**Related docs (cross-links):**
- Design doc (full protocol, sequence diagrams, frozen wire format):
  `.docs/internal/at-rest-key-flow.md`
- Multi-user space key-share (slot `0x05`):
  `docs/adr/0003-space-kek-multi-user.md`
- Architecture record — what of this is implemented+tested vs dark/deferred
  in the shipped client, plus the carry-forward ledger P2 planning inherits:
  `.docs/internal/architecture.md` §11 D8 (this ADR's client sits on top of
  the local-first item-organization model in the same doc's §5 / D6 / D7,
  plan #102).
- Honest cross-platform verification state (what was actually run vs. read
  from source): `.docs/internal/dod-matrix-1857.md`.
- Forward rollout steps + recovery posture (rollback vs wipe-and-resync per
  failure mode): `.docs/internal/runbook-at-rest-migration.md`.
- Native-connection spike **#815** — go/no-go on the hand-rolled SQLCipher
  connection this ADR's `KeyUnwrapper`/DEK machinery keys:
  `apps/flutter/tool/spike_815_sqlcipher/DECISION.md`.

## Context

Plan #131 ("Parte 1 — Login + encriptação padronizados") requires every Matome
client (Flutter web, mobile, desktop) to open its local at-rest store (Drift DB
+ media) through one shared decryption process, offline-capable after first
unlock, with the server never able to decrypt client data ("zero-knowledge").

Two designs were on the table:

1. **Single user key** — one secret, derived from the password, directly
   encrypts the data.
2. **Envelope encryption** — a random data key encrypts the data; the data key
   is itself wrapped ("enveloped") multiple independent ways, one per unlock
   method.

A single-key design was rejected outright: changing the password would force
re-encrypting the entire local store (DB + every media file), which is
expensive, unsafe to interrupt mid-operation, and does not extend to a second
unlock method (recovery code, OS keystore) without either sharing the same
secret across methods (weak) or re-encrypting again per method (worse).

## Decision

Adopt a three-tier envelope hierarchy: **DEK / KEK / FEK**.

```
password ──Argon2id──► password-KEK  ─┐
recovery code ──Argon2id──► recovery-KEK ─┼─wraps──► DEK ──wraps──► FEK (per file)
device keystore key (native only) ───────┘
```

- **DEK (Data Encryption Key)** — one random 256-bit key per user. The only
  key that ever decrypts the SQLCipher DB directly. Never leaves the device in
  clear, never persisted in clear.
- **KEK (Key Encryption Key)** — not one key but a *set* of independent keys,
  each capable of unwrapping the same DEK: password-KEK (portable, server
  holds the wrapped copy), recovery-KEK (from a one-time high-entropy recovery
  code), device-KEK (native-only, OS keystore, enables password-less offline
  unlock). Adding or revoking an unlock method only touches its own wrapped
  copy of the DEK — the DEK itself, and therefore the encrypted data, is
  untouched.
- **FEK (File Encryption Key)** — one random 256-bit key per media file,
  wrapped by the DEK. Media is encrypted as a chunked AES-256-GCM stream under
  its own FEK rather than the DEK directly, so large audio files never load
  fully into memory and a DEK rotation only re-wraps FEK references instead of
  re-encrypting every file on disk.

Consequences of this shape:

- **Password change is O(1).** Re-derive the password-KEK, re-wrap the same
  DEK, `PUT` the new `wrapped_dek_pw`. No data touched.
- **Adding an unlock method is additive.** Enrolling a device keystore or a
  recovery code produces one more wrapped copy of the same DEK; it does not
  require re-encrypting anything already at rest.
- **Losing all KEKs is unrecoverable by design.** Without the password, the
  recovery code, and the device keystore, the DEK cannot be reconstructed —
  that is the zero-knowledge trade-off, not a bug. Any recovery mechanism
  beyond the recovery code (e.g. support-side escrow) is a deliberate,
  separately-disclosed weakening of the guarantee, not a default.

The exact byte-level wrap format, the KDF parameters, and the reserved slots
for future KEK types (passkey, per-space) are frozen in
`.docs/internal/at-rest-key-flow.md` Appendix A (task #1848) and are treated
as part of this decision, not an implementation detail — the format is
authenticated (AEAD; AES-256-GCM in v1, never raw block-cipher output) and
versioned (`format_version` byte) so a future crypto-primitive change does not
require reasoning about every historical wrapped blob's shape.

## Auth-secret ≠ encryption-secret

Login authentication and DEK unwrapping use **different derivations from the
same password, with different salts**:

- `auth_secret = Argon2id(password, salt_auth)` — sent to the Core API as the
  login credential (never the raw password).
- `KEK = Argon2id(password, salt_enc)` — used to unwrap the DEK, **never
  leaves the client**.

This is deliberate, not incidental. If a single hash served both purposes, the
value the server legitimately receives at login (to verify authentication)
would also be the value that unwraps the user's data key — collapsing
"proves who you are" and "can decrypt your data" into one secret the server
sees on every login. Three independent, randomly generated salts
(`salt_enc`, `salt_rec`, `salt_auth` — Appendix A.2) are what make "the server
cannot decrypt client data" a property of the math, not a promise about how
the server chooses to use a secret it already has.

An earlier design pass considered SRP (Secure Remote Password) for this split.
The frozen decision (plan #131 crypto pins) is a **salted Argon2id verifier**
instead: simpler to implement consistently across web/mobile/desktop, and it
already achieves the required property (server never receives the raw
password or the KEK) without SRP's additional protocol complexity. SRP is not
ruled out for a future hardening pass; it is not required for this decision to
hold.

## Honest limits (must be stated, not overclaimed)

This design's "zero-knowledge" and "end-to-end encrypted" claims are scoped
narrowly. Overclaiming here is a trust liability, so this ADR states the
boundary explicitly (full detail: `.docs/internal/at-rest-key-flow.md` §6):

1. **The Core API still processes and stores plaintext.** Recordings and
   transcripts are persisted in clear on Core today, and server-side
   transcription needs plaintext audio to function. This design encrypts
   **the on-device mirror only**. The truthful claim is *"your local store is
   encrypted with a key we cannot unwrap,"* not *"we never see your data."*
   A server that truly never sees plaintext requires client-side
   transcription/AI or a processing enclave — a separate, materially more
   expensive product decision, out of scope for this ADR.
2. **The zero-knowledge guarantee is strongest on native, weaker on web.** A
   web client's JavaScript is served by us on every page load, so a malicious
   or compromised deploy could exfiltrate the password or DEK during an active
   session. The guarantee is credible for installed, code-signed native apps;
   it is weaker for a web client until mitigations (Subresource Integrity,
   pinned service-worker builds) are in place.
3. **This defends data at rest, not an active session.** Once the DEK is
   resident in memory and the store is decrypted, local malware or same-origin
   XSS can read plaintext. Envelope encryption is not a substitute for session
   hardening (short token TTL, refresh rotation, device binding).
4. **Processing plane exposure is opt-in and transient.** Cloud transcription,
   where enabled, is the one point where plaintext audio leaves the device
   over TLS; it is consent-gated, processed in RAM only, and not persisted by
   the processing plane. On-device transcription (future) removes this
   exposure entirely.

These limits are non-negotiable disclosure requirements for any user-facing
copy describing this feature (e.g. "we can't read your data" must not appear
unqualified).

## Rejected Alternatives

- **Single user key, no envelope.** Rejected: forces full re-encryption of DB
  + media on every password change and cannot cleanly support multiple unlock
  methods (recovery code, device keystore) without either sharing one secret
  across all of them or re-encrypting per method.
- **One Argon2id hash serving both login authentication and KEK derivation.**
  Rejected: collapses the auth-secret/encryption-secret boundary, meaning the
  server would legitimately hold a value that (with the same salt) also
  unwraps the DEK. Distinct salts (`salt_enc` vs `salt_auth`) cost nothing and
  close this off entirely.
- **SRP for the auth split.** Not rejected outright, but not adopted for P1 —
  the salted Argon2id verifier meets the same requirement (server never sees
  the raw password or KEK) with less protocol surface across three client
  platforms. Revisit if a future threat model specifically needs SRP's
  additional properties (e.g. resistance to a passive network observer
  learning the auth-secret itself).
- **Platform-differentiated Argon2id profiles (heavier "native," lighter
  "web").** Rejected for the *portable* KEKs (`salt_enc`, `salt_rec`,
  `salt_auth`): `wrapped_dek_pw` is wrapped once and must be unwrappable by
  any device on the account. Different per-platform KDF params would derive
  different KEKs from the same password on different platforms, breaking
  cross-device login. A single portable profile sized to the weakest platform
  (browser Argon2id-WASM) is used instead; see
  `.docs/internal/at-rest-key-flow.md` Appendix A.3 for the full rationale and
  the chosen parameters. The device-KEK (native-only, OS keystore) is the one
  genuinely platform-specific key in the hierarchy, and it skips Argon2id
  entirely since it is not password-derived.
- **RFC-3394 (AES Key Wrap) instead of AES-256-GCM for the wrap layer.**
  Considered and deferred, not rejected: `alg_id` in the wire format
  (Appendix A.4) reserves room for it. AES-256-GCM was chosen for v1 because
  it is the same primitive already required for the per-file media stream
  (§8.3 of the design doc), so one audited AEAD implementation covers every
  wrap in the system.

## Consequences

- Task #1849 (crypto core) and #1851 (`/keybundle`) implement directly against
  the frozen wire format (`.docs/internal/at-rest-key-flow.md` Appendix A) with
  no further KDF-parameter or wrap-layout decisions open.
- Any future KEK type (passkey-derived, per-space shared key) is additive: a
  new `wrapper_type` value against the same DEK, not a hierarchy change. Slots
  `0x04` (passkey-KEK) and `0x05` (space-KEK) are reserved in the format now,
  unimplemented in P1.
- A DEK rotation (e.g. suspected compromise) re-wraps under every existing KEK
  and re-wraps every FEK, but does not require re-deriving KEKs from
  passwords/recovery codes already on file — bounded, backgroundable work.
- Any user-facing copy about this feature must carry the honest-limits
  qualification above; Marketing/Support-facing claims of "we can't read your
  data" without qualification are a documentation bug against this ADR.
