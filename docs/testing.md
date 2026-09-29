# Test Matome

Test builds read `MATOME_TEST_DEFAULT_SERVER` from the root `.env`. When that
file is absent, they use the local value in the root `.env.example`. Copy the
example to `.env` to change the test URL or port. Only localhost,
127.0.0.1, and the Android emulator host 10.0.2.2 are accepted; test builds
cannot use the public server from `app.toml`.

Run the local gate with:

```bash
mise run verify
```

It checks QML warnings and translation completeness, runs the core unit
tests and offscreen desktop suite, and checks line coverage of every source
listed in `.scripts/coverage.py` at a minimum of 90% per file and in total.

The test suites are also available individually:

```bash
mise run lint
mise run test:core
mise run test:proxy
mise run test
mise run test:desktop
mise run test:web
mise run test:mobile
mise run test:e2e
```

`test:core` runs the C++ unit suite, including organization administration,
without the studio, platform e2e suites, or the combined coverage gate.

`test:proxy` checks that the local web preview forwards compressed Core
responses with their encoding headers, including API errors.

`test:desktop` exercises keyboard, mouse, touch, drag and drop, uploads,
errors, and the narrow drawer against FakeCore by QML `objectName`. It then
smokes the real `matome-studio` binary's `main.cpp` wiring through a probe
plugin: fonts, translator, icon, saved settings, and sign-in.

`test:web` runs Chromium at desktop 1280×800 and Pixel 7 sizes. It drives
real browser input against FakeCore through a test-only probe linked into a
WebAssembly build under `build-tests/web-e2e`, then checks that the shipped
`build-wasm` boots untouched. Run `mise run wasm` once before this suite.

`test:mobile` uses a `Pixel_7_API_34` emulator and uiautomator. Each scenario
starts from a clean APK install and its own FakeCore on a free port, reached
through `10.0.2.2`. It uses the app's accessible names and Android's real
DocumentsUI file picker. It builds and installs the APK, boots the emulator
when needed, and restores device settings changed by the scenarios.

`test:e2e` runs all three platform suites. The mobile suite requires the
Android toolchain. In the browser, Qt's WebAssembly accessibility exposes
buttons, fields, breadcrumbs, and menus, but no page elements for list and
tree items. The web suite asserts what that platform exposes; the mobile
suite checks accessible names for those rows.

Every end-to-end suite uses FakeCore instead of a real Core instance. Run
`mise run fakecore` to serve it on `127.0.0.1:7011`. Its first stdout line,
`fakecore http://127.0.0.1:<port>`, reports the bound port. Suites reset,
seed, break, and inspect it through `/__e2e/` (`reset`, `seed`, `fail`,
`release`, `state`; see `tests/FakeCore.h`).
