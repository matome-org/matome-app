# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

Matome captures audio and photos, transcribes and summarizes them through an AI
engine, and organizes them into **matomes** (per-happening collections of items)
that file into spaces and sync to the cloud.

The client is a cross-platform **Flutter** app (`apps/flutter`) — mobile, Linux
desktop, and web from one codebase. It talks to an **Elixir / Phoenix** Core API
(`services/api`), which owns Postgres, S3 storage, Guardian auth, and AI
orchestration. A small Node mock of the AI engine (`services/ai-stub`) stands in
for the real transcription/summarization service during local development.

## Commands

The toolchain is driven by [mise](https://mise.jdx.dev/):

```bash
mise run up             # Backend: Supabase + Core API (:4000) + AI stub (:5055)
mise run backend        # Same as `up` (no client)
mise run flutter-linux  # Flutter on Linux desktop  → local Core
mise run flutter-web    # Flutter on Chromium (:8080)
mise run flutter-android# Flutter on the pixel7 emulator
mise run storybook      # Widgetbook design catalog
mise run down           # Stop the stack
mise run nuke           # Wipe the local environment
```

Run `mise run up` before any `mise run flutter-*` client.

## Architecture

### Flutter client (`apps/flutter/lib`)

```
app/       -> App wiring: go_router routes, the shell scaffold, auth guard
core/      -> Cross-cutting infra: Drift DB, HTTP (dio), config, theme,
              providers, observability
features/  -> Feature modules (matome, home/inbox, auth, recording, calendar,
              contacts, spaces, satori, details)
ui/        -> Shared widgets (cards, badges, dialogs)
i18n/      -> slang translations (en/ja JSON → generated strings)
```

### Key patterns

- **State**: Riverpod (`flutter_riverpod`). Feature controllers are
  `StateNotifier`s exposed via providers; screens watch them. `WidgetRef` is
  bound to the widget element — never use it after an async gap; capture a
  `ProviderContainer` first.
- **Persistence**: Drift (SQLite), offline-first. The DB is the source of truth
  the UI watches; the upload queue syncs local → Core in the background.
- **Routing**: go_router with a `StatefulShellRoute.indexedStack`. The shell
  tabs are a single ordered registry (`lib/app/shell_tabs.dart`) gated by
  build-time feature flags (see below).
- **i18n**: slang. Edit `lib/i18n/{en,ja}.i18n.json`, then run `dart run slang`.
- **Auth**: Guardian-issued JWTs from the Core API. Never log credentials —
  only a non-sensitive email domain.
- **Feature flags**: build-time `const bool.fromEnvironment` flags in
  `lib/core/config/feature_flags.dart`, supplied by the root
  `apps/flutter/feature_flags.json` via `--dart-define-from-file`. A disabled
  screen is tree-shaken out, not merely hidden.
- **Design catalog**: `apps/flutter_widgetbook` (`mise run storybook`) *renders*
  app widgets; it never *defines* shippable ones. `apps/flutter/lib` is the
  source of truth — the catalog imports it via `package:matome_flutter/...` and
  writes only use-cases/stories (the sole local widgets are the
  `MatomeWidgetbook` entry point and fixtures/scenes wrapping real app widgets;
  enforced by the design-system gate, `mise run flutter-design-system-check`).
  Author proposals app-first (real
  widget under `proposals/` or behind a disabled flag, plus a catalog use-case
  that imports it); graduate by moving the file or flipping the flag — never
  reimplement.

### Core API (`services/api`)

Elixir / Phoenix 1.7 with Ecto (Postgres), Guardian for JWT auth, Oban for the
AI job queue, Phoenix Channels for realtime ingestion status, and `cors_plug`.
Runs on `:4000`. Owns database/storage access and AI orchestration behind the
API boundary; the Flutter client never touches Postgres or S3 directly. Status
reaches the client over a `RecordingStatusChannel`, raced against a 2 s poll
(`recording_result_waiter.dart`).

## Testing

```bash
cd apps/flutter && flutter test     # Flutter unit + widget tests (~65 suites)
cd services/api && mix test         # Core API tests (creates + migrates a test DB)
bun run check                       # AI-stub server test
```

Regression discipline: a test that passes against both the old and fixed code
proves nothing — verify it goes red on the unfixed code before trusting it.

## Conventions

- Conventional Commits, written in English, one intent per commit.
- Never attribute commits to an AI agent (no `Co-Authored-By` trailer).
- Never `git push` without explicit authorization — the human owns publication.
