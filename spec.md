# Matome QML client

Specification for the open-source desktop client. This repository is
greenfield (`fresh-start`). The Phoenix JSON API stays private in
`matome-core`. The old Flutter app is not a source, except the **Eva
gold palette** copied from `development` (`apps/flutter/lib/core/theme/app_theme.dart`).

This file is the brief to start development. It is not code.

---

## 1. What this is

A **Qt 6 Quick** window that talks to Matome Core over HTTP.

- **Public:** this repo (QML, C++ HTTP client, packaging).
- **Private:** Core (auth, storage, grants, events, add-ons).
- The protocol is visible in the client. “Private API” means the
  server is not open source, not that URLs or JSON are secret.

The product is a **company document manager**: sign in, pick an
organization, work in spaces and folders, upload and download files,
invite people, and (later) rules, webhooks and add-ons.

---

## 2. What this is not

- Not a rewrite of the Flutter tree. No Dart, no Material 3, no
  Flutter fonts, no Flutter navigation.
- Not a wrapper around a CLI. The window and a future CLI both sit on
  the same C++ core. The GUI never `QProcess`es itself.
- Not Omarchy-only. Light and Dark are the **Eva brand tables**
  (gold on warm paper / warm charcoal). System follows the desktop:
  Omarchy `colors.toml` when that file is there, otherwise the OS
  light/dark mapped onto Eva. The Theme object still looks like
  `omafiles` (QML singleton, roles, `fill()`, contrast helpers).
- Not a search product until Core ships search. Listing is per space
  and folder.
- Not realtime. Events are pulled. No WebSocket.
- Not checkout. Catalogue and usage are read-only until Commercial
  exists.
- Not SSO. Email, password, refresh, `mat_…` tokens.

---

## 3. Practices taken from `/home/howl/Projects/omacon`

These apps are the local Qt canon: `omafiles`, `omastore`, `omahouse`,
`omabench`, `omapixel`, `omawrite`. Copy the **shape**, not the
filesystem-tag product.

### 3.1 One core, thin fronts

`omafiles.pro` / omabench architecture: a static library with no Qt
Quick, then a studio (and optionally a CLI) on top.

```
src/core     libmatomecore     HTTP, session, models, commands
src/cli      matome            JSON in, JSON out (PATH, agents)
src/gui      matome-studio     QQmlApplicationEngine, QML
```

Everything is **C++ and QML**. No Rust crate, no FFI. `libmatomecore`
is Qt Core + Network only. The studio adds Quick. The CLI links the
same static library.

If a behaviour lives only in QML JavaScript, the CLI cannot have it
and tests cannot run it headless. Mutations and HTTP stay in C++.

### 3.2 QML types the build registers

`QML_ELEMENT` / `QML_SINGLETON`, `CONFIG += qmltypes`,
`QML_IMPORT_NAME = matome`. `main.cpp` does **not**
`qmlRegisterType` or `setContextProperty`. Context properties are
invisible to `qmllint`; a singleton is a type the linter and the
engine share.

Reference: `omafiles/src/studio/main.cpp`, `Theme.h`.

### 3.3 Theme is a singleton, not a context property

Roles as `Q_PROPERTY` (`background`, `surface`, `foreground`,
`accent`, …), `Q_INVOKABLE fill(role, alpha)`, and (from omastore)
`contrast()` plus a readable-text helper so muted never prints
body text under 4.5:1. A `mode` property is `light`, `dark`, or
`system` — see §4.

QML: `color: Theme.background` — never a hex in a screen file.

### 3.4 Controls.Basic, not Material

`import QtQuick.Controls.Basic`. We paint chrome. Material would
fight the Eva surfaces.

### 3.5 Keyboard is a first-class surface

omafiles: one `handleKey` on the window; lists draw and report
clicks; they do not own keys. Everything a mouse reaches, the
keyboard reaches. `?` is the keymap. `:` is the command palette.

The palette is **not** named `palette` in QML (`Item.palette` is Qt’s
colour group). omafiles/omastore use `sheet`. Feed it the **same**
command table the buttons use — a command that exists only in the
palette is a bug (omabench R-equivalent).

### 3.6 Focusable chrome

Shared `FocusableControl.qml`: tab focus, activation, focus ring,
hover wash via `Theme.fill`. Screens compose it; they do not
reimplement rings.

### 3.7 Tooling

- **Qt 6** + **qmake** + **mise** (`deps`, `build`, `studio`, `test`,
  `lint` = qmllint with warnings fatal, `i18n` = lupdate over C++ and
  QML, `verify` / `check`).
- Copy `omabench/qmake/layout.pri`: **no in-tree builds**; moc/rcc/obj
  under `.qmake/`.
- `pragma ComponentBehavior: Bound` on QML files.
- Tests of core without a window. Studio tests drive
  `QQmlApplicationEngine` **offscreen** (`QT_QPA_PLATFORM=offscreen`)
  with real key events — `omafiles/tests/tst_studio.cpp`.
- There is **no shared oma Qt library**. Copy the pattern into this
  repo; do not add a third-party kit.
- MIT, `LICENSE`, desktop entry + SVG under `packaging/`. Arch recipe
  later. English in published packaging (omarchy-pkgs rule).

### 3.8 Network in C++ only (omastore)

`omastore/src/studio/AppCatalog.cpp` is the local HTTP example:
`QNetworkAccessManager`, bounded body size, same-origin redirects,
SHA-256 of downloaded blobs, disk cache. Matome Core calls follow
that discipline. QML never fetches.

Signed MinIO/S3 PUTs (upload) and GETs (download) are the exception
to “only Core origin”: they hit the URL Core returned, with no extra
headers the storage did not ask for.

### 3.9 What not to copy

- Using Omarchy `colors.toml` as the **only** look. Light and Dark
  stay Eva. The watcher exists only in System when Omarchy is
  present.
- A 3k-line `Main.qml`. Split screens and chrome from day one.
- Putting HTTP in QML `XMLHttpRequest`.
- Generating 150 OpenAPI operations before the first window runs.

---

## 4. Brand colours (from Flutter `development`)

Source of truth for numbers: Eva Design tokens as ported in
`MatomeColors`. Gold is the **fill** accent. It is **not** a text
colour on light surfaces (~1.9:1 on paper). Words on gold use
`onAccent`; gold as words uses `accentText`.

No pure `#FFFFFF`. Surfaces are warm, tinted toward the gold hue.

### Light

| Role | Hex | Notes |
| --- | --- | --- |
| `accent` | `#E1B346` | Brand gold fill |
| `accentDark` | `#B98A1F` | Pressed / dark filled accent |
| `accentSoft` | `#F6E8C0` | Wash |
| `accentText` | `#8B6A29` | Gold as text (AA on paper) |
| `onAccent` | `#221E16` | Text/icons on gold fill |
| `background` | `#F6F4EF` | Scaffold |
| `surface` | `#FDFCF9` | Cards, panels |
| `border` | `#E7E2D7` | Hairlines |
| `textPrimary` | `#221E16` | Body |
| `textSecondary` | `#585249` | ~6:1 |
| `textMuted` | `#655D4F` | AA on warm surface |
| `subtleFill` | `#1A1712` @ 6% | `0x0F1A1712` |
| `subtleFillStrong` | `#1A1712` @ 10% | `0x1A1A1712` |
| `failed` | `#B23A2E` | Error fill and error text |

### Dark

| Role | Hex | Notes |
| --- | --- | --- |
| `accent` | `#E1B346` | Still the brand gold |
| `accentSoft` | `#3A2D10` | |
| `accentText` | `#E1B346` | Gold reads on charcoal |
| `onAccent` | `#221E16` | |
| `background` | `#1A1714` | |
| `surface` | `#252119` | |
| `border` | `#38322A` | |
| `textPrimary` | `#F4F1E9` | |
| `textSecondary` | `#C4BCAD` | |
| `textMuted` | `#AAA08D` | |
| `subtleFill` | `#F4F1E9` @ 8% | `0x14F4F1E9` |
| `subtleFillStrong` | `#F4F1E9` @ 16% | `0x29F4F1E9` |
| `failed` | `#FF6B75` | |

### Space accents (same in both modes)

Low-chroma set so spaces differ without fighting the gold.

| Index | Role | Hex |
| --- | --- | --- |
| 0 | `spaceGold` | `#C8A24E` |
| 1 | `spaceGreen` | `#7E9B6E` |
| 2 | `spaceBlue` | `#6E86A8` |
| 3 | `spaceOrange` | `#C68A5E` |
| 4 | `spaceRose` | `#BC8497` |
| 5 | `spacePurple` | `#9587AE` |
| 6 | `spaceTeal` | `#6FA39A` |
| 7 | `spaceRed` | `#C2705F` |

`spaceColor(i) = palette[i % 8]`.

### Theme object in C++

Implement as `matome::Theme` QML singleton with the roles above
plus:

- `QString mode` — `light` | `dark` | `system` (persisted)
- `bool dark` — resolved: Eva dark table, or Omarchy background
  luminance, or OS color scheme
- `QColor fill(const QColor &role, qreal alpha)`
- `qreal contrast(a, b)` (WCAG 1–21)
- `QColor readable(wanted)` — nudge until ≥ 4.5:1 on `background` /
  `surface` (omastore: Omarchy `muted` is often a wash, not text)

Typography and spacing are **not** imported from Flutter. They follow
the landing page (`matome-landing`): Inter for UI text, Newsreader for
titles and the slogan, Cormorant Garamond for the wordmark, Noto Sans /
Serif JP (subset: kana + JIS level 1) behind them and first when the
language is Japanese. The fonts ship in `src/gui/fonts` (OFL) and
`Theme` exposes them as type tokens (`eyebrow`, `caption`, `body`,
`bodyLarge`, `button`, `link`, `heading`, `title`, `slogan`,
`display`), next to motion (`ease`, `fast`, `base`, `slow`), spacing
(`gapXs`…`gapXxl`), size (`iconS`/`iconM`/`iconL`,
`controlS`…`controlXl`, `rowDense`/`rowTouch`, `measure`, `column`) and
shape (`rounding`, `pill`, `inset`) tokens. QML never spells a size,
family, weight, radius, or duration.

The explorer keeps the landing's voice without losing density: the マ
mark heads the top bar as the way home (the breadcrumb starts below it),
a location header sets the place's name in the serif title under a gold
eyebrow with the item count beside it, and empty, loading, and error
lists show the landing's drawn pages over a short serif italic phrase. The
list, sidebar, and toolbar stay in Inter; only "New" is gold, the other
actions are quiet icons. Selection is a gold-soft wash, the keyboard
cursor a gold hairline, and row washes stand `inset` clear of a panel's
edge (flush when the desktop's corners are square). Colours bind straight
to `Theme`, so the one crossfade on a mode switch moves everything; hover
eases a wash's opacity, never a colour.

### Languages: pt-BR, en, ja

English is the source; `src/gui/i18n/matome_pt_BR.ts` and
`matome_ja.ts` carry the rest, in the landing's words (its slogan, its
calm). qmake's `lrelease` + `embed_translations` compile them into
`:/i18n/` for desktop, WebAssembly, and Android alike; the build stops
when lrelease is missing, and `mise run verify` stops while any string is
unfinished. `mise run i18n` refreshes the files.

`Theme.language` is the one owner. It resolves like the landing: the
saved choice (`theme/language` in QSettings), else the first of
`QLocale::system().uiLanguages()` we speak (the browser's languages on
WebAssembly), else English. Setting it saves it, makes its locale the
default (sizes and numbers), swaps the translator, and retranslates the
engine; Japanese also puts Noto JP first and sets the slogan upright.
Session hears the translator change and retitles its commands (titles
are English in the table, translated when read). `Theme.languages` and
`src/gui/Languages.h` are the one list: the sign-in screen's
`PT · EN · 日本語`, the account menu, and the `lang-*` commands.

### Modes: light, dark, system

The settings chrome offers three choices. Default is `system`.

| Mode | Colours |
| --- | --- |
| `light` | Eva light table in this section. Gold fill. |
| `dark` | Eva dark table. Gold fill on warm charcoal. |
| `system` | See below. |

**System on Omarchy.** Present when
`$XDG_STATE_HOME/omarchy/current/theme/colors.toml` exists
(`XDG_STATE_HOME` defaults to `~/.local/state`). Read it the way
`omafiles` / `omastore` / `omahouse` do: `background`, `foreground`,
`accent`, `muted`/`urgent`, derive `panel` / `sunken` / `line` /
`dim`. Watch the file (theme switches rename over the symlink).
Corners follow the same switch: with Omarchy, Hyprland's `rounding`
(looknfeel) for every surface and button; without it, soft 8 px
surfaces and pill buttons, as on the landing.

Map onto Matome roles:

- `textPrimary` ← `foreground`
- `background` / `surface` ← `background` and derived panel
- `accent` ← Omarchy accent (**fill**, never body text)
- `onAccent` / `accentText` ← `readable()` on that accent
- `failed` ← `urgent` if it clears AA, else Eva `failed` for the
  resolved dark/light
- Space accents stay the Eva eight. Omarchy has one accent; spaces
  still need a set.

If the file vanishes mid-session, fall through to OS light/dark
without changing `mode`.

**System off Omarchy.** No `colors.toml`. `QGuiApplication` /
`QStyleHints::colorScheme` (and `colorSchemeChanged`) picks Eva
light or Eva dark. Same path on Windows/macOS/other Linux.

QML never branches on Omarchy. It only binds `Theme.*`. Detection
and watching live in C++.

---

## 5. HTTP client (core)

Machine contract: Core `GET /openapi`. Human table:
`matome-core/docs/endpoints.md`. Judgement: `docs/api.md`.

### 5.1 Session

- `POST /api/auth/register` and `login` return
  `access_token`, `refresh_token`, `user`.
- Refresh on 401 once; logout on refresh failure.
- `GET /api/auth/me` has no org.
- Tokens live in the **platform secret store** (QtKeychain), keyed by
  profile id, never in plaintext QSettings. QSettings holds the
  profile list, each profile's `apiBaseUrl` and `last_org_id`, plus
  `theme.mode`. See §5.7.

### 5.2 Every org call names the org

Path prefix `/api/v1/organizations/:org_id`. The server does not
infer org from email. The client holds `currentOrgId` and builds
URLs from it.

Bootstrap without org: list/create organizations, event catalogue,
add-on catalogue, accept invitation, `me`.

### 5.3 Headers the wrapper owns

| Header | When |
| --- | --- |
| `Authorization: Bearer` | All authenticated routes |
| `Idempotency-Key` | Organization POSTs (UUID per attempt) |
| `If-Match` | Document/folder mutations (revision) |
| `Content-Type: application/json` | JSON bodies |

409 + `revision_conflict`: refetch, then the user retries. Do not loop
silently.

### 5.4 Upload (not through the JSON client body)

1. `POST .../uploads` with document id, size, SHA-256, media type.
2. `POST .../uploads/:id/parts/:n/presign` → PUT bytes to the signed
   URL (S3/MinIO). Progress is this PUT, not the Core POST.
3. `POST .../uploads/:id/complete`.
4. Abort on cancel. Completing twice must not create a second version
   (server invariant; client still avoids a second complete).

Download: `GET .../documents/:id/download` → open the signed URL
(QDesktopServices or a streaming GET). Do not treat the JSON as the
file.

### 5.5 Errors

Parse `{ error, ... }` JSON. Surface `limit_exceeded`, `forbidden`,
`unauthenticated`, `revision_conflict`, `not_found` as stable codes to
QML, not raw English from the server as the only UI.

### 5.6 Generated SDK

Later: snapshot `openapi.json` from Core (private CI) into this repo
as a **generated** C++ Qt client, plus a **hand** wrapper for
session, idempotency, If-Match, multipart. Do not block the first
window on OpenAPI generator quality (`operationId`s today are
`AuthController.login`). Hand-write the first dozen calls.

### 5.7 Profiles (several accounts)

Two different things:

| | What it is | How the user switches |
| --- | --- | --- |
| **Organization** | Tenant on the server. Already in every URL. | Org picker inside a signed-in identity. |
| **Profile** | Local slot: one identity (email) at one `apiBaseUrl`. | Account switcher, `--profile`, or a second window. |

One login can own many orgs. That is **not** a second profile. A
second email, or the same email against another server (prod vs
localhost), **is** a second profile.

A profile is `{id, email, apiBaseUrl, lastOrgId}`. Secrets
(`refresh_token`, optional `access_token`) are
`matome/profile/<id>/refresh` in the keyring. `id` is a local
slug (`work`, `home`, `dev`), not the server user id.

There is **no global Session**. `AccountStore` holds many profiles;
each `Client` is bound to one. Models and uploads take a `Client*`.
Two windows may pin two profiles at once (Chrome-style). Switching
inside one window tears down that window's models and builds them
on the other client — it does not merge two token jars.

CLI (same store, same keyring):

```
matome auth login [--profile work] [--url http://localhost:7001]
matome auth whoami
matome auth logout
matome --profile work orgs list
MATOME_PROFILE=work matome spaces list
```

Default profile is the last one the studio used, or `default`.
`--url` / `MATOME_URL` override `apiBaseUrl` for that invocation.
Password is prompted (TTY) or taken from the studio login form —
never as a CLI flag that lands in shell history.

Agents: prefer a `mat_…` token created in the studio or
`matome auth token create` (secret shown once, stored only if the
user asks). The refresh JWT of a human profile is for the CLI and
the window, not for pasting into an agent config.

`matome mcp` uses `--profile` / `MATOME_PROFILE` the same way.

---

## 6. C++ / QML boundary

| Lives in C++ (`core` / models) | Lives in QML |
| --- | --- |
| HTTP, retries, refresh | Layout, lists, dialogs |
| Token store | Binding to `Theme.*` |
| Org/space/folder/document models (`QAbstractListModel`) | Delegates |
| Upload session + hash | Progress bars |
| Command registry (id, title, shortcut, enabled) | Palette UI, key routing |
| Settings | Forms |

QML may call `Q_INVOKABLE` on session/client. It must not assemble
URLs or set auth headers.

Models expose roles the delegates need (`id`, `title`, `revision`,
`byteSize`, …). Do not dump full JSON into QML and parse it there.

---

## 7. Product surface (phased)

### P0 — window that signs in

- Theme singleton: light / dark / system (Omarchy `colors.toml` or OS).
- Login, register, forgot/reset (reset URL may be a custom scheme or
  a pasted token until mail deep links exist).
- Profiles: add a second account, switch, open another window on
  another profile. `apiBaseUrl` is per profile (default
  `http://localhost:7001`).
- List organizations of the **current profile**; create one;
  persist `last_org_id` on that profile.

### P1 — files

- Space list (colour from `spaceColor`).
- Folder tree + document list in the current folder.
- Create folder, rename, move, trash, restore, purge.
- Upload (simple and multipart), download current version, version list.
- Tags as names on the document; `tag_assignments` later.

### P2 — people

- Members, invitations, roles as Core returns them.
- Space grants (the compatibility `/members` is not the source of
  truth; grants are).

### P3 — activity and automations

- Org/space event history (poll).
- Routines/rules/runs when the files shell is solid.

### P4 — add-ons and org webhooks

- Catalogue, installation, on-demand runs (`dry_run`), usage.
- Org webhook CRUD. Trusted endpoints read-only (no URL/secret).

Out of the client until Core has it: full-text search, SSO, checkout,
connectors, knowledge graphs.

### P5 — CLI and agents

After files work: a thin `matome` CLI on the same core, shipped in
the **same package** as the window. That is the agent surface. MCP
is an adapter on that CLI, not a second API.

---

## 8. Agents: CLI first, MCP later

An agent is another consumer of `libmatomecore`, like the window and
the command sheet. It is not a consumer of Core HTTP and not a
consumer of QML.

**CLI is the contract.** JSON on stdout, including errors, with a
stable `code` (omabench). Humans can script it; Cursor / Claude Code /
omunculus already shell out. Auth is the keyring session or a `mat_…`
token the user already created — never a secret pasted into a prompt
file.

**Same install, two binaries** (omafiles: `omafiles` + `omafiles-studio`).
`matome` is the CLI on PATH. `matome-studio` is the window; the
`.desktop` launches it. One Arch/mise package copies both. Not a
second repo. Not one binary that guesses argv vs GUI.

A later split (`matome` without Qt Quick for CI/agents) is optional
packaging, not a second codebase.

**MCP is a wrapper.** `matome mcp` on stdio maps a **small** tool list
onto the same verbs. Ship it when an editor wants native MCP. Do not
generate one tool per OpenAPI operation. Do not run MCP inside
Phoenix: the API stays private; the open-source client is what an
agent is allowed to drive.

omapixel's `where` is the one extra the GUI owes the CLI: on request,
the window answers what org/space/folder/document is on screen. The
CLI does not scrape QML. No socket until that question exists.

First verbs (after login works): `auth login` / `whoami`, `orgs list`,
`spaces list`, `folders list`, `documents list|show`, `download`.
Mutations after the GUI has them: tag, move, trash. Upload last.

---

## 9. Suggested tree

```
matome-app/
  spec.md                 this file
  LICENSE
  README.md
  mise.toml
  matome.pro              subdirs: core, cli, gui
  qmake/
  src/core/               libmatomecore: Client, AccountStore, commands
  src/cli/                binary `matome` — JSON; later `mcp` stdio
  src/gui/
    main.cpp
    Theme.{h,cpp}
    AccountStore.{h,cpp}
    Session.{h,cpp}           one Client per profile, not a global
    models/
    qml/
      Main.qml
      chrome/             FocusableControl, ActionButton, EntryRow, ContextMenu, CommandSheet
      screens/            Auth
      explorer/           Explorer: TopBar, Sidebar, LocationHeader, Toolbar, EntryList, StatusBar
  packaging/              .desktop, icon.svg
  tests/
```

Binaries: `matome` (CLI), `matome-studio` (window). QML import: `matome`.

---

## 10. Invariants

1. **No hex in screens.** Colour comes from `Theme`.
2. **Accent is fill.** In Eva modes that is gold: text on it =
   `onAccent`; accent as words = `accentText`. In System-on-Omarchy
   the desktop accent is the fill; `readable()` still owns text.
3. **Org is in the path.** Never a global "current org" header.
4. **Bytes do not go Core JSON.** Upload PUT to storage; download is a
   signed URL.
5. **QML does not speak HTTP.**
6. **A command has one id** in the registry; keyboard, buttons, the
   sheet and the CLI share it.
7. **Secrets stay in the keyring.**
8. **This repo never vendors Core.** No Phoenix, no DB, no MinIO
   credentials. `API_BASE_URL` only.
9. **Agents speak CLI (JSON), not Core HTTP.** MCP, if any, wraps
   those verbs.
10. **No global session.** HTTP is always `Client` + profile id.
    Orgs of one login share that client; a second email is a
    second profile.

---

## 11. First implementation slice

Do not scaffold the whole tree empty. Ship, in order:

1. `mise` + qmake that builds a window with `Theme` (light / dark /
   system) and the sign-in form (no HTTP).
2. `Session` + login against local Core.
3. Org list + space list.
4. Folder/document list + download.
5. Upload with progress.

qmllint is in the gate from slice 1.

---

## 12. References

| What | Where |
| --- | --- |
| Palette | `matome-app` branch `development` — `apps/flutter/lib/core/theme/app_theme.dart` (`MatomeColors`) |
| HTTP judgement | `matome-core/docs/api.md` |
| Routes | `matome-core/docs/endpoints.md` (router is source; ignore "later waves" for trusted webhooks / add-on runs) |
| Events | `matome-core/docs/events.md` |
| Core/studio split | `omacon/omafiles/omafiles.pro`, `omacon/omabench/docs/internal/architecture.md` |
| Theme singleton | `omacon/omafiles/src/studio/Theme.h`, `omacon/omastore/src/studio/Theme.h` |
| QML registration | `omacon/omafiles/src/studio/main.cpp`, `studio.pro` |
| Keyboard + sheet | `omacon/omafiles/src/studio/qml/Main.qml`, `omastore/src/studio/qml/Main.qml` |
| Focus chrome | `omacon/omafiles/src/studio/qml/FocusableControl.qml` |
| HTTP client | `omacon/omastore/src/studio/AppCatalog.cpp` |
| qmake layout | `omacon/omabench/qmake/layout.pri` |
| Offscreen GUI tests | `omacon/omafiles/tests/tst_studio.cpp` |
| Packaging | `omacon/publicar-app-no-omarchy-pkgs.md` |
| CLI JSON | `omacon/omabench/docs/cli.md` |
| Agent `where` | `omacon/omapixel` (`omapixel where`) |
