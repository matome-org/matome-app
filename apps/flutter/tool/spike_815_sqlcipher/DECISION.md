# Spike #815 / task #1847 — SQLCipher keyed by raw DEK: go/no-go

**Plan:** p1-unified-login-encryption (#131), Wave 0 gate.
**Blocks:** `.docs/internal/at-rest-key-flow.md` §7 ("flip Native connection to
SQLCipher keyed by DEK once the `sqlcipher_flutter_libs` build conflict is
resolved").

## Verdict: GO — with the hand-rolled connection, not the stock plugin

The mechanism (`package:sqlite3` + `open.overrideFor` + a SQLCipher-built
library + `PRAGMA key = "x'<hex>'"`) round-trips correctly on Linux desktop.
The **stock `sqlcipher_flutter_libs` plugin does not build on this distro**
(confirmed, not assumed — see below), which matches and confirms the existing
`pubspec.yaml` / `connection_native.dart` risk note. The fix is exactly the
"hand-rolled native connection" alternative already named in the AC, not a
namespaced fork of the stock plugin.

## Evidence

### 1. Why the stock plugin is a no-go here (confirmed root cause)

`sqlcipher_flutter_libs-0.6.8/linux/CMakeLists.txt`:
```cmake
option(OPENSSL_USE_STATIC_LIBS "..." ON)
find_package(OpenSSL REQUIRED)
```
This host's OpenSSL package ships **shared libraries only**:
```
$ pacman -Ql openssl | grep -E '\.so$|\.a$'
openssl /usr/lib/libcrypto.so
openssl /usr/lib/libssl.so
openssl /usr/lib/engines-3/afalg.so
...
# no libcrypto.a / libssl.a anywhere
```
`find_package(OpenSSL)` with `OPENSSL_USE_STATIC_LIBS ON` requires the `.a`
archives; on Arch (and most rolling-release distros that don't ship a
`-static` OpenSSL package) that lookup fails before compilation even starts.
This is the exact collision the pubspec comment predicted — now empirically
confirmed against this machine's actual package set, not just theorized.

(Separately, the pubspec also notes the Android manifest-merger collision:
`sqlcipher_flutter_libs` and `sqlite3_flutter_libs`, force-pulled by
`drift_flutter`, both declare the plugin namespace
`eu.simonbinder.sqlite3_flutter_libs`. Not re-verified here — no Android
build attempted in this spike — but it's an independent, already-documented
failure mode of the same "co-build the stock plugins" approach.)

### 2. Hand-rolled connection round-trip — Linux desktop (PROVEN)

Built a throwaway SQLCipher 4.7.0 (community) shared library from source
**already vendored in this repo's own dependency tree**
(`node_modules/expo-sqlite/vendor/sqlcipher/sqlite3.c` — Expo's RN SQLite
plugin ships the full SQLCipher amalgamation under an `exsqlite3_*` symbol
prefix). Renamed the prefix back to standard `sqlite3_*` names and compiled
against the system's **shared** `libcrypto.so.3` — i.e. the exact opposite of
the stock plugin's static-OpenSSL requirement:

```
$ gcc -shared -fPIC -O2 \
    -DSQLITE_HAS_CODEC \
    -DSQLITE_EXTRA_INIT=sqlcipher_extra_init \
    -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown \
    -DSQLITE_THREADSAFE=1 -DSQLITE_TEMP_STORE=2 -DHAVE_STDINT_H \
    -DSQLITE_ENABLE_FTS5 \
    sqlite3.c -o libsqlcipher_poc.so -lcrypto
$ ldd libsqlcipher_poc.so
    libcrypto.so.3 => /usr/lib/libcrypto.so.3   # shared, not static
    ...
```
Reproducible via `build_libsqlcipher.sh` in this directory.

Proved the full AC round trip through `package:sqlite3` (the same package
`connection_native.dart` already depends on) with `open.overrideFor`:

```
open -> PRAGMA key = "x'<32-byte hex DEK>'" -> assert cipher_version -> write row -> close
reopen -> PRAGMA key(same DEK) -> assert cipher_version -> read row back -> match
reopen WITHOUT a key  -> SqliteException(26) "file is not a database" (refused)
reopen WITH WRONG key -> SqliteException(26) "file is not a database" (refused)
```

Output tail (standalone script, `poc.dart`):
```
--- PRAGMA cipher_version (open #1, correct key) ---
4.7.0 community
...
--- PRAGMA cipher_version (open #2 / reopen, correct key) ---
4.7.0 community
--- Row read back after reopen ---
{"id":1,"note":"sqlcipher-roundtrip-ok"}
--- Negative control: open WITHOUT PRAGMA key ---
Refused as expected (encrypted, not plaintext): SqliteException(26): while
preparing statement, file is not a database (code 26)
2026-07-03 ...: ERROR CORE sqlcipher_page_cipher: hmac check failed for pgno=1
--- Negative control: open WITH WRONG key ---
Refused as expected (wrong key rejected): SqliteException(26) ...
=== ALL ROUND-TRIP + NEGATIVE-CONTROL CHECKS PASSED ===
```

This exact flow is now also a checked-in, opt-in **flutter test**
(`test/db/sqlcipher_native_spike_test.dart`, tag `native_spike`), using
`DbEncryptionKeyManager.pragmaKeyStatement` from production code, so the
proof lives in the same test harness the rest of the suite runs under:
```
$ MATOME_SQLCIPHER_POC_LIB=<built .so> flutter test --tags native_spike \
    --run-skipped test/db/sqlcipher_native_spike_test.dart
...+1: All tests passed!
```
Default `flutter test` (no `--tags`) skips it — confirmed — so it does not
affect CI until a real build pipeline exists.

### 3. Mobile (Android) — NOT run, explicitly unverified

No Android emulator/device is available on this host (see plan constraints).
The stock-plugin manifest-merger collision (§1, Android namespace clash) is
**documented, not reproduced** — no `flutter build apk` was attempted in this
spike. **This is a real gap**, not a paper-over: someone with a device/CI
runner must still run the equivalent open→key→write→close→reopen→read
round-trip on Android before #815 is fully closed. The Dart-level mechanism
(package:sqlite3 + `open.overrideFor(OperatingSystem.android, ...)`) is the
same one just proven on Linux, which lowers — but does not eliminate — that
risk.

## Decision: hand-rolled native connection (not a re-namespaced sqlcipher_flutter_libs fork)

Two options were on the table per the AC:

1. **Hand-rolled native connection.** Drop `drift_flutter`'s automatic native
   setup for the encrypted path; open the SQLite handle directly via
   `package:sqlite3` (`open.overrideFor` per platform) against a SQLCipher
   build, same as this spike, then hand the opened `Database` to
   `NativeDatabase.opened(...)` (drift's escape hatch for a pre-opened
   connection) instead of `driftDatabase(...)`.
2. **Namespaced sqlcipher build.** Fork `sqlcipher_flutter_libs` to rename its
   Android plugin namespace and drop `OPENSSL_USE_STATIC_LIBS` on Linux, then
   keep using `drift_flutter` unmodified.

**Chosen: (1) hand-rolled connection.** Reasons:
- It is what this spike actually built and proved, end to end, on real
  package versions already in `pubspec.yaml` (`sqlite3: 2.9.4`, no new
  dependency needed for the mechanism itself).
- Maintaining a namespace-patched fork of a third-party Flutter plugin per
  platform (Android *and* Linux, per §1) is more ongoing maintenance than
  owning ~30 lines of connection-construction code, and re-forks on every
  upstream `sqlcipher_flutter_libs` release.
- `connection_native.dart` already documents this exact recipe
  (`kSqlCipherEnabled` doc comment: *"override package:sqlite3 open to the
  SQLCipher build in isolateSetup; PRAGMA key + cipher_version assertion in
  setup"*) — this spike validates that plan rather than introducing a new one.
- The production packaging question this decision does NOT answer yet: where
  the real (non-throwaway) SQLCipher `.so`/`.aar`/framework per platform comes
  from at build time (Android Gradle task, Linux CMake step, etc.). That is
  implementation work for the next wave, scoped separately from this
  spike — the spike's job was only to de-risk the *mechanism*, which is done.

## What flips `kSqlCipherEnabled = true`

Still not flipped in this change. Remaining before it can flip:
1. A real (non-throwaway, checked-into-build, not hand-copied-from-node_modules)
   SQLCipher static/shared library per target platform, produced by a build
   step owned by this repo (mirroring `build_libsqlcipher.sh` but wired into
   Gradle/CMake, not run ad hoc).
2. The Android round-trip actually run on a device/emulator (open gap above).
3. `openPlatformConnection`'s encrypted branch swapped from `driftDatabase(...,
   native: DriftNativeOptions(setup: ...))` to the hand-rolled
   `NativeDatabase.opened(...)` construction this spike validates (today's
   code still uses `drift_flutter`'s `setup` hook, which is the very
   mechanism whose co-build was in question — the AC is about the *keying*
   mechanism working, which it does, but the connection construction still
   needs the swap for encryption to be reachable in a real build).
