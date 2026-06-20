# Matome

Matome captures audio and photos, transcribes and summarizes them through an AI
engine, and organizes everything into **matomes** — per-happening collections of
items — that file into spaces and sync to the cloud. The client is a
cross-platform **Flutter** app backed by an **Elixir / Phoenix** Core API.

## Layout

| Path | What |
|------|------|
| `apps/flutter` | The Flutter client — mobile, Linux desktop, and web |
| `apps/flutter_widgetbook` | Isolated Widgetbook design catalog |
| `services/api` | Core API — Elixir / Phoenix, Postgres, Guardian auth |
| `services/ai-stub` | Local Node mock of the AI engine the Core calls |
| `supabase` | Local Postgres + S3 storage for development |

## Quick start

The toolchain is managed by [mise](https://mise.jdx.dev/):

```bash
mise run up             # backend: Supabase + Core API (:4000) + AI stub (:5055)
mise run flutter-linux  # a Flutter client — or flutter-web / flutter-android
```

Sign in with the seeded dev user: `dev@matome.test` / `devpassword123`.
Stop everything with `mise run down`; wipe the local stack with `mise run nuke`.

## Documentation

- Architecture and data flow: [.docs/architecture.md](.docs/architecture.md)
- Local build details: [.docs/build-local.md](.docs/build-local.md)
- Design decisions (ADRs): [.docs/decisions/](.docs/decisions/)
- Domain glossary: [.docs/glossary.md](.docs/glossary.md)
- Contribution and commit standards: [CONTRIBUTING.md](CONTRIBUTING.md)
- Guidance for coding agents: [AGENTS.md](AGENTS.md)
