# Matome — Architecture

> Status: agreed · Last updated: 2026-06-23
> One Flutter client, one Elixir Core API, one external Python AI Engine, one
> ingestion contract. This is the single architecture record: the decisions that
> used to live in separate ADRs are folded into §11 (Decision log) so nothing is
> lost. Where code and this doc disagree, the code wins.
>
> Companions: product framing in [`prd.md`](prd.md), requirements in
> [`requirements.md`](requirements.md), behaviour in [`../use-cases.md`](../use-cases.md).

---

## 1. Principles

1. **Thin client.** The app only *captures* (record / pick a file), *uploads raw bytes*, and *reads results*. It never runs transcription, OCR, or summarization.
2. **The backend owns all processing.** Transcription, OCR, and summarization are server-side. Adding a media type or model is a backend change — the client doesn't ship.
3. **Server is the source of record.** Records live in Core's Postgres. The client's Drift (SQLite) store is an offline mirror, reconciled against Core — not the authority.
4. **One ingestion contract for every media type.** Audio, meetings, images, and future formats flow through one `upload → pending → process → done` path. The client is media-agnostic.
5. **Local-first organization, decoupled from sync.** Items are organized on-device; whether they sync is a separate question answered by a single resolver (§5).
6. **Owned backends, one client language.** Core API is Elixir; the AI Engine is Python; the client is Dart/Flutter.
7. **Contract-first.** Core publishes a REST (OpenAPI) surface consumed by the Flutter `dio` layer; ingestion status is pushed over Phoenix Channels, raced against a poll fallback.

---

## 2. System overview

```mermaid
flowchart LR
  subgraph Client["Client (Flutter)"]
    F[apps/flutter\nmobile · desktop · web]
  end
  subgraph Core["Backend A — Core API (Elixir/Phoenix)"]
    PH[Phoenix\nauth · CRUD · gateway]
    PG[(PostgreSQL\nsource of record)]
    OB[Oban\njob queue]
    CH[Channels\nrealtime status]
  end
  ST[(Object Storage\nSupabase Storage / S3)]
  subgraph AI["Backend B — AI Engine (Python/FastAPI)"]
    P[transcribe · ocr · summarize]
  end
  F -- "REST (OpenAPI)" --> PH
  F -- "presigned upload" --> ST
  PH --- PG
  PH --- OB
  PH --- CH
  OB -- "enqueue job" --> P
  P -- "download raw" --> ST
  P -- "callback: result" --> PH
  CH -- "status push (poll fallback)" --> F
```

**Hard rule:** the client talks only to Core + Storage. Only Core talks to the AI Engine. The AI Engine is never client-facing.

---

## 3. Backend A — Core API (Elixir / Phoenix)

Owns everything except AI.

| Concern | Choice |
|---|---|
| Framework / language | **Phoenix** / **Elixir** (BEAM) |
| DB | **Supabase Postgres** (managed) via **Ecto** — system of record |
| Auth | **Guardian** (JWT access + refresh), **Argon2** hashing; users in Postgres. App-level authz (no Supabase Auth/RLS) |
| Authorization | scoping by `owner_id` (Ecto query scopes) |
| Job queue | **Oban** (Postgres-backed) — dispatch + retry of AI jobs |
| Realtime | **Phoenix Channels** + PubSub (`RecordingStatusChannel` on `user:*`) |
| Object storage | **Supabase Storage** — Core issues presigned PUT/GET URLs |
| API surface | REST, documented as **OpenAPI** (`open_api_spex`) |

Responsibilities: register/login + tokens; CRUD on matomes / recordings / spaces / contacts; create the `pending` record; issue presigned upload URLs; enqueue ingestion jobs; receive AI results via internal callback; archive/restore.

**Public REST surface (owner-scoped unless noted):** `/api/auth/{register,login,refresh,logout}` (public) + `/api/auth/me`; `/api/spaces` (+ `/search`, `/:id`); `/api/recordings` (+ `/search`, `/:id`, `/:id/process`, `/:id/download-url`, `/:id/contacts`); `/api/matomes` (+ `/search`, `/:id`, `/:id/archive`, `/:id/restore`, `/:id/contacts`); `/api/contacts` (+ `/search`, `/:id`). **Internal:** `POST /internal/jobs/:id/result` (AI callback, service-token).

> Note: the physical `workspaces` table / `workspace_id` FK is the **Space** concept (logical rename); the code keeps the legacy name.

---

## 4. Backend B — AI Engine (Python / FastAPI)

> **Lives in its own repository — NOT in this monorepo.** This repo integrates it via its HTTP contract (job dispatch + result callback) and ships a local mock at `services/ai-stub`.

Stateless processors (`transcribe`, `ocr`, `summarize`). Only Core reaches it (service token, private network). It downloads media via presigned GET and returns one terminal result via callback. It stores nothing durable.

**Contract.** Core → AI: `POST /v1/jobs` `{job_id, recording_id, media_type, storage_key, media:{method:GET,url,expires_at}, callback:{url,method:POST}, metadata}` → `202 {accepted:true}`. AI → Core: `POST /internal/jobs/:job_id/result` with `status:done` (`title, transcript, summary, duration`) or `status:failed` (`error.{code,message}`), both `Bearer <AI_ENGINE_TOKEN>`. Callback is idempotent per `job_id`; `metadata` is advisory and must not be used for authorization. Local stub: `bun run ai:stub` (default `http://127.0.0.1:5055/v1/jobs`).

---

## 5. The local-first organization model (central)

Organization and sync are two independent questions, joined only by the **effective space** resolver.

### Membership lattice (composable)

An item (a `recordings` row — audio, image, file) is in exactly one state, composing freely with the matome/space graph:

```
LOOSE              recording.matomeId = NULL  AND  recording.workspaceId = NULL
IN A MATOME        recording.matomeId set      (the matome may be a DRAFT — no space)
FILED INTO A SPACE recording.workspaceId set, no matome wrapper
```

A **draft matome** has items but no space (`matome.spaceId = NULL`). Nothing forces a matome before a space, or a space before sync.

### Effective space — the single precedence rule

```
effectiveSpace(item) =
    matome.spaceId        if item IS IN A MATOME   (matome WINS)
    else recording.workspaceId                     (filed directly)
    else NULL                                       (loose, or draft matome)
```

- **Matome membership wins.** An item's own `workspaceId` is **shadowed, not cleared**, when it joins a matome; it reappears on leave. Reading `recording.workspaceId` directly is a bug for any item that is (or ever was) in a matome.
- One resolver (`apps/flutter/lib/features/spaces/effective_space.dart`) owns this and is the **sole sync-eligibility authority**. It consumes a Space value object `{id, syncMode, tenancy, ownerId}` and returns a sealed `SyncStatus` (no default arm).

### Inbox = a VIEW

```
INBOX ⟺ effectiveSpace(item) == NULL          (loose items + draft matomes)
```

Inbox is a derived view computed on read — **never** a stored column, boolean, sentinel id, or magic row (no `is_inbox`).

### Sync gate

```
SYNC(item) ⟺ effectiveSpace(item) is a CLOUD space
           ⟺ effectiveSpace(item) != NULL  AND  thatSpace.is_local == false
```

- A Space carries `is_local` (m017, additive, **default local**). A **local** space's items never sync; a **cloud** space's items sync.
- **Filing organizes; landing in a cloud space syncs.** Filing is no longer the sync trigger.
- The decision flows through **one operation-keyed gate**: `SyncPolicy.can(caller, Operation.spaceSync, space)` (`apps/flutter/lib/features/spaces/sync_policy.dart`) — never an inline `if isCloud`, never a fixed role enum. Today it returns `isCloudSynced` (owner ⇒ allow).
- **Promotion** turns a local space cloud — one-way in v1, with itemized consent ("N items will leave this device"), per-item idempotency (keyed on stable/Core id), and a sealed `local → promoting → cloud | failed` state machine with resume (`space_promotion.dart`). State is re-derived from `is_local` + each item's `coreId`, not a new column.

### Two axes, never collapsed (forward-compat)

| Axis | Question | Column | Values | Status |
|---|---|---|---|---|
| **A — sync mode** | does it sync? | `workspaces.is_local` | local \| cloud | **built** (m017) |
| **B — tenancy** | who owns it? | `workspaces.space_type` | personal \| shared \| org | **reserved / unenforced** |

Orthogonal columns, never merged. Invariants couple them: **`local ⟹ personal`**, **`org ⟹ cloud`**; `personal` may be local or cloud. Keying sync off `space_type`, adding an `org_local` cell, or merging the columns is forbidden.

> The whole behaviour is behind `FeatureFlags.localFirstSpaces` (default OFF; single-flip rollback).

---

## 6. Ingestion pipeline (one path for every media type)

```mermaid
sequenceDiagram
  participant C as Flutter client
  participant API as Core API
  participant ST as Object Storage
  participant OB as Oban
  participant AI as AI Engine
  C->>API: POST /api/recordings (mediaType)
  API-->>C: id + presigned PUT url (status pending)
  C->>ST: PUT raw bytes (presigned, streamed)
  C->>API: POST /api/recordings/:id/process
  API->>OB: enqueue ingestion job
  API-->>C: 202 (status processing)
  OB->>AI: dispatch job
  AI->>ST: GET raw bytes (presigned)
  alt audio or meeting
    AI->>AI: transcribe
  else image
    AI->>AI: ocr
  end
  AI->>AI: summarize
  AI->>API: POST /internal/jobs/:id/result
  API->>API: update record, status done
  API-->>C: Channels push (status done)
  Note over C: a ~2s GET /api/recordings/:id poll also resolves it
```

- **Statuses:** `pending → processing → done | failed` (client renders each + retry).
- **mediaType:** `audio | meeting | image` (future `video | pdf`); set by the client at upload, routed by the AI Engine.
- **Retry:** on processor error Core sets `failed`; client retry re-enqueues server-side, never processes locally.

---

## 7. Client (Flutter)

A single Flutter codebase (`apps/flutter`) targets mobile, Linux desktop, and web. `apps/flutter_widgetbook` is an isolated design catalog.

| Layer (`lib/`) | Responsibility |
|---|---|
| `app/` | go_router routes, shell scaffold, auth guard |
| `core/` | Drift DB, HTTP (`dio`), config, theme, providers, observability |
| `features/` | feature modules (auth, home/inbox, recording, recordings, matome, details, spaces, contacts, calendar, files, satori, sync) |
| `ui/` | shared widgets |
| `i18n/` | slang translations (en/ja) |

- **State:** Riverpod (`StateNotifier`s behind providers). **Routing:** one flat go_router tree; matome detail is one breakpoint-driven route. **Persistence:** Drift, offline-first — UI watches the DB; an upload queue syncs local → Core in the background.
- **Capture:** mic on mobile/desktop; loopback meeting capture on Linux desktop (ffmpeg); file import everywhere.

### Capability matrix
| Capability | Mobile | Desktop | Web |
|---|---|---|---|
| Record audio (mic) | ✅ | ✅ | ⚠️ platform-dependent |
| Record meeting (loopback) | ❌ | ✅ Linux (ffmpeg) | ❌ |
| Import file (audio/image/doc) | ✅ | ✅ | ✅ |
| Read / search / organize | ✅ | ✅ | ✅ |
| Offline mirror (Drift) | ✅ | ✅ | ⚠️ online-first (in-memory) |

---

## 8. Data model

Server-authoritative store in Core Postgres; mirrored in Drift. The central entity is the **Matome** — a per-happening collection of items.

```
recordings
  id          uuid pk      -- Core id; local rows keep rec_local_<uuid> until reconciled
  owner_id    uuid (users)
  matome_id   uuid (matomes)    -- nullable: item may be loose
  workspace_id uuid (workspaces) -- nullable: filed-directly space (shadowed when in a matome)
  title / summary / transcript / notes  text
  media_type  text          -- audio | meeting | image | ...
  storage_key text
  status      text          -- pending | processing | done | failed
matomes
  id / owner_id / space_id (nullable ⇒ draft) / title / happened_at
  aggregated_summary / summary_stale / archived_at (soft-delete) / core_id
workspaces (= Space)
  id / owner_id / name / is_local (m017) / space_type (m006, reserved)
contacts (+ matome_contacts, space_contacts, matome_shares, space_members)
```

- Authorization is enforced in Ecto query scopes by `owner_id`.
- The Drift store is a per-user offline mirror, reconciled by `core_id`; a Matome's sync chip rolls up from its items (`onDevice → partial → cloud`).

---

## 9. Lifecycle of a Matome (summary)

- **Birth** — minted implicitly when the first item enters (1 item → 1 Matome); local id `mat_local_<uuid>`. No blank-Matome flow.
- **Add items** — photo/file upserted against the existing Matome; summary marked stale.
- **Upload + processing** — per-item ingestion (§6); status `pending_upload → processing → done | failed`.
- **Summary** — aggregated summary is a local deterministic composition of item summaries, regenerated on demand; staleness flips on add/remove/change.
- **Edit** — rename + date/time, local-first then `PATCH` when reconciled.
- **Triage** — file into a Space (§5); only cloud-space items push to Core.
- **Contacts** — tagged via `matome_contacts` with a role.
- **Death** — **archive** (soft-delete, offline-first, Undo restore) is the user-facing path; converges across sync via an adopt-guard on pull + a re-push pass. Hard-delete exists in the data layer but is not a surfaced UI flow.

---

## 10. Monorepo layout

```
matome/
├── apps/
│   ├── flutter/             # The client — mobile, Linux desktop, web
│   └── flutter_widgetbook/  # Isolated Widgetbook design catalog
├── services/
│   ├── api/                 # Backend A — Elixir/Phoenix
│   └── ai-stub/             # Local Node mock of the AI Engine (Backend B is a separate repo)
├── supabase/                # Local Postgres + S3 storage for dev
└── .docs/
```

Toolchain via [mise](https://mise.jdx.dev/) (`mise run up`, `mise run flutter-*`). Design tokens originate in Figma (`LxpS0mmXZHPZ17qLufN7wB`), bound as Flutter `ThemeExtension`s under `lib/core/theme`, governed by the Widgetbook catalog + `mise run flutter-design-system-check`.

---

## 11. Decision log (folded from the former ADRs)

The historical decisions, kept here as the durable record:

- **D1 — Consolidate to Flutter.** The client tier was three JS/TS apps (Expo RN, Next.js, Tauri) over a generated TS API client; they were consolidated into one Flutter codebase. Backend topology unchanged. Web is online-only (no at-rest local store).
- **D2 — Design-system foundation.** Canonical tokens in Figma, bound as Flutter `ThemeExtension`s, governed by Widgetbook + the DS-check gate. The app-owned route/Page layer contract and current route inventory live in [`design-system-route-contract.md`](design-system-route-contract.md).
- **D3 — Matome is the central entity.** A Matome is a per-happening, fixed-structure aggregate of items + contacts + summaries + notes. *(Its original forced-Matome invariant — every recording in exactly one Matome — was later repealed by D6.)*
- **D4 — Identity, permissions, triage.** Contacts are owner-owned with an optional `linkedUserId`. Spaces carry `type` (personal/shared/org) + `owner_id`; `space_members` carry RBAC roles; `organizations` may own spaces. **Schema is reserved; behaviour is deferred and unenforced** (sharing, ACLs, multi-user sync, org management). A linked contact's profile is viewable without consent — a recorded, revisitable privacy risk.
- **D5 — Matome detail = letter + responsive panel.** One route renders a stacked "letter" on narrow viewports and letter + persistent side panel at ≥ 900 px via a `LayoutBuilder` (no nested navigator).
- **D6 — Item organization decoupled from sync** (plan #102, the §5 model). Supersedes D3's forced-Matome rule; amends D4's "filing ⟹ sync". Effective-space resolver + one operation-keyed sync gate + two-axis (`is_local` ⟂ `space_type`) model + one-way promotion. **Accepted risk:** local-default means an unsynced item lives only on the device; a device wipe loses it (owner-accepted trade-off of the local-first default).
- **D7 — Master–detail layout (email-style), Settings-controlled** (plan #102, W1). Graduated from the approved Widgetbook proposal `[Proposals]/Master–detail layout`.
  - **Decision:** every collection surface (Inbox, Files, Spaces, Contacts) renders through **one** reusable `MasterDetailScaffold` (`apps/flutter/lib/ui/master_detail_scaffold.dart`) — a master list plus an optional right-hand **reading pane**. Pane visibility is a single GLOBAL persisted setting, `readingPaneProvider` (`ReadingPanePosition { right, off }`), switchable **only** from Settings (no in-screen toggle). Layout uses unified breakpoints (`apps/flutter/lib/core/layout/breakpoints.dart`: `compact < 600` / `medium 600–1024` / `expanded ≥ 1024`); the pane shows only at `expanded` **and** `right`, while `compact` navigates full-screen. The Files reading-pane content is `FileView` (the shared body), **not** the full `FileDetailScreen`. The whole behaviour is gated behind `FeatureFlags.masterDetailLayout` (default **OFF** — a single flag flip is the rollback).
  - **Rejected alternatives:** a left-hand pane (right-hand chosen, email-style); per-surface pane settings (gold-plating — the global setting widens to per-surface additively later if ever needed); an in-screen pane toggle (Settings-only chosen, so the choice is global and stable); embedding the 33 KB multi-`Scaffold` `FileDetailScreen` in the pane (nested-`Scaffold` breakage — use `FileView`, the shared body).
  - **Accepted note:** unifying the legacy `1000` breakpoint onto `1024` is an intentional behaviour change for viewports in the half-open range `[1000, 1024)` (formerly two-pane, now single-pane until `1024`).

### Forward-compat seams (deferred org / admin / data-policy / SSO / RBAC)

Plan #102 leaves **seams, not features**, so the deferred work plugs in without a rewrite:

- **Resolver seam** — the Space value object already carries `tenancy` + `ownerId` (constants today), so org-spaces add one branch.
- **Authorization seam** — guarding is **operation-keyed** (`SyncPolicy.can(caller, Operation, space)`), a client mirror of a future Core **Bodyguard/PDP** seam. Roles/operations are future **DATA**, not enums — custom roles add zero call-site changes. The sealed sync-status type makes a new state (`orgManaged`/`policyBlocked`) a compile error at every switch.
- **Identity seam** — `owner_id` is a stable user id (not email), so SSO-linked identities map cleanly.
- **Deferred configurable-RBAC** — the full data-driven model (users × groups × custom roles × operations + a PDP + an engine choice: OpenFGA/Oso/Casbin/hand-rolled) is a **separate deferred plan** (tag `#future-plan`). #102 adopts only the seam.

---

## 12. Glossary (essentials)

- **Matome** — a per-happening collection of items (recordings); the central entity. *(Distinct from the `Matome*` brand/theme namespace.)*
- **Space** — a container of Matomes (table `workspaces`); `is_local` (sync mode) + `space_type` (tenancy).
- **Item / recording** — a child of a Matome (audio / meeting / image), or a loose/directly-filed file.
- **Loose item** — no matome and no space → Inbox, never syncs.
- **Draft matome** — a matome with no space → Inbox, unsynced until filed.
- **Inbox** — the VIEW of everything whose effective space is NULL. (Banned synonym: **"unfiled"**.)
- **Local / Cloud space** — `is_local` true/false; sync ⟺ effective space is a cloud space.
- **Capture** — recording audio or picking a file on the client.
- **SoR** — system of record (Core Postgres).
- **Master–detail** — the email-style layout (D7) where a collection surface is a master list plus an optional reading pane; implemented by `MasterDetailScaffold`.
- **Reading pane** — the optional right-hand detail pane of a master–detail surface; visible only at `expanded` + `right`. (Code: the `right` arm of `MasterDetailScaffold`.)
- **`MasterDetailScaffold`** — the one reusable widget every collection surface renders through (`apps/flutter/lib/ui/master_detail_scaffold.dart`).
- **`readingPaneProvider`** — the single GLOBAL persisted Riverpod provider holding the reading-pane setting (`apps/flutter/lib/core/settings/reading_pane.dart`); Settings-only.
- **`ReadingPanePosition`** — the pane-position enum, `{ right, off }` (defined in `master_detail_scaffold.dart`).
