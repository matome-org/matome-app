# Matome — Requirements

> Status: agreed · Last updated: 2026-07-20
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
| **Visitor** | An unauthenticated person. Can use welcome, register, sign in, and request/complete Core password reset. |
| **User (Owner)** | An authenticated person. Owns all their data (`owner_id`-scoped). The primary actor for every feature. |
| **AI Core** | Internal Core-managed processing service. Production currently transcribes supported audio; other typed outputs are capability-gated. Secondary actor, never client-facing. |
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
- **FR-AUTH-8** Authentication does not expose account content until the account-scoped encrypted Vault is enrolled/unlocked and ready. Existing keybundles are unwrapped; missing keybundles enroll once after password authentication.
- **FR-AUTH-9** Logout, account switch, and forced sign-out revoke leases, close account stores, and wipe live key material before the authenticated session is cleared.
- **FR-AUTH-10** A signed-out Visitor can request a password-reset code. The response is neutral and does not disclose whether the email identifies an account.
- **FR-AUTH-11** A signed-out Visitor can submit a reset token, new password, and matching confirmation, then return to Login without automatic authentication. The current shipping UI resets the Core credential only; recovery-code Vault-DEK rewrap exists in code/tests but is not wired into this flow.

### Capture — `FR-CAP`

- **FR-CAP-1** A User can record audio from the microphone with start / pause / resume / finish, a live duration timer, and a waveform amplitude meter.
- **FR-CAP-2** A User can record a meeting by mixing system-audio (loopback) + microphone — **Linux desktop only** (ffmpeg + PulseAudio/PipeWire).
- **FR-CAP-3** A User can import an existing photo, video, audio, or document when the active shell/picker and feature flags expose that type.
- **FR-CAP-4** A capture interrupted by a crash/kill is recoverable as a draft on next entry.
- **FR-CAP-5** Where microphone capture is unsupported (some web targets), the app degrades gracefully with a clear notice.
- **FR-CAP-6** A captured/imported file is sealed into the encrypted account Media Vault and committed to Drift **locally first** before any network activity.
- **FR-CAP-7** Meeting capture writes only to app-owned local staging while active. Finish independently validates one decodable M4A/AAC-LC mono artifact before atomically creating its Item, file payload, and upload work; queue egress starts only afterward.
- **FR-CAP-8** Meeting drafts record capture kind, session, backend, owned staging/final paths, codec, state, duration heartbeat, and storage health. Crash, failed finalization, cancel, and low storage leave either one recoverable owned artifact or no owned files.
- **FR-CAP-9** A file Item becomes visible only after the Vault publishes a ready blob and Drift atomically commits its opaque `blob_id`, logical size, SHA-256, metadata, and durable work. Durable Item state never stores a physical media path.
- **FR-CAP-10** Supported videos use the same Vault-backed file ingest and verified upload path. Current classification recognizes `mp4`, `mov`, `mkv`, and `avi`; video has no AI processing leg.

### Ingestion & processing — `FR-ING`

- **FR-ING-1** Every supported input (`audio | image | document | text`) uses one explicit processing lifecycle: `not_requested → queued → processing → succeeded | partial | failed`, with `not_available` when current capabilities or policy cannot dispatch it.
- **FR-ING-2** The client creates a file Item under its reconciled Matome (`POST /api/matomes/:id/items`) and receives a verified-upload envelope.
- **FR-ING-3** For an egress-eligible file, the client acquires an authenticated Vault read lease and streams plaintext bytes directly to object storage via the presigned URL; bytes never pass through Core, and the local ciphertext container/key material never leave the client.
- **FR-ING-4** The client requests processing (`POST /api/items/:id/process`); Core creates or replays one logical run and enqueues run-keyed Oban work.
- **FR-ING-5** AI Core downloads media via a presigned GET, executes only the advertised capability/output intersection, and POSTs one terminal result to Core's internal callback. Production currently supports transcript output for supported audio only; OCR, description, extraction, summaries, titles, embeddings, and classification are not production capabilities.
- **FR-ING-6** Core persists terminal state and bounded typed `processing_outputs`; user-authored notes remain independent.
- **FR-ING-7** The client polls `GET /api/items/:id` for the accepted run id with one request in flight and bounded backoff. Its 30-second observation timeout does not fail the Core run; Core's watchdog is authoritative.
- **FR-ING-8** On `failed`, the client surfaces the failure and the User can retry; retry re-enqueues server-side (Oban) — the client never processes media locally.
- **FR-ING-9** Callback handling is idempotent and current-run guarded by job id, run id, Item id, and source revision.
- **FR-ING-10** Text processing skips object storage and sends canonical AI `input` exactly as `{kind: "text", body: text_contents.body}`. `items.notes` and `matomes.description` are neither concatenated nor sent as separate fields; optional `locale` is non-content metadata.

### Matome (the central aggregate) — `FR-MAT`

- **FR-MAT-1** There is no blank-Matome creation flow. The current default organization lane mints a Matome from the first Item; the feature-gated `localFirstSpaces` lane may keep a new Item loose until later grouping.
- **FR-MAT-2** A User can open a Matome detail (`/matome/:id`): title, when/date, aggregated summary, notes, items list, contacts.
- **FR-MAT-3** A User can rename a Matome (local-first write, then `PATCH /api/matomes/:id` when reconciled).
- **FR-MAT-4** A User can edit a Matome's date/time (`happened_at`); lists re-sort immediately.
- **FR-MAT-5** A User can add photo, video, feature-gated file/document, existing file, or standalone text to an existing Matome without minting another Matome; the aggregated summary is marked stale.
- **FR-MAT-6** A User can remove an item from a Matome through the central tombstone/delete boundary, which converges remote deletion and lease-safe Vault ciphertext removal, and marks the aggregate summary stale.
- **FR-MAT-7** A User can edit a Matome's notes (persistent, with an unsaved-changes leave guard).
- **FR-MAT-8** A User can regenerate the aggregated summary — a **local deterministic composition** of the items' AI summaries, not a new AI call.
- **FR-MAT-9** A User can archive a Matome (soft-delete: stamp `archived_at`, exclude from all lists, **offline-first**, Core best-effort) and restore it via an Undo affordance.
- **FR-MAT-10** An archived Matome stays openable and shows an archived banner with a Restore action.
- **FR-MAT-11** Only **sync-eligible** Matomes (effective space is a cloud space) are pushed to Core; archive/restore converge across sync (adopt-guard on pull + re-push pass).
- **FR-MAT-12** Inbox supports searching Matomes, date grouping/card presentation, table sorting by title/date/Item count/people, selection, row regenerate/move/copy/archive actions, and bulk move/archive/delete.
- **FR-MAT-13** A User can copy a non-empty aggregated summary with truthful empty/success feedback.
- **FR-MAT-14** Inbox table exposes confirmed row/bulk hard delete as distinct from recoverable archive/restore. The current path directly uses `MatomesDao.deleteMatome`; no ItemDeletionService-style remote/Vault convergence guarantee is claimed for it.

### Organization & triage — `FR-ORG`

- **FR-ORG-1** With `FeatureFlags.localFirstSpaces` enabled, an Item sits in exactly one membership state: **loose** (no Matome, no Space), **in a Matome**, or **filed directly into a Space**. The configured default flag-OFF lane remains Matome-first.
- **FR-ORG-2** In the enabled local-first lane, an Item's **effective Space** is resolved by one rule: `matome.space_id` if in a Matome (Matome wins), else `item.workspace_id`, else `NULL`. This is the sole sync-eligibility authority.
- **FR-ORG-3** In that lane, **Inbox** is a derived view of everything whose effective Space is `NULL` (loose Items + draft Matomes), never a stored field/sentinel row. With the flag OFF, Inbox remains Matome-centric.
- **FR-ORG-4** A User can file a Matome into a Space (Inbox → Space); the operation is local-first.
- **FR-ORG-5** In the enabled local-first lane, a User can file/move a loose Item or a directly filed Item into a Space or Matome.
- **FR-ORG-6** In that lane, when an Item joins a Matome its own `item.workspace_id` is shadowed, not cleared; leaving the Matome makes it authoritative again.
- **FR-ORG-7** In the enabled local-first lane, filing organizes and only a cloud effective Space permits sync; the flag-OFF lane retains legacy sync behavior.

### Spaces — `FR-SPC`

- **FR-SPC-1** A User can enter a non-blank name to create a local Space in Drift. The create dialog does not offer direct cloud creation; Core Space creation occurs during promotion.
- **FR-SPC-2** In the enabled local-first lane, a local Space's Items do not sync while they remain there.
- **FR-SPC-3** A **cloud** Space's items sync to Core.
- **FR-SPC-4** A User can list Spaces (name + matome count) and open a Space detail listing its Matomes.
- **FR-SPC-5** A User can delete a local Space after directly filed Item `workspace_id` references are cleared. The current DAO does not explicitly clear `matomes.space_id`, so no stronger Matome-refiling guarantee is claimed.
- **FR-SPC-6** A User can confirm one-way local-to-cloud promotion. The service creates Core state, atomically rekeys references, drains idempotently, and returns cloud/failed; the current screen shows an aggregate count and reloads but does not expose detailed failed/resume state.
- **FR-SPC-7** Sync eligibility flows through **one operation-keyed gate** `SyncPolicy.can(caller, Operation.spaceSync, space)` — never an inline `if isCloud`, never a role enum.

### Contacts — `FR-CON`

- **FR-CON-1** A User can create, edit, and delete owner-owned local Contacts by display name and notes. Detail can display company/title/email/phone/linked-user fields when present, but the current form does not edit them.
- **FR-CON-2** A User can tag a Contact in a Matome with a role (`organizer | attendee | speaker`); tagging is idempotent per (matome, contact).
- **FR-CON-3** A User can change a tagged Contact's role and untag a Contact.
- **FR-CON-4** A User can open a Contact detail showing linked Matomes (with roles), Space memberships, and related files.
- **FR-CON-5** Contact edges sync to Core (ensure Core id, attach edge, reconcile on pull) when their Matome syncs.
- **FR-CON-6** Contact detail routes related files by audio/image/document/video media type. The visible Merge entry is currently reserved/no-op and is not a supported operation.

### Files (cross-Matome) — `FR-FIL`

- **FR-FIL-1** A User can browse all their files across every Matome in a grid or table view (preference persisted).
- **FR-FIL-2** With `FeatureFlags.localFirstSpaces` enabled, a User can filter files by scope: **All / Loose / In a Space**.
- **FR-FIL-3** A User can open a file, which routes by media type to audio, image, document, or video detail.
- **FR-FIL-4** A User can bulk-open, move to a Matome/Unfiled, export available local blobs, or delete with confirmation; direct file-into-Space is additionally exposed in the local-first lane.
- **FR-FIL-5** Export reads each available local `blob_id` through the Vault export boundary and creates a user-owned copy outside Matome's encryption, retention, and deletion lifecycle. The current bulk action does not rehydrate missing local blobs.
- **FR-FIL-6** Files table sorts by Name/When/Size; move-to-Matome includes Unfiled plus Undo; the expanded reading pane is read-only for notes while retaining supported processing retry.

### Item detail (read & playback) — `FR-ITM`

- **FR-ITM-1** A User can open an audio item: play/pause/seek through a local purpose-bound Vault lease or a presigned Core URL fallback, with duration/bitrate/size.
- **FR-ITM-2** A User can read an item's machine-generated transcript (read-only).
- **FR-ITM-3** A User can edit an item's notes (user-owned, with a leave guard).
- **FR-ITM-4** A User can retry failed processing as a new Core run; the client observes only that current run through bounded polling.
- **FR-ITM-5** A User can view an image item inline and fullscreen through a revocable Vault preview lease.
- **FR-ITM-6** A User can view document metadata and safely open/export it through a local Vault lease or fresh owner-scoped remote descriptor: approved types may open externally, active or unknown content stays attachment/download-only, and executable or script types are rejected.
- **FR-ITM-7** A User can delete an item through tombstone-first remote/Vault convergence and move an item to a Space. Delete and local eviction are distinct operations.
- **FR-ITM-8** A User can create, edit, and delete a standalone plain-text item and open it at `/items/text/:id`. Each mutation commits to Drift first and survives restart in the durable queue; cloud create uses `POST /api/items/text`, while edit/delete use `PATCH`/`DELETE /api/items/:id/text` with `expected_source_revision`, preserving local body or deletion intent and surfacing a conflict instead of overwriting a newer revision.
- **FR-ITM-9** A User can open `/items/video/:id` and see static video file detail/availability. Video supports Vault ingest, verified upload, routing, and Files export, but no in-app playback lease/player or AI dispatch today.

### Calendar — `FR-CAL`

- **FR-CAL-1** A User can view a month grid with heat dots on days that have Matomes, and navigate prev/next month.
- **FR-CAL-2** A User can tap a day to list that day's Matomes and open one.
- **FR-CAL-3** A User can filter the day list by Space.

### Preferences — `FR-PRF`

- **FR-PRF-1** A User can set theme mode (Light / Dark / System), persisted.
- **FR-PRF-2** A User can set language (English / 日本語), persisted.
- **FR-PRF-3** A User can set default Inbox view (Cards / Table) and Files view (Grid / Table), persisted.
- **FR-PRF-4** A User can sign out from settings (shows the signed-in email).
- **FR-PRF-5** A User can choose account-local Vault retention: `keep_forever` by default, or opt-in 30-day expiry that may collect only unreferenced, remote-verified blobs after all lease/work/integrity guards pass.
- **FR-PRF-6** A User can independently persist `always`, `onClick` (default), or `off` reading-pane mode for Inbox, Files, Spaces, and Contacts. Modes affect expanded master-detail layouts only when `FeatureFlags.masterDetailLayout` is enabled.

### Satori (AI roadmap) — `FR-SAT`

- **FR-SAT-1** In a legacy-shell build with Satori enabled, a User can view the static roadmap. In the primary `newNavShell` build the branch is absent and `/satori` safely redirects to Inbox.

### Developer-only surfaces — `FR-DEV`

- **FR-DEV-1** In builds with `FeatureFlags.godMode`, Settings exposes preset/custom Core endpoint controls. The flag is dark in the end-user configuration and the surface is not an account/cloud preference.

---

## 2. Non-functional requirements

### Architecture & data — `NFR-ARCH`

- **NFR-ARCH-1 (Thin client).** The client captures, encrypts local media, streams authenticated plaintext uploads, and reads results. It never runs transcription, OCR, or summarization.
- **NFR-ARCH-2 (Backend owns processing).** Adding an AI processor capability or model is a backend change; Flutter still owns media-specific capture/detail presentation.
- **NFR-ARCH-3 (Authority follows sync intent).** Core Postgres is authoritative for reconciled cloud records. Encrypted Drift is authoritative for deliberately local-only content and is the offline mirror for cloud records.
- **NFR-ARCH-4 (One processing contract).** Every supported input uses the explicit `not_requested → queued → processing → succeeded | partial | failed` lifecycle, with `not_available` for unsupported capability/policy; file inputs first complete verified upload, while text deliberately skips upload.
- **NFR-ARCH-5 (Boundary).** The client talks only to Core + object storage; only Core talks to AI Core; AI Core is never client-facing.
- **NFR-ARCH-6 (Stable local PK).** A local row keeps its `rec_local_*` / `mat_local_*` id forever; reconciliation fills in `core_id` alongside it — the PK is never remapped.

### Local-first & sync — `NFR-SYNC`

- **NFR-SYNC-1 (Local-first).** The UI watches the local DB; capture, edits, archive, and filing succeed offline and sync in the background.
- **NFR-SYNC-2 (Offline-first writes).** Archive/restore/rename/edit are written to Drift first and are not rolled back if the Core leg fails; the two ends converge on next sync.
- **NFR-SYNC-2A (Durable text mutations).** Standalone text create/edit/delete operations are revisioned durable work, not best-effort requests. Text work skips file hashing, presign, and byte upload while retaining explicit `local_saved`, `pending_sync`/`pending_delete`, `synced`, `failed`, and `conflict` states.
- **NFR-SYNC-3 (One resolver, one gate).** Exactly one resolver computes effective space / cloud-eligibility, and exactly one operation-keyed gate decides sync — no second predicate, no inline `if isCloud`, no role enum.
- **NFR-SYNC-4 (Two axes, never collapsed).** Sync mode (`is_local`) ⟂ tenancy (`space_type`); invariants `local ⟹ personal`, `org ⟹ cloud` couple them without merging.
- **NFR-SYNC-5 (Accepted data-loss risk).** A local-only Item exists only on the device; a device wipe loses it. Promotion is the cloud-sync boundary. Current consent shows the Space and an aggregate count; more explicit egress/recovery UX is not claimed.
- **NFR-SYNC-6 (Feature-flagged).** The local-first-spaces behaviour is behind `FeatureFlags.localFirstSpaces` (single-flip rollback; default OFF).
- **NFR-SYNC-7 (Web encrypted storage).** Web requires durable OPFS and stores both account Drift data and media encrypted at rest. Browsers without durable OPFS block local Vault operation rather than falling back to plaintext or transient storage.
- **NFR-SYNC-8 (Retention is independent).** Successful synchronization does not remove the local blob. `keep_forever` is the default; automatic orphan collection and explicit future cloud-only eviction are separate operations.

### Security & privacy — `NFR-SEC`

- **NFR-SEC-1** Passwords are hashed with Argon2; auth is Guardian JWT (access + refresh). Authorization is app-level by `owner_id` (no Supabase Auth/RLS).
- **NFR-SEC-2** Object storage is reached only via short-lived Core-issued presigned URLs.
- **NFR-SEC-3** AI Core is internal-only behind a shared service token, never exposed to clients.
- **NFR-SEC-4 (Open risk).** A linked Contact's profile is viewable without that user's consent — a recorded, revisitable privacy risk to resolve before any multi-tenant launch.
- **NFR-SEC-5 (Account isolation).** Encrypted databases, Media Vault namespaces, key material, leases, and scratch storage are isolated by account and fail closed on mismatch or unavailable secure storage.
- **NFR-SEC-6 (No durable plaintext path).** Item state stores only opaque `blob_id` and verified logical facts, never a durable physical path, file encryption key, or nonce. Playback/preview/open/export use purpose- and TTL-bound leases; native scratch files and Web Blob URLs are revoked on close, expiry, lock, logout, restart, or account switch as applicable.

### Platform & UX — `NFR-UX`

- **NFR-UX-1** One Flutter codebase targets mobile, Linux desktop, and web from a single flat go_router tree.
- **NFR-UX-2** The Matome detail is one route with breakpoint-driven layout (stacked letter on narrow; letter + side panel ≥ 900 px).
- **NFR-UX-3** Design tokens originate in Figma and are bound as Flutter `ThemeExtension`s, governed by the Widgetbook catalog and the `flutter-design-system-check` gate.
- **NFR-UX-4** The app is fully localized (en / ja) via slang.
- **NFR-UX-5** The always-visible Matome sync chip shows exactly three states (On device / Syncing / Synced); a permanently-failed item reads as "Syncing", with the explicit failure on the per-item badge.
- **NFR-UX-6** Legacy recording deep links (`/inbox/:id`, `/calendar/:id`, `/spaces/recording/:id`) resolve an owner-scoped local parent Matome and redirect when possible; if resolution returns null, the corresponding legacy detail fallback may render without a Core lookup.

### Quality — `NFR-QA`

- **NFR-QA-1** The host test suite (`flutter test`) is green; the design-system gate runs analyze + DS guards + golden tests + dual-flag lanes.
- **NFR-QA-2** Schema migrations are additive and reversible; backfills are tested-reversible.
