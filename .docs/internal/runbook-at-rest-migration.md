# Runbook — enabling at-rest encryption (plan #131 → production)

> Status: honest / operational · Last updated: 2026-07-03
> This is the forward runbook for turning the **dark** at-rest-encryption
> mechanism (proven in dev/spike, gated behind compile-time flags) into a
> **live** production posture, plus the recovery posture for when something
> goes wrong mid-rollout. It does not re-derive the design — see
> [`at-rest-key-flow.md`](at-rest-key-flow.md) for the key hierarchy and
> [ADR-0002](../../services/api/docs/adr/0002-envelope-encryption-key-hierarchy.md)
> for the decision record — and it does not re-litigate what was actually
> verified — see [`dod-matrix-1857.md`](dod-matrix-1857.md) for that. This
> doc is the missing third piece: **how do we actually flip this on, and
> what do we do when it goes wrong.**
>
> Cross-links: [`architecture.md`](architecture.md) §11 D8 (implemented vs
> dark/deferred) and its "Known gaps / next" carry-forward table · spike
> **#815** (`apps/flutter/tool/spike_815_sqlcipher/DECISION.md`) · media
> migration engine, task **#1856** · recovery-code flow, task **#1854**.

---

## 1. Preconditions — nothing below should be attempted until these are true

| # | Precondition | Status today | Blocks |
|---|---|---|---|
| P1 | Real per-platform SQLCipher library packaged into the actual build (Linux: a repo-owned CMake step producing the shared lib the way `tool/spike_815_sqlcipher/build_libsqlcipher.sh` does ad hoc today, but wired into the real build; Android: the `sqlcipher_flutter_libs` ↔ `sqlite3_flutter_libs` manifest-namespace collision resolved, per DECISION.md §1) | **NOT DONE** (CF-3) | Step 3 (native flag flip) |
| P2 | `openEncryptedNativeConnection`'s connection construction swapped from `drift_flutter`'s `driftDatabase(..., setup:)` hook to the hand-rolled `NativeDatabase.opened(...)` path DECISION.md validates (today's code still uses the `setup` hook, which is the exact co-build path P1 replaces) | **NOT DONE** | Step 3 |
| P3 | Android/iOS round-trip actually run on a device or emulator (open→key→write→close→reopen→read + wrong-key-fails-closed + offline-cold-start — the same suite already proven on Linux) | **NOT DONE** — no device/emulator available in dev | Step 3 (mobile only; Linux desktop can proceed once P1/P2 land there) |
| P4 | A plaintext-DB → encrypted-DB migration exists (today only **media** has one — task #1856; the **DB** does not — CF-4) | **NOT DONE** | Step 4 |
| P5 | Normal-login `salt_auth` pre-auth bootstrap wired (`AuthRepository.login` can fetch `salt_auth` before authenticating) | **NOT DONE** (CF-1) | Step 2 (a user who has never unlocked on this device can't reach the password-KEK path without it) |

**Do not flip `kSqlCipherEnabled` or `kMediaEncryptionEnabled` to `true` in a shipped build until the row's blocking step is actually reachable.** Both flags default `false` for exactly this reason (see `connection_native.dart`'s and the media-encryption module's doc comments).

---

## 2. Forward steps (in dependency order)

### Step 1 — Native library packaging (closes CF-3, P1/P2)
1. Linux: promote `build_libsqlcipher.sh`'s recipe into a real repo-owned CMake build step (not a hand-run script), producing a checked-in-to-the-build-pipeline (not checked-into-git) `.so` alongside the app bundle.
2. Android: resolve the `sqlcipher_flutter_libs` vs `sqlite3_flutter_libs` plugin-namespace collision (DECISION.md §1) — either a namespace-patched fork (rejected in DECISION.md as higher-maintenance) or, preferred per that decision, extend the hand-rolled connection pattern to Android's `.aar`.
3. iOS: package a SQLCipher framework equivalent; no spike has attempted this yet — treat as unstarted, not "same as Android."
4. Swap `openEncryptedNativeConnection`'s construction to the hand-rolled `NativeDatabase.opened(...)` path everywhere (P2) — the keying *mechanism* is proven; the *connection construction* still uses the co-build hook it's meant to replace.

### Step 2 — Login wiring (closes CF-1, P5)
1. Wire `AuthRepository.login` to fetch `salt_auth` (and, on first-device enrollment, the rest of the keybundle) before authentication completes, so the password-KEK path (§3 of the design doc) is reachable from the real login screen, not just from tests.
2. Wire `openEncryptedWebConnection` in front of `appDatabaseProvider` (web) and the native encrypted path in front of the same provider — today neither is called from the app's boot sequence (per #1860's resume note and `connection_native.dart`'s doc comment).

### Step 3 — Flag flips, staged (closes CF-3 device gap)
1. Flip `kSqlCipherEnabled=true` for a **Linux-only** internal build first (P1/P2 satisfied, P3 not required for this platform) — dogfood before touching mobile.
2. Flip mobile only after P3 (an actual device/emulator round-trip, not a read of the Dart-level mechanism) passes on both Android and iOS.
3. Flip the media-encryption flag (`kMediaEncryptionEnabled`) once its own dependency — a ciphertext-aware Core ingestion pipeline (CF-6) — exists; flipping it earlier only affects local storage, not what Core/AI can read, and is lower risk than the DB flag, but should still not precede a canary (Step 5).

### Step 4 — Migration invocation (closes CF-4 for media; DB migration must be built first)
1. **Media** (task #1856 already ships this): invoke `MediaMigrationRunner.dryRun()` first (read-only, counts candidates, never gated) against a representative device population; then `MediaMigrationRunner.run({int? canaryLimit})` with a bounded `canaryLimit` before an unbounded run. The runner is crash-safe by construction (backup → encrypt → atomic swap → verify → DB-repoint → unlink, in that order, resumable from any interruption point) — see task #1856's implementation summary for the full state machine.
2. **DB** (does not exist yet — this is new work, not an invocation of existing code): before `kSqlCipherEnabled` ever flips on a device with an existing plaintext `matome.sqlite`, a migration task must ship an attach/rekey-or-export→re-encrypt→swap path, idempotent and resumable, mirroring the media migration's crash-safety shape (per task #1853's CF-4 carry-forward note). **Until this exists, do not flip the native flag on any device that might already have a plaintext DB** — today it fails closed (data inaccessible, not corrupted) rather than migrating, which is safe but is an outage, not a migration.

### Step 5 — Canary
1. Roll `kSqlCipherEnabled` (Linux, then mobile once P3 passes) to an internal/staff cohort first, behind whatever remote-flag mechanism the app already uses for `FeatureFlags` (mirrors how `FeatureFlags.localFirstSpaces` and `FeatureFlags.masterDetailLayout` were staged — single-flip rollback, default OFF).
2. Watch for: DB open failures (wrong-key / fails-closed exceptions surfacing as user-visible errors), media-migration verification failures, and any reports of "my data disappeared" (see §3 below — that symptom maps to a specific failure mode, not a generic bug).
3. Widen gradually; keep the flag single-flip revertible at every stage (this is why the flag-based approach was chosen over a one-way schema migration).

---

## 3. Recovery posture — per failure mode

**Governing principle:** every migration step in this design is built to fail closed and to be resumable or reversible — restated here as an explicit table so an on-call engineer doesn't have to re-derive it from source under pressure. "Wipe-and-resync" is a **last resort**, only when the local copy is unrecoverable AND the server-side data (or memory) is intact enough to be a legitimate source of truth for the resync — it is not the default answer.

| Failure mode | What happens today | Recovery action | Rollback vs wipe-resync |
|---|---|---|---|
| **DB migration crash mid-run** | No DB migration exists yet (P4 gap) — not applicable until Step 4's DB migration ships. Once it does, it must mirror the media migration's crash-safety shape: a persisted per-row state machine that resumes from wherever it stopped, verify-before-commit, and an explicit `rollback()` restoring the pre-migration plaintext from a backup. | Re-run the migration tool — a crash-safe design resumes in-flight rows automatically (do not manually intervene in the DB file). If the migration's own `rollback()` is available, prefer it over any manual SQL. | **Rollback** (to the pre-migration plaintext DB, via the migration's own restore path) — never wipe-resync for a DB migration crash: the local DB is the reconciled offline mirror of Core, but a crash-induced DB rebuild from Core would still lose any not-yet-synced local-only changes (loose items, unsynced local-space content per D6). Rollback-first, wipe-resync only if rollback itself is provably impossible (backup missing/corrupted). |
| **Media migration crash mid-run** | **Directly covered by task #1856.** The state machine (`pending → backedUp → encrypted → swapped → verified → done`) persists to a JSON manifest (itself atomically written); a crash at ANY step — including "DB already repointed, plaintext not yet unlinked" — resumes correctly on next run (`MediaMigrationRunner.run()` treats any non-`done` manifest entry as in-flight and resumes it first). Verify-before-unlink is enforced by code order, not convention: the plaintext original is never deleted before the round-trip decrypt + SHA-256 check passes. | Re-run `MediaMigrationRunner.run()` — it resumes automatically. If a specific file's ciphertext fails verification (tamper/corruption), that file throws `MediaMigrationVerificationException` rather than silently succeeding; investigate that file specifically (its plaintext backup is still present until `done`). | **Rollback** via `MediaMigrationRunner.rollback(id)` — restores the plaintext from `.media_migration_backups/<id>.orig.bak`, verified against the recorded SHA-256 before touching the DB row, then reverts the row. This is the designed, tested path (task #1856); wipe-resync is not needed and would be strictly worse (loses any local-only edit history the DB row carried). |
| **Wrong-key lockout** (password forgotten, device-KEK lost/corrupted, keystore wiped by an OS update) | By design, fails closed — `openEncryptedNativeConnection` and `openEncryptedWebConnection` both throw rather than falling back to plaintext or regenerating a DEK (see `connection_native.dart`'s "fails closed" doc comment and `key_unwrapper.dart`'s INVARIANT). Without password **and** recovery code, the DEK is mathematically unrecoverable (ADR-0002's "losing all KEKs is unrecoverable by design" consequence). | If the user has the **recovery code**: task #1854's `RecoveryRepository` flow — reset via recovery code re-wraps the same DEK under a new password-KEK; existing encrypted data is untouched (no re-encryption, O(1) operation). If the recovery code is ALSO lost: there is no server-side escrow (deliberate, zero-knowledge design) — the local encrypted store is unrecoverable. | **Recovery-code path = rollback-equivalent** (same DEK, same data, just re-wrapped — not a wipe). **No recovery code = forced wipe-and-resync**, and only of what Core actually holds (Core still stores recordings/transcripts in plaintext per ADR-0002's honest limits, so cloud-synced items ARE recoverable by re-installing and re-authenticating; **anything local-only / unsynced, per D6's local-first model, is genuinely and permanently lost** — this is the explicit, disclosed cost of the zero-knowledge design, not a bug to "fix" with an escrow backdoor). |
| **Silent-wipe on Android** (`flutter_secure_storage`'s `AndroidOptions.resetOnError` defaulting to `true`, wiping the stored key/DEK-wrap on a transient decrypt error) | **Mitigated in code, not just documented:** both `DbEncryptionKeyManager` (SQLCipher passphrase) and `buildDeviceKekSecureStorage()` (device-KEK) construct their `FlutterSecureStorage` with `AndroidOptions(resetOnError: false)` explicitly, specifically to prevent this footgun — see the doc comments in `db_encryption.dart` citing this exact failure mode. | Confirm at code-review / release-gate time that every `FlutterSecureStorage` construction touching a DEK-wrap or device-KEK path uses `resetOnError: false` — a regression here (someone constructing a bare `FlutterSecureStorage()` on a new call site) is the actual risk, not the documented mitigation itself failing. If a wipe DOES occur despite this (e.g. a future package version changes defaults again, or the platform channel itself corrupts data outside this flag's control): this is functionally the same as "wrong-key lockout" above — no password/recovery-code path helps because the DEK is gone, not the KEK; treat it as the **wrong-key-lockout** row if the user's own password/recovery code still validates against the server-held `wrapped_dek_pw`/`wrapped_dek_recovery` (those are NOT device-local, so a device-local keystore wipe does not destroy them) — recovery is possible via the SAME recovery-code flow as above, re-enrolling this device's device-KEK fresh. | **Recoverable via recovery-code re-enrollment** (the server-held wraps survive a device-local keystore wipe) — genuinely a **rollback-equivalent for the account**, but a **local wipe-and-resync for this one device's local-only data** (anything not yet synced to Core before the wipe is lost, same D6 caveat as above). |

**Cross-cutting rule for on-call:** before invoking ANY manual recovery action, check whether the affected component has its own tested `rollback()`/resume path (media migration does; a future DB migration must) — manual SQL/file surgery against an encrypted store is exactly the kind of intervention this design's atomic-swap-and-verify machinery exists to make unnecessary, and hand-editing a SQLCipher file or a wrapped-envelope blob without going through the unwrap/wrap core risks turning a recoverable failure into an unrecoverable one.

---

## 4. Carry-forward ledger this runbook inherits

Same ledger as `architecture.md` §11 "Known gaps / next" (CF-1, CF-3, CF-4, CF-6, CF-7, CF-8, CF-9, CF-10) — restated here only insofar as CF-1/CF-3/CF-4 are direct **preconditions** (§1 above) for this runbook's own steps. See `architecture.md` for the full table and `dod-matrix-1857.md` for the session-level detail behind each row.
