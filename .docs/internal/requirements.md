# Matome — Requirements

> Status: agreed · Last updated: 2026-06-23
> The functional and non-functional requirements of Matome **as it stands today**.
> Each requirement has a stable id (`FR-*` / `NFR-*`); the per-use-case docs in
> [`../use-cases/`](../use-cases/) cite these ids. Where a requirement and the code
> disagree, the code wins and this file is corrected.
>
> Companion docs: product framing in [`prd.md`](prd.md), system shape in
> [`architecture.md`](architecture.md), behaviour catalog in
> [`../use-cases.md`](../use-cases.md).

---

## Actors

| Actor | Description |
|---|---|
| **Visitor** | An unauthenticated person. Can only register or sign in. |
| **User (Owner)** | An authenticated person. Owns all their data (`owner_id`-scoped). The primary actor for every feature. |
| **AI Engine** | External Python service (separate repo) that transcribes / OCRs / summarizes media and calls back. Secondary actor, never client-facing. |
| **Core API** | The Elixir/Phoenix backend — system boundary, system of record, orchestrator. |

> Matome is **single-user today**. Multi-user concepts (sharing, org tenancy, RBAC
> roles) are schema-reserved but **unenforced** — see [`architecture.md` §Forward-compat](architecture.md).

---

## 1. Functional requirements

### Authentication & session — `FR-AUTH`

- **FR-AUTH-1** A Visitor can register with email + password.
- **FR-AUTH-2** A Visitor can sign in with email + password and receive a Guardian JWT access token + refresh token.
- **FR-AUTH-3** A User can refresh the access token using the refresh token.
- **FR-AUTH-4** A User can sign out (token invalidated client-side; session cleared).
- **FR-AUTH-5** A User can read their own profile (`GET /api/auth/me`).
- **FR-AUTH-6** An authenticated session survives an app reload/restart (token persisted locally).
- **FR-AUTH-7** Every non-auth API call is scoped to the caller's `owner_id`; a User can never read or write another owner's data.

### Capture — `FR-CAP`

- **FR-CAP-1** A User can record audio from the microphone with start / pause / resume / finish, a live duration timer, and a waveform amplitude meter.
- **FR-CAP-2** A User can record a meeting by mixing system-audio (loopback) + microphone — **Linux desktop only** (ffmpeg + PulseAudio/PipeWire).
- **FR-CAP-3** A User can import an existing file (audio, image, or document) from device storage.
- **FR-CAP-4** A capture interrupted by a crash/kill is recoverable as a draft on next entry.
- **FR-CAP-5** Where microphone capture is unsupported (some web targets), the app degrades gracefully with a clear notice.
- **FR-CAP-6** A captured/imported item is persisted **locally first** (Drift) before any network activity.

### Ingestion & processing — `FR-ING`

- **FR-ING-1** Every supported input (`audio | image | document | text`) uses one explicit processing lifecycle: `not_requested → queued → processing → succeeded | partial | failed`, with `not_available` when current capabilities or policy cannot dispatch it.
- **FR-ING-2** The client creates a file Item under its reconciled Matome (`POST /api/matomes/:id/items`) and receives a verified-upload envelope.
- **FR-ING-3** The client uploads raw bytes directly to object storage via the presigned URL (streamed); the client never sends bytes through Core.
- **FR-ING-4** The client requests processing (`POST /api/items/:id/process`); Core creates or replays one logical run and enqueues run-keyed Oban work.
- **FR-ING-5** The AI Engine downloads media via a presigned GET, runs transcribe/OCR + summarize, and POSTs a single terminal result to Core's internal callback.
- **FR-ING-6** Core persists terminal state and bounded typed `processing_outputs`; user-authored notes remain independent.
- **FR-ING-7** The client polls `GET /api/items/:id` for the accepted run id with one request in flight and bounded backoff. Its 30-second observation timeout does not fail the Core run; Core's watchdog is authoritative.
- **FR-ING-8** On `failed`, the client surfaces the failure and the User can retry; retry re-enqueues server-side (Oban) — the client never processes media locally.
- **FR-ING-9** Callback handling is idempotent and current-run guarded by job id, run id, Item id, and source revision.

### Matome (the central aggregate) — `FR-MAT`

- **FR-MAT-1** A Matome is **never created empty** — it is minted implicitly when the first item enters (1 item → 1 Matome at birth). There is no blank-Matome creation flow.
- **FR-MAT-2** A User can open a Matome detail (`/matome/:id`): title, when/date, aggregated summary, notes, items list, contacts.
- **FR-MAT-3** A User can rename a Matome (local-first write, then `PATCH /api/matomes/:id` when reconciled).
- **FR-MAT-4** A User can edit a Matome's date/time (`happened_at`); lists re-sort immediately.
- **FR-MAT-5** A User can add an item (photo / file) to an existing Matome without minting a new one; the aggregated summary is marked stale.
- **FR-MAT-6** A User can remove an item from a Matome (deletes the row, best-effort deletes the on-device file, marks summary stale).
- **FR-MAT-7** A User can edit a Matome's notes (persistent, with an unsaved-changes leave guard).
- **FR-MAT-8** A User can regenerate the aggregated summary — a **local deterministic composition** of the items' AI summaries, not a new AI call.
- **FR-MAT-9** A User can archive a Matome (soft-delete: stamp `archived_at`, exclude from all lists, **offline-first**, Core best-effort) and restore it via an Undo affordance.
- **FR-MAT-10** An archived Matome stays openable and shows an archived banner with a Restore action.
- **FR-MAT-11** Only **sync-eligible** Matomes (effective space is a cloud space) are pushed to Core; archive/restore converge across sync (adopt-guard on pull + re-push pass).

### Organization & triage — `FR-ORG`

- **FR-ORG-1** An item sits in exactly one membership state: **loose** (no matome, no space), **in a matome**, or **filed directly into a space**. These compose with the matome/space graph; nothing forces a matome before a space.
- **FR-ORG-2** An item's **effective space** is resolved by one rule: `matome.space_id` if in a matome (matome wins), else `recording.workspace_id`, else `NULL`. This is the **sole sync-eligibility authority**.
- **FR-ORG-3** **Inbox** is a derived VIEW = everything whose effective space is `NULL` (loose items + draft matomes). It is never a stored field, boolean, sentinel id, or row.
- **FR-ORG-4** A User can file a Matome into a Space (Inbox → Space); the operation is local-first.
- **FR-ORG-5** A User can file/move a loose item or an item directly into a Space or Matome.
- **FR-ORG-6** When an item joins a matome, its own `recording.workspace_id` is **shadowed, not cleared**; leaving the matome makes it authoritative again (no silent data loss).
- **FR-ORG-7** Filing **organizes**; it does **not** by itself trigger sync. Sync happens iff the effective space is a **cloud** space.

### Spaces — `FR-SPC`

- **FR-SPC-1** A User can create a Space; a new Space is **local by default** (`is_local = true`) and can be created as cloud by explicit choice.
- **FR-SPC-2** A **local** Space's items **never** sync (no Core row, no upload) while they remain in it.
- **FR-SPC-3** A **cloud** Space's items sync to Core.
- **FR-SPC-4** A User can list Spaces (name + matome count) and open a Space detail listing its Matomes.
- **FR-SPC-5** A User can delete a Space; its Matomes return to the Inbox.
- **FR-SPC-6** A User can **promote** a local Space to cloud — **one-way**, with explicit itemized consent ("N items will leave this device"), idempotent per-item, resumable on partial failure, via a sealed `local → promoting → cloud | failed` state machine.
- **FR-SPC-7** Sync eligibility flows through **one operation-keyed gate** `SyncPolicy.can(caller, Operation.spaceSync, space)` — never an inline `if isCloud`, never a role enum.

### Contacts — `FR-CON`

- **FR-CON-1** A User can create, edit, and delete owner-owned Contacts (`displayName`, company, title, email, phone, notes/metadata, optional `linkedUserId`).
- **FR-CON-2** A User can tag a Contact in a Matome with a role (`organizer | attendee | speaker`); tagging is idempotent per (matome, contact).
- **FR-CON-3** A User can change a tagged Contact's role and untag a Contact.
- **FR-CON-4** A User can open a Contact detail showing linked Matomes (with roles), Space memberships, and related files.
- **FR-CON-5** Contact edges sync to Core (ensure Core id, attach edge, reconcile on pull) when their Matome syncs.

### Files (cross-Matome) — `FR-FIL`

- **FR-FIL-1** A User can browse all their files across every Matome in a grid or table view (preference persisted).
- **FR-FIL-2** A User can filter files by scope: **All / Loose / In a space**.
- **FR-FIL-3** A User can open a file, which routes by media type to the audio / image / document detail.
- **FR-FIL-4** A User can bulk-act on files: open, move to a Matome, file into a Space, delete (hard-delete with confirm).
- **FR-FIL-5** File download is presented but currently a stub ("not available").

### Item detail (read & playback) — `FR-ITM`

- **FR-ITM-1** A User can open an audio item: play/pause/seek a local file or a presigned Core URL, with duration/bitrate/size.
- **FR-ITM-2** A User can read an item's machine-generated transcript (read-only).
- **FR-ITM-3** A User can edit an item's notes (user-owned, with a leave guard).
- **FR-ITM-4** A User can retry failed processing as a new Core run; the client observes only that current run through bounded polling.
- **FR-ITM-5** A User can view an image item inline and fullscreen.
- **FR-ITM-6** A User can view a document item's metadata (name, size, type).
- **FR-ITM-7** A User can delete an item (removes on-disk file + Drift row + Core row) and move an item to a Space.

### Calendar — `FR-CAL`

- **FR-CAL-1** A User can view a month grid with heat dots on days that have Matomes, and navigate prev/next month.
- **FR-CAL-2** A User can tap a day to list that day's Matomes and open one.
- **FR-CAL-3** A User can filter the day list by Space.

### Preferences — `FR-PRF`

- **FR-PRF-1** A User can set theme mode (Light / Dark / System), persisted.
- **FR-PRF-2** A User can set language (English / 日本語), persisted.
- **FR-PRF-3** A User can set default Inbox view (Cards / Table) and Files view (Grid / Table), persisted.
- **FR-PRF-4** A User can sign out from settings (shows the signed-in email).

### Satori (AI roadmap) — `FR-SAT`

- **FR-SAT-1** A User can view the Satori roadmap (shipped / in-progress / next status for Search, Q&A, Email summaries, Meeting insights). It is **informational only** — no real AI interaction ships today.

---

## 2. Non-functional requirements

### Architecture & data — `NFR-ARCH`

- **NFR-ARCH-1 (Thin client).** The client only captures, uploads raw bytes, and reads results. It never runs transcription, OCR, or summarization.
- **NFR-ARCH-2 (Backend owns processing).** Adding a media type or model is a backend change; the client is media-agnostic.
- **NFR-ARCH-3 (Single source of record).** Core Postgres is authoritative; the client's Drift store is an offline mirror reconciled against Core, never the authority.
- **NFR-ARCH-4 (One ingestion contract).** Every media type uses the same `upload → pending → process → done` path.
- **NFR-ARCH-5 (Boundary).** The client talks only to Core + object storage; only Core talks to the AI Engine; the AI Engine is never client-facing.
- **NFR-ARCH-6 (Stable local PK).** A local row keeps its `rec_local_*` / `mat_local_*` id forever; reconciliation fills in `core_id` alongside it — the PK is never remapped.

### Local-first & sync — `NFR-SYNC`

- **NFR-SYNC-1 (Local-first).** The UI watches the local DB; capture, edits, archive, and filing succeed offline and sync in the background.
- **NFR-SYNC-2 (Offline-first writes).** Archive/restore/rename/edit are written to Drift first and are not rolled back if the Core leg fails; the two ends converge on next sync.
- **NFR-SYNC-3 (One resolver, one gate).** Exactly one resolver computes effective space / cloud-eligibility, and exactly one operation-keyed gate decides sync — no second predicate, no inline `if isCloud`, no role enum.
- **NFR-SYNC-4 (Two axes, never collapsed).** Sync mode (`is_local`) ⟂ tenancy (`space_type`); invariants `local ⟹ personal`, `org ⟹ cloud` couple them without merging.
- **NFR-SYNC-5 (Accepted data-loss risk).** A local-only item exists only on the device; a device wipe loses it. This is an owner-accepted trade-off of the local-first default; the mitigation is consented promotion + clear local/cloud affordances.
- **NFR-SYNC-6 (Feature-flagged).** The local-first-spaces behaviour is behind `FeatureFlags.localFirstSpaces` (single-flip rollback; default OFF).
- **NFR-SYNC-7 (Web carve-out).** Web has no at-rest local store (in-memory, online-first); its Inbox is server-backed.

### Security & privacy — `NFR-SEC`

- **NFR-SEC-1** Passwords are hashed with Argon2; auth is Guardian JWT (access + refresh). Authorization is app-level by `owner_id` (no Supabase Auth/RLS).
- **NFR-SEC-2** Object storage is reached only via short-lived Core-issued presigned URLs.
- **NFR-SEC-3** The AI Engine is internal-only behind a shared service token, never exposed to clients.
- **NFR-SEC-4 (Open risk).** A linked Contact's profile is viewable without that user's consent — a recorded, revisitable privacy risk to resolve before any multi-tenant launch.

### Platform & UX — `NFR-UX`

- **NFR-UX-1** One Flutter codebase targets mobile, Linux desktop, and web from a single flat go_router tree.
- **NFR-UX-2** The Matome detail is one route with breakpoint-driven layout (stacked letter on narrow; letter + side panel ≥ 900 px).
- **NFR-UX-3** Design tokens originate in Figma and are bound as Flutter `ThemeExtension`s, governed by the Widgetbook catalog and the `flutter-design-system-check` gate.
- **NFR-UX-4** The app is fully localized (en / ja) via slang.
- **NFR-UX-5** The always-visible Matome sync chip shows exactly three states (On device / Syncing / Synced); a permanently-failed item reads as "Syncing", with the explicit failure on the per-item badge.

### Quality — `NFR-QA`

- **NFR-QA-1** The host test suite (`flutter test`) is green; the design-system gate runs analyze + DS guards + golden tests + dual-flag lanes.
- **NFR-QA-2** Schema migrations are additive and reversible; backfills are tested-reversible.
