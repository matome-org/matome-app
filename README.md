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
| `script/` | Native local data plane helpers (Postgres + MinIO) |

## Quick start

The toolchain is managed by [mise](https://mise.jdx.dev/):

```bash
mise run up             # backend: native Postgres + MinIO + Core (:7001) + AI stub (:7002)
mise run flutter-linux  # a Flutter client — or flutter-web / flutter-android
```

App: register via Flutter signup (or `POST /api/auth/register`). No auto-seeded account.
Admin: `http://127.0.0.1:7001/admin` — allowlisted email (dev default `dev@matome.test`) + OTP at `/dev/mailbox`.
Stop everything with `mise run down`; wipe the local stack with `mise run nuke`.
Data plane env contract: [services/api/docs/data-plane.md](services/api/docs/data-plane.md).

## Documentation

- Architecture and data flow: [.docs/internal/architecture.md](.docs/internal/architecture.md)
- Matome lifecycle (cradle-to-grave): [.docs/internal/architecture.md §9](.docs/internal/architecture.md)
- Design-system route/Page contract: [.docs/internal/design-system-route-contract.md](.docs/internal/design-system-route-contract.md)
- Local build details: see the build/run steps above
- Design decisions: [.docs/internal/architecture.md §11 (D1..D6)](.docs/internal/architecture.md)
- Domain glossary: [.docs/internal/architecture.md §12 (Glossary)](.docs/internal/architecture.md)
- Product docs: [.docs/internal/](.docs/internal/) and [.docs/use-cases.md](.docs/use-cases.md)
- Contribution and commit standards: [CONTRIBUTING.md](CONTRIBUTING.md)
- Guidance for coding agents: [AGENTS.md](AGENTS.md)
