# Develop Matome

## Build the desktop app

```bash
mise install
mise run deps
mise run build
mise run studio
```

The desktop binary is `build/bin/matome-studio`.

The sign-in server default comes from `default_server` in the root
`app.toml`. Change that file before building a new package; the value is
compiled into desktop, web, and Android artifacts. A saved server choice in
the client takes precedence over the compiled default. Add a
`[platform.android]`, `[platform.web]`, `[platform.linux]`,
`[platform.macos]`, or `[platform.windows]` table with its own
`default_server` to override the root value for one target.

## Local account

Core does not seed a user. With its API on `http://localhost:7001`, run:

```bash
mise run first-login
```

The task is idempotent. It registers `matome-admin@localhost` /
`Matome67!` when the email is new, logs in when it already exists, and
leaves an organization named `matome` on that identity. For a new account,
open the emailed confirmation link in a browser, confirm the address, then
run the task again. Core's default local mailer does not deliver email
externally; configure a local SMTP relay to receive the link. Override the
API URL with `MATOME_URL`.

## Web preview

Run `mise run wasm:serve` to build the browser app and serve it on port
7002. It proxies Core on port 7001. Use the preview's own origin as the
server address to avoid cross-origin API requests.

Web builds version JavaScript URLs by content so an existing browser cache
cannot pair an older loader with a rebuilt WebAssembly module. The preview
server requires JavaScript and WebAssembly cache revalidation.

## Client behavior

The client signs in, registers accounts, resends confirmation links, and
requests password resets. Confirmation and password changes finish in the
browser; the user then signs in to the client. A pending account remains on
the confirmation screen until the user returns to sign-in. Invitation links
are accepted in the browser; the client reloads organizations when active.

After sign-in, the client lists organizations, spaces, folders, and
documents. Downloads write signed files to disk. Dragging, clicking, or
Ctrl+X/Ctrl+V moves an item; F2 renames, Del trashes a document or deletes
an empty folder after confirmation, `u` uploads, and `?` and `:` open the
keymap and command sheet. Keyboard navigation reaches every control.
Tokens stay in memory; the email, API URL, and last organization stay in
QSettings. Sign out posts logout.

## Android emulator

The local Android build is a native Qt Quick x86_64 APK
(`org.matome.studio`), rather than the WebAssembly page in Chrome. Run:

```bash
mise run android:deps
mise run android:emulator
mise run android
mise run android:install
```

The Android build compiles pinned OpenSSL 3.5.8 libraries and bundles them
with the APK so HTTPS works on devices without system OpenSSL libraries.
The source archive is checked against its SHA-256 digest. The license is
included in the APK under `assets/licenses/openssl.txt`.

`android:install` needs a running `Pixel_7_API_34` AVD. Start it with
`mise run android:emulator`, which uses `-gpu host`; SwiftShader paints
Qt Quick rectangles as one triangle. The sign-in URL defaults to the value
in `app.toml`; the server field can be changed for a local Core.

See [testing](testing.md) for the local checks and [releasing](releasing.md)
for the publication process. See [web deployment](web-deployment.md) to run
the published web app in a local container or deploy it with Dokploy.
