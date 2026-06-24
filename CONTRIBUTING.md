# Contributing Guide

## Scope

Matome is a cross-platform **Flutter** client (`apps/flutter`) backed by an
**Elixir / Phoenix** Core API (`services/api`), with a Node mock of the AI
engine (`services/ai-stub`) and Supabase (Postgres + S3) for local development.
The toolchain is managed by [mise](https://mise.jdx.dev/).

## Development workflow

```bash
mise run up             # Start the backend (Supabase + Core API + AI stub)
mise run flutter-linux  # Run a Flutter client (or flutter-web / flutter-android)
```

Before opening a PR:

```bash
cd apps/flutter && flutter analyze && flutter test
cd services/api && mix test
```

## Project standards

### Flutter (`apps/flutter/lib`)

- Keep feature code under `features/<feature>/`; cross-cutting infra under
  `core/`; shared widgets under `ui/`.
- Use Riverpod for state; do not use a `WidgetRef` after an async gap (capture a
  `ProviderContainer` first).
- Drift is the offline-first source of truth the UI watches; sync to Core runs
  through the upload queue, not inline.
- Edit translations in `lib/i18n/{en,ja}.i18n.json`, then run `dart run slang`.
- Respect the design-system gate (`mise run flutter-design-system-check`).
- Never log credentials — only a non-sensitive email domain.
- Author UI in the app, render it in the catalog — see
  [Widgetbook design catalog](#widgetbook-design-catalog).

### Widgetbook design catalog (`apps/flutter_widgetbook`)

`apps/flutter/lib` is the source of truth for widgets; the catalog only
*renders* them for review. It must never *define* a shippable widget.

- The catalog imports app widgets via `package:matome_flutter/...` and writes
  only Widgetbook use-cases/stories. The only widget classes allowed to live in
  the catalog package are the `MatomeWidgetbook` entry point and private
  fixtures/scenes that wrap real app widgets (enforced by the design-system gate,
  `mise run flutter-design-system-check`).
- Author proposals **app-first**: build the real widget in `apps/flutter/lib`
  (under a `proposals/` area or behind a disabled build-time feature flag, which
  tree-shakes it out of release builds), then add a catalog use-case that
  *imports* it.
- **Graduate** by moving the file out of `proposals/` or flipping the flag —
  never reimplement. One widget, 100% fidelity, zero re-port.
- Mocking a widget in the catalog and then re-implementing it in the app is the
  failure mode this rule forbids: two implementations of one widget that drift.

### Core API (`services/api`)

- Follow standard Phoenix/Ecto structure; run `mix format` and `mix test`.
- The client talks to Core only; Core owns DB/storage/AI access.

## Commit standards

- Use **Conventional Commits**, written in **English**, for example:
  - `feat(matome): add sync rollup pill`
  - `fix(recording): prevent duplicate insert on save`
  - `docs: update architecture overview`
- One intent per commit; split mixed trees via non-interactive staging.
- Never attribute a commit to an AI agent (no `Co-Authored-By` trailer).
- Never `git push` without explicit authorization.

## Documentation standards

- All documentation is written in **English**.
- Keep `README.md` concise and high-level; move detail into `.docs/`.
- When content moves to `.docs/`, keep a short summary + link in `README.md`.
- Update docs when behavior, architecture, or workflows change.

## Pull request expectations

- Ensure `flutter analyze`, `flutter test`, and `mix test` pass before opening a PR.
- Keep changes consistent with the existing architecture and file organization.
