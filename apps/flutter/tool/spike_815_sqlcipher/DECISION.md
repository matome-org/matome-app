# Linux SQLCipher packaging (#815, task #2152)

## Production-shaped decision

The Linux Flutter build now turns the existing `sqlite3_flutter_libs_plugin`
target into the app's SQLCipher implementation. It downloads the SQLCipher
4.10.0 community amalgamation from the versioned upstream artifact used by
`sqlcipher_flutter_libs` 0.6.8, verifies its SHA-512 before compilation, links
to shared OpenSSL, and installs the result as
`bundle/lib/libmatome_sqlcipher.so`.

Reusing that target is intentional: `drift_flutter` requires
`sqlite3_flutter_libs`, whose Linux plugin would otherwise compile and load
stock SQLite for Matome. Replacing its source means the app database has one
implementation and no fallback. GTK/glycin/tinysparql may independently load
the host `libsqlite3`; Owner decision #107774 permits that internal GUI-stack
use and excludes rebuilding or namespacing GTK.

The SQLCipher target links with `-Wl,-Bsymbolic`. This binds references made
inside `libmatome_sqlcipher.so` to definitions in that same DSO, preventing ELF
symbol interposition from redirecting SQLCipher internals to a host
`libsqlite3` loaded by GTK. Public SQLite symbols remain available to the exact
handle opened by package:sqlite3.

## Android package and isolation

Android does not add `sqlcipher_flutter_libs`: that plugin intentionally uses
the same `eu.simonbinder.sqlite3_flutter_libs` namespace as the stock plugin
that `drift_flutter` pulls transitively. Instead, the app has a direct fixed
runtime dependency on `net.zetetic:sqlcipher-android:4.10.0` from Maven Central.
The app's `preBuild` runs `verifySqlCipherArtifact` and requires AAR SHA-256
`cc60b1a40d023bec06a1e56740db7172d2516668570140cd9de00ca90f84cd9f`.
Its AAR packages `libsqlcipher.so`; `connection_native.dart` overrides
`package:sqlite3`'s Android opener with `DynamicLibrary.open('libsqlcipher.so')`
before any Matome DB open. A missing DSO throws. There is no lookup of
`libsqlite3.so`, process symbols, or fallback opener on the encrypted path.

The stock `libsqlite3.so` pulled by `sqlite3_flutter_libs` may coexist for other
framework/plugin uses. It is not a candidate for Matome because the explicit
Android override only returns the distinct SQLCipher handle and the subsequent
`cipher_version` plus decrypt probe reject any non-codec or incorrectly keyed
handle.

Reproduce the Android proof with:

```sh
flutter build apk --debug --dart-define=MATOME_SQLCIPHER=true
flutter test integration_test/sqlcipher_android_bundle_test.dart \
  -d emulator-5554 --dart-define=MATOME_SQLCIPHER=true
bash tool/spike_815_sqlcipher/run_android_restart_gate.sh emulator-5554
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -E 'lib(sqlcipher|sqlite3)\\.so'
./android/gradlew -p android :app:dependencies --configuration debugRuntimeClasspath
```

The restart driver builds a test-only Flutter target guarded by
`MATOME_SQLCIPHER_RESTART_GATE=true`, installs that APK exactly once, and clears
data only before phase 1. It waits for a durable write result, verifies the live
writer PID, executes `am force-stop`, verifies that PID is gone, then relaunches
the same installed activity. Phase 2 must retain the same package marker, report
a distinct PID, decrypt the sentinel, and pass the ciphertext scan. Recreated
package data starts another write phase with a different marker/PID and makes
the host command fail. The harness is not referenced by the normal app target
and cannot enter a normal release build.

At runtime, `loadBundledLinuxSqlCipher` resolves the DSO relative to
`Platform.resolvedExecutable` and installs an `open.overrideFor` before the
first encrypted open. A missing DSO, unsupported platform, empty
`PRAGMA cipher_version`, wrong key, or corrupt page throws; none selects a
system or stock SQLite fallback.

## Host and build dependencies

- Flutter 3.44.6 / Dart 3.12.2 or the repository's current mise toolchain.
- CMake 3.13+, a C/C++ compiler, pkg-config, and GTK 3 development files (the
  standard Flutter Linux prerequisites).
- OpenSSL 3 development headers and shared `libcrypto` (`openssl` on Arch,
  `libssl-dev` on Debian/Ubuntu).
- HTTPS access at CMake configure time to the pinned SQLCipher artifact. The
  build fails if download, TLS validation, or SHA-512 validation fails.

## Reproducible gate

```bash
cd apps/flutter
flutter build linux --release --dart-define=MATOME_SQLCIPHER=true
flutter drive --profile -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/sqlcipher_linux_bundle_test.dart \
  --dart-define=MATOME_SQLCIPHER=true \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false
readelf -d build/linux/x64/release/bundle/lib/libmatome_sqlcipher.so
ldd build/linux/x64/release/bundle/lib/libmatome_sqlcipher.so
```

`flutter drive` compiles the integration target into and runs it inside a real
AOT-profile Flutter Linux executable, not `flutter_tester` (Flutter Driver does
not support Release mode). The preceding production Release build uses the
same CMake target and bundled DSO. The gate checks
the exact bundled DSO mapping through `/proc/self/maps`, verifies the ELF
`SYMBOLIC` flag, and does not read `MATOME_SQLCIPHER_POC_LIB`. It proves
`cipher_version`, encrypted Drift write, close/reopen/read, wrong-key and
tamper rejection, and scans for `SQLite format 3` and a known sentinel.

## Historical spike

Task #1847 established the go decision with a manually built SQLCipher 4.7.0
amalgamation and `MATOME_SQLCIPHER_POC_LIB`. It proved raw-DEK keying,
`cipher_version`, round-trip, and no-key/wrong-key rejection. Task #1853 then
wired that mechanism into `openEncryptedNativeConnection`. Task #2152 replaces
the deleted PoC script and opt-in `native_spike` tests with the CMake package
and real-process gate documented above. Android and other operating systems
remain explicitly unverified and out of scope.
