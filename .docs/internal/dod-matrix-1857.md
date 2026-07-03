# Cross-platform + interop Definition-of-Done matrix — task #1857

> Related: design doc [`at-rest-key-flow.md`](at-rest-key-flow.md) · decision record
> [ADR-0002](../../services/api/docs/adr/0002-envelope-encryption-key-hierarchy.md) ·
> architecture summary [`architecture.md`](architecture.md) §11 D8 and its
> "Known gaps / next" table (this matrix's carry-forward ledger, restated there
> for durability) · forward rollout + recovery posture
> [`runbook-at-rest-migration.md`](runbook-at-rest-migration.md) · native-connection
> spike **#815** (`apps/flutter/tool/spike_815_sqlcipher/DECISION.md`).

Plan #131 ("unified login + at-rest encryption"), Wave 5 — **verify-only**.
This is the honest state of the world as actually exercised in this
session, on this host, on `migration/flutter-lab`. A cell says
**VERIFIED-here** only when a test in this repo was actually run, by me, in
this session, and it exercised the real production code path (not a
restatement of an earlier wave's doc comment). Everything else says
**UNVERIFIABLE-in-this-env** with the concrete reason, or **N/A-by-design**
where the AC column doesn't apply to a platform's actual architecture.

## The matrix

| Platform | Plaintext-scan (disk = zero plaintext) | Fails-closed (wrong key) | Offline cold-start | Keybundle-down (defined behavior) |
|---|---|---|---|---|
| **Android** | UNVERIFIABLE-in-this-env — no device/emulator on this host (CF-3). SQLCipher production packaging for Android is not wired (`kSqlCipherEnabled` dark); the Dart-level unwrap mechanism is the same code proven on Linux, but the Android *build* (manifest-namespace collision, per spike #815 `DECISION.md` §1/§3) was never attempted. | UNVERIFIABLE-in-this-env — same reason. | UNVERIFIABLE-in-this-env — same reason. | UNVERIFIABLE-in-this-env — same reason. |
| **iOS** | UNVERIFIABLE-in-this-env — no device/simulator on this host (CF-3), same packaging gap as Android (per-platform SQLCipher lib not built/shipped). | UNVERIFIABLE-in-this-env | UNVERIFIABLE-in-this-env | UNVERIFIABLE-in-this-env |
| **Linux desktop** | **VERIFIED-here.** Built a real throwaway SQLCipher 4.7.0 `.so` from the vendored amalgamation (`tool/spike_815_sqlcipher/build_libsqlcipher.sh`) and ran `test/db/sqlcipher_encrypted_open_test.dart` against it: a real written row + the seeded "Pessoal" workspace + the literal table name are all absent from the raw on-disk bytes, and the SQLCipher random-salt header replaces the plaintext `SQLite format 3` magic. | **VERIFIED-here.** Same run: reopening the keyed file through an unrelated enrollment (fresh device-KEK/DEK) throws `SqliteException` (SQLCipher HMAC check fails) and never returns a usable connection; the original enrollment still opens correctly afterward — the on-disk file is provably untouched by the failed attempt. | **VERIFIED-here.** Same run: with `HttpOverrides.runZoned` hard-blocking ALL network access (any HTTP client construction throws), a "cold" reopen of the device-KEK-encrypted DB still succeeds and reads back a row written in a prior "warm" session. | **VERIFIED-here, by design (device path is keybundle-independent).** The same offline-cold-start test IS the keybundle-down proof for native today: `NativeDekProvisioner` never calls `/keybundle` at all (bootstraps its device-KEK + wraps the DEK entirely locally — see `db_encryption.dart`'s documented KNOWN GAP), so "server down" and "airplane mode" are the identical code path, already exercised above. This is intentional per CF-1/CF-cross-device-sync-gap, not an accidental omission — but it also means Linux does **not** yet prove behavior for a *password-based* login hitting a down server, because that flow isn't wired end-to-end (CF-1). |
| **Web** | **VERIFIED-here (codec level).** `test/core/db/opfs_plaintext_scan_test.dart` — the exact bytes `WebStoreOpener.persist` produces (DB image codec) and the exact bytes `encryptFileToFile` produces (media codec) contain zero of six realistic plaintext markers, including markers straddling AEAD chunk boundaries. **NOT independently re-verified here:** the real OPFS file-write mechanism (`web_opfs_blob_store.dart`) — a real-Chromium check was done in an earlier task (#1860) per its doc comments, not re-run by me (see below, browser test runner is broken in this env). | **VERIFIED-here.** `test/core/db/web_store_opener_test.dart`: wrong password throws `EnvelopeTamperException`, and a corrupted persisted blob (even with the correct password) throws `DbImageDecryptException` — neither falls back to an empty/plaintext store. | **VERIFIED-here, partially.** `WebKeyBundleCache` (offline cache of `wrapped_dek_pw`/`salt_enc`/`kdf_params`) round-trips correctly with zero network involved (`test/core/db/web_key_bundle_cache_test.dart`), which is the piece that makes a *returning* user's cold start offline-capable. **NOT verified end-to-end in a browser**: `openEncryptedWebConnection` (the function that actually chains cache→unwrap→open) cannot be exercised under plain `flutter test` (imports `dart:js_interop`/`package:web` via `web_opfs_blob_store.dart` — confirmed by a compile probe in this session, see below) and `flutter test --platform chrome` is broken in this environment (see below) — so this is UNVERIFIABLE-in-this-env for the full function, VERIFIED-here for its offline-cache building block. | **Defined in code, UNVERIFIABLE-in-this-env for execution.** `openEncryptedWebConnection` throws an explicit `StateError` with a documented message when there is no cached keybundle AND no `fetchKeyBundleOnline` callback supplied (the true first-cold-start-with-server-down case), and simply propagates whatever exception `fetchKeyBundleOnline` raises otherwise (server-down mid-fetch) — never silently falls back to an empty/plaintext store. This is read directly from the source (`connection_web.dart` lines ~116–140) and is intentional (documented as "the CF-1 gap"), not accidental — but I could not execute it as a test in this session for the same `dart:js_interop`/broken-chrome-platform reason as the cell to its left. |

### Server (Elixir/Core)

| Check | Result |
|---|---|
| `/keybundle` returns only opaque blobs | **VERIFIED-here.** `test/matome_api_web/controllers/key_bundle_controller_test.exs` — "opaque-only" test reads the raw DB row directly (bypassing the controller/JSON layer) and asserts every field is byte-identical to what the client sent; the GET response echoes the same opaque blobs. Ran 10/10 stable full-suite runs after the CF-2 fix below (see that section for reproduction of the failure mode this fixes). |
| Recovery-code round trip | **VERIFIED-here.** `apps/flutter/test/core/crypto/recovery_flow_test.dart` — enroll → forget password → reset via recovery code → DEK bytes byte-identical (re-wrap, not re-encrypt) → new password unwraps the same DEK. |
| Recovery-code single-use | **VERIFIED-here.** Same file, "single-use / rotation" test: the OLD code, replayed against the ROTATED `wrapped_dek_recovery`, throws `EnvelopeTamperException`; the NEW code recovers the same DEK. |

## The interop fixture (the key new artifact this task adds)

**New file:** `apps/flutter/test/core/crypto/interop_multi_device_test.dart`

Fixture: one account, one 32-byte DEK, generated once. Wrapped THREE
independent ways:
1. Under a password-KEK (`PasswordKeyUnwrapper`, Argon2id(password, salt_enc)).
2. Under device-KEK "A" (`DeviceKeystoreKeyUnwrapper` over an isolated fake
   `SecureKeyStore`, simulating one physical device's OS keystore).
3. Under device-KEK "B" (a second, independent fake `SecureKeyStore` with a
   *different* random device-KEK, simulating a second physical device).

All three envelopes are unwrapped through the ONE shared
`KeyUnwrapper.unwrapDek` core (the extension method backends cannot
override — see `key_unwrapper.dart`'s INVARIANT note), and the recovered
plaintext is asserted byte-identical to the original DEK **and to each
other**, pairwise. A second test proves the two device-KEKs are genuinely
independent (not silently interchangeable): device B's KEK fails closed
(`EnvelopeTamperException`) against device A's wrapped envelope.

```
$ flutter test test/core/crypto/interop_multi_device_test.dart
00:00 +2: All tests passed!
```

This is the concrete proof of the multi-device model: N devices, N
independent device-KEKs, ONE shared DEK, all interoperable through a single
unwrap core — which is what makes "log in from a second device" or "recover
via password" reach the same at-rest data.

## CF-2: the rate-limiter test flake — fixed (test-infra only, sanctioned exception)

**Root cause, confirmed by reading the code (not guessed):**
`MatomeApi.RateLimiter` backs `router.ex`'s `:keybundle_get_rate_limit` and
`:keybundle_recovery_rate_limit` pipelines with a single GenServer-owned,
**named, public ETS table that lives for the whole BEAM process** — it is
never reset between ExUnit tests. Both pipelines include an `:ip` check
(30/min and 20/min respectively) alongside the intended per-user check.
`Phoenix.ConnTest.build_conn/0` always hardcodes `remote_ip: {127, 0, 0,
1}`. `key_bundle_controller_test.exs` and
`key_bundle_recovery_controller_test.exs` both built their
*authenticated* conns (the ones that actually issue the GET/PUT
`/keybundle[/recovery]` calls under test) via a fresh `build_conn()` with
no IP override — so every GET across every test in both files accumulated
against the SAME 127.0.0.1 IP bucket for the life of the suite run. Once
that shared bucket's count exceeds its limit, ANY subsequent GET from
*any* test trips a 429, including tests that only expect 200.

**Fix (test files only — no production code touched):** extended the
`with_unique_ip/1` helper pattern that already existed in this codebase
(for the *register/forgot-password* calls, `:auth` scope) to also cover
the conn actually used for the GET/PUT `/keybundle` and
`/keybundle/recovery` calls, in both files. Each test now gets its own
synthetic IP for the requests that matter to these two rate-limit scopes,
decoupling its own volume from every other test's.

**Proof this was a real, reproducible flake — not a hypothetical:**

```
# BEFORE the fix (git stash of the two test files), 5x full `mix test` runs:
run 1: 102 tests, 0 failures
run 2: 102 tests, 0 failures
run 3: 102 tests, 6 failures   <-- reproduced, in key_bundle_controller_test.exs
run 4: 102 tests, 0 failures
run 5: 102 tests, 0 failures

# AFTER the fix (git stash pop), 10x full `mix test` runs:
run 1..10: 102 tests, 0 failures   (10/10 stable)
```

Files changed:
- `services/api/test/matome_api_web/controllers/key_bundle_controller_test.exs`
- `services/api/test/matome_api_web/controllers/key_bundle_recovery_controller_test.exs`

## Environment limitations hit in this session (reported honestly, not papered over)

- **`flutter test --platform chrome` is broken in this environment**,
  independent of anything in this task: compiling the full web test bundle
  fails inside the `alchemist` golden-testing package
  (`AlchemistFileComparator` calling APIs — `basedir`, `getGoldenBytes`,
  `generateFailureOutput` — that don't exist on
  `flutter_test`'s installed web-goldens API in this SDK version). This
  blocks running ANY test (not just ours) as a real browser test in this
  sandbox. Confirmed with a throwaway probe test, then removed (not
  committed).
- **`connection_web.dart` cannot be imported into a plain-VM `flutter
  test`** — it transitively pulls in `web_opfs_blob_store.dart`, which
  imports `dart:js_interop` / `package:web`, neither available on the
  Dart VM test runner. Confirmed with a throwaway probe test (compile
  error: `'JSObject' isn't a type.` etc.), then removed (not committed).
  This is why `openEncryptedWebConnection`'s keybundle-down behavior is
  readable in source and unit-tested at the *component* level
  (`WebKeyBundleCache`, `WebStoreOpener`) but not exercisable as one
  end-to-end test here.
- Real-browser OPFS proof (chrome-devtools MCP) was not attempted beyond
  the above: the app's cold-start UI does not yet call
  `openEncryptedWebConnection` (per that file's own doc comment — wiring
  it in front of `appDatabaseProvider` is flagged as follow-up work, not
  done), so there is no reachable click-path in the actual app to drive
  with a real browser today. Forcing a synthetic harness around it would
  not be testing the production wiring, so I did not fabricate one.

## Carry-forward ledger (unchanged by this task, restated so it isn't buried)

- **CF-1 (OPEN):** normal-login `salt_auth` PRE-AUTH bootstrap is unresolved —
  `AuthRepository.login` still can't fetch `salt_auth` before authenticating.
  The recovery path (reset token) solved its own version of this; the
  *normal* login flow was not. The crypto primitives below it (this task's
  subject) are proven; the end-to-end unified LOGIN is not wired.
- **CF-3 (OPEN):** `kSqlCipherEnabled` stays dark; no production
  per-platform SQLCipher library is packaged for Android/iOS. This
  session's Linux round-trip (above) proves the *mechanism*; it does not
  close Android/iOS packaging or device verification.
- **CF-4 (OPEN):** plaintext-DB → encrypted-DB migration does not exist
  (media migration does, DB does not). Flipping `kSqlCipherEnabled` on a
  device with an existing plaintext `matome.sqlite` fails closed
  (SQLCipher rejects the unkeyed file) rather than migrating it.
- **CF-6 (OPEN):** media encryption flag dark — the Core pipeline is not
  yet ciphertext-aware end-to-end.
- **CF-7 (OPEN):** the live-recording segment path is still plaintext.
- **CF-8 (OPEN):** web page-level VFS is deferred; the shipped MVP is
  whole-image encrypt/decrypt, not per-page.
- **CF-9 (OPEN):** `WebOpfsBlobStore` end-to-end has not been re-proven in
  a real browser in THIS session (see environment limitations above); the
  only real-Chromium confirmation on record is from task #1860's own
  session, not independently reproduced here.
- **CF-10 (OPEN):** `ff.godMode` weakens the web CSP; unchanged by this
  task.

## Test evidence (actual counts from this session)

- `flutter test` (full suite, default — native_spike tests skipped as
  designed): **1144 passed, 34 skipped, 0 failures**.
- `flutter test --tags native_spike --run-skipped
  test/db/sqlcipher_native_spike_test.dart
  test/db/sqlcipher_encrypted_open_test.dart` (built a real SQLCipher
  `.so` first via `tool/spike_815_sqlcipher/build_libsqlcipher.sh`):
  **4 passed, 0 failures** (raw round-trip PoC + plaintext-scan +
  wrong-key-fails-closed + offline-cold-start, all against a REAL
  SQLCipher build, not a mock).
- `flutter test test/core/crypto/interop_multi_device_test.dart`:
  **2 passed, 0 failures** (new file, this task).
- `mix test` (full Elixir suite, after the CF-2 fix): **102 passed, 0
  failures**, stable across 10 consecutive runs with random seeds.
- `flutter build web`: succeeds (compiles; the wasm dry-run warning is
  informational, not an error).
