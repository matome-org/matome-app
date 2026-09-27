# Develop Matome

## Build the desktop app

```bash
mise install
mise run deps
mise run build
mise run studio
```

The desktop binary is `build/bin/matome-studio`.

## Local account

Core does not seed a user. With its API on `http://localhost:7001`, run:

```bash
mise run first-login
```

The task is idempotent. It registers `matome-admin@localhost` /
`Matome67!` when the email is new, logs in when it already exists, and
leaves an organization named `matome` on that identity. A new account must
confirm its email first: the task prompts for the emailed token, or accepts
it in `MATOME_CONFIRMATION_TOKEN`. Core's default local mailer does not
deliver email externally; configure a local SMTP relay to receive the
token. Override the API URL with `MATOME_URL`.

## Client behavior

The client signs in, registers accounts, confirms new accounts with an
emailed token, resends that token, requests password resets, and accepts a
new password. An account waiting for email confirmation stays on the
confirmation form until Core returns a new session. A reset form accepts a
token or extracts one from a full reset link.

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

`android:install` needs a running `Pixel_7_API_34` AVD. Start it with
`mise run android:emulator`, which uses `-gpu host`; SwiftShader paints
Qt Quick rectangles as one triangle. The sign-in URL defaults to
`http://10.0.2.2:7001`, the host's Core as seen from the emulator. Core
must be running on the host.

See [testing](testing.md) for the local checks and [releasing](releasing.md)
for the publication process.
