# matome-app

Qt 6 Quick desktop client for Matome Core.

## Build

```bash
mise install
mise run deps
mise run build
mise run studio
```

The studio binary is `build/bin/matome-studio`.

## Install

Download the latest Matome app for your device:

| Platform | Download |
| --- | --- |
| Windows (x86_64) | [Installer](https://github.com/matome-org/matome-app/releases/latest/download/matome-windows-x86_64.exe) |
| macOS (Intel and Apple silicon) | [DMG](https://github.com/matome-org/matome-app/releases/latest/download/matome-macos-universal.dmg) |
| Linux (x86_64) | [AppImage](https://github.com/matome-org/matome-app/releases/latest/download/matome-linux-x86_64.AppImage) |
| Android (arm64) | [APK](https://github.com/matome-org/matome-app/releases/latest/download/matome-android-arm64.apk) |

See [installation and removal instructions](docs/installation.md) for each
platform. All versions and checksums are on the [releases page](https://github.com/matome-org/matome-app/releases).

## Releases

See [the local release process](docs/releasing.md).

## License

Matome is licensed under the [MIT License](LICENSE), Copyright (c) 2026
MATOME. Bundled fonts retain their own licenses in [src/gui/fonts](src/gui/fonts).

## Local Core account

Core does not seed a user. With the API on `http://localhost:7001`:

```bash
mise run first-login
```

That is idempotent. It registers `matome-admin@localhost` / `Matome67!`
when the email is new, logs in when it already exists, and leaves an
organization named `matome` on that identity. A new account must confirm
its email first: the task prompts for the emailed token, or accepts it in
`MATOME_CONFIRMATION_TOKEN`. Core's default local mailer does not deliver
email externally; configure a local SMTP relay to receive the token.
Override the URL with `MATOME_URL`.

The studio signs in, registers, confirms new accounts with the emailed
token, can resend that token, requests a password reset, and sets a
new password against those Core routes. An account waiting for email
confirmation stays on the confirmation form until Core returns a new
session. After sign-in it lists organizations, spaces, then folders and
documents. Download writes the signed file to disk. Drag, click, or
Ctrl+X/Ctrl+V move a row; F2 renames, Del trashes a document or, once
confirmed, deletes an empty folder for good, `u` uploads, `?` and `:`
open the keymap and command sheet. The keyboard still reaches
every control. Tokens stay in memory; email, URL and last org stay in
QSettings. Sign out posts logout.

Core emails a reset token. The reset form accepts that token and can also
extract one from a full reset link.

## Tests

```bash
mise run lint
mise run test
mise run test:desktop
mise run test:web
mise run test:mobile
```

`test` is the fast gate: core unit tests, the offscreen desktop window,
and line coverage of every source listed in `.scripts/coverage.py`, at
least 90% per file and in total.

E2e is split by platform because each surface is a different host:

| Task | Host | What it proves |
| --- | --- | --- |
| `test:desktop` | Qt offscreen (`tst_studio`), then the built `matome-studio` | Keyboard, mouse, touch, drag and drop, uploads, errors, and the narrow drawer by QML `objectName` against FakeCore; then a smoke of the real binary's `main.cpp` wiring (fonts, translator, icon, saved settings, sign-in) through a probe plugin |
| `test:web` | Chromium: desktop 1280×800 (mouse, keyboard) and Pixel 7 (touch) | Every web scenario against FakeCore, by real browser input aimed through a test-only probe (`tests/e2e/web/probe`) linked into an e2e WASM build under `build-tests/web-e2e`; then the shipped `build-wasm` boots untouched |
| `test:mobile` | Pixel_7_API_34 APK + uiautomator | Every Android scenario, each from a clean install against its own FakeCore on a free port (`10.0.2.2` from the emulator), by taps on the real Qt Accessible names, files chosen in the real DocumentsUI picker |

`test:e2e` runs all three. Web needs `mise run wasm` once. Mobile needs
the Android toolchain; it builds and installs the APK, boots
Pixel_7_API_34 when no emulator is up (and shuts down only that one),
and puts back every device setting a scenario changes. In the browser
a screen reader hears the buttons, fields, crumbs, and menus by their
Accessible names, but Qt's WASM accessibility renders no page element
for list and tree items, so the rows are silent there; `test:web`
asserts only what the platform exposes, and `test:mobile` proves the
names on Android.

Every e2e suite talks to FakeCore, never to a real Core:
`mise run fakecore` (or `.scripts/fakecore.sh --port N`, `0` for any
free port) serves it on `127.0.0.1:7011`. Its first stdout line,
`fakecore http://127.0.0.1:<port>`, says it is ready. Suites reset,
seed, break, and inspect it over HTTP under `/__e2e/` (`reset`, `seed`,
`fail`, `release`, `state`; see `tests/FakeCore.h`).

## Android APK (emulator)

This is a native Qt Quick APK (`org.matome.studio`), not the WASM
page in Chrome. The emulator ABI is x86_64.

```bash
mise run android:deps
mise run android:emulator
mise run android
mise run android:install
```

`android:install` needs a booted AVD (`Pixel_7_API_34`). Boot it
with `-gpu host` (`mise run android:emulator`): SwiftShader paints
Qt Quick rectangles as one triangle. The sign-in URL defaults to
`http://10.0.2.2:7001` (the host's Core, seen from the emulator).
Core must be up on the host.
