# Matome — Product Requirements (PRD)

> Status: agreed · Last updated: 2026-07-20
> The product framing behind Matome: the problem, the user, the value, and what is
> in vs out of scope today. Engineering detail lives in
> [`architecture.md`](architecture.md); the testable requirement list in
> [`requirements.md`](requirements.md); the behaviour catalog in
> [`../use-cases.md`](../use-cases.md).
>
> Items inferred from product intent (not directly from code) are marked
> *[assumption]*; everything else is grounded in the implementation.

---

## 1. What Matome is

**Matome** (まとめ — "a gathering / summary") turns the scattered audio, photos, and
notes around a *happening* — a meeting, a call, a conversation, a thought — into one
organized page, enriches supported inputs through backend processing, and lets the
user file it where it belongs **on their own terms**.

The core loop is **capture → process → organize**:

1. **Capture** raw material with zero friction — record audio, capture a meeting's
   system audio, or drop in a file. No setup, no mandatory naming, works offline.
2. The backend **processes** supported inputs without the client doing any AI work.
   Production currently transcribes supported audio; other typed processors remain
   capability-gated.
3. The user **organizes** it later, at their own pace — into a Matome or Space;
   the feature-gated local-first lane also supports leaving Items loose and
   deciding what syncs versus stays on-device.

---

## 2. The problem

People generate a lot of ephemeral context — meeting talk, voice memos, whiteboard
photos, business cards — and lose most of it. Existing tools force a trade the user
doesn't want to make at capture time:

- **Organize-first tools** (Notion-style) demand a destination *before* you can
  capture, so quick thoughts never get recorded.
- **Capture-first tools** (voice recorders, meeting-note apps) dump everything into an
  undifferentiated pile and/or push everything to a vendor cloud by default.

Matome's bet: **separate "what is this?" from "where does it go?" and from "should it
sync?"** — three independent questions the user answers when *they* are ready, not at
the moment of capture.

### The meishi (business-card) mental model

The triage metaphor is how Japanese business cards are handled: **you collect during
the day, then sort later**. Capture is instant and unstructured; triage — enriching
with photos/notes/contacts and filing into a Space — happens when convenient. *Filing
organizes; it does not, by itself, push anything to the cloud.*

---

## 3. Target user

- **Today: a single individual** — the Owner of all their own data. Matome is
  single-user; every record is `owner_id`-scoped. *[assumption: the near-term ICP is a
  knowledge worker / professional who runs many short meetings and calls and wants
  them captured and transcribed without manual note-taking.]*
- **Tomorrow: teams and organizations.** The schema reserves shared/org spaces,
  members, roles, and organizations; the behaviour is deferred (§7).

---

## 4. Value proposition & principles

- **Local-first, on the user's terms.** Capture and organization persist locally
  first. The full loose-Item/effective-Space egress policy is implemented behind
  `FeatureFlags.localFirstSpaces` and remains OFF in the configured primary build;
  when enabled, local-only content is lost on device wipe unless promoted/synced.
- **Zero-friction capture.** A Matome is minted implicitly from the first item — no
  blank-page creation, no mandatory title.
- **AI does the busywork, not the client.** Processing is server-side and
  capability-discovered; the client stays thin and ships independently of model
  changes.
- **Encrypted local ownership.** Drift and media are encrypted per account. Item
  state uses opaque blob identities, while playback, preview, open, upload, and
  export use bounded Vault leases.
- **One ingestion path** for every media type — adding video/pdf later is a backend
  change.
- **Three-state clarity over the cloud.** Every Matome shows exactly one of *On device
  / Syncing / Synced*, so the user always knows what has left the device.
- **One client, every surface.** A single Flutter codebase serves mobile, Linux
  desktop, and web.

---

## 5. Feature set (today)

| Area | What the user can do |
|---|---|
| **Auth** | Welcome, register, sign in, restore JWT sessions, enroll/unlock the account Vault, request/reset the Core password, and sign out with Vault teardown. Password reset does not currently rewrap the Vault keybundle. |
| **Capture** | Record mic audio; record a Linux loopback meeting; import photo/video/audio/document where the active picker permits; seal media into Vault; recover an interrupted draft. |
| **AI processing** | Production audio transcription via the backend, with explicit capability/status and retry. OCR, extraction, description, and summarization remain capability-gated. |
| **Matome** | Search/sort/browse; view hub; rename/date/notes; add existing/new media or text; contacts/Space; copy/regenerate summary; archive/restore; confirmed table hard delete. |
| **Organize** | Matome-centric Inbox by default; the `localFirstSpaces` lane additionally exposes loose Items, derived Inbox membership, and direct Item filing. |
| **Spaces** | Create a named local Space in Drift; list/open/delete; confirm one-way promotion to a Core-backed cloud Space; optionally preview at expanded width. |
| **Contacts** | Create/edit local display name + notes; delete; tag in Matomes with roles; inspect linked Matomes/Spaces and audio/image/document/video files. |
| **Files** | Browse grid/table; sort/filter where enabled; route audio/image/document/video; move/unfile with Undo; export/delete; optionally inspect in a read-only pane. |
| **Calendar** | Month view of activity; open a day's Matomes; filter by Space. |
| **Item detail** | Play audio, preview images, open documents through Vault leases, view static video detail, edit text/notes, use supported remote fallbacks, retry processing, and delete. |
| **Preferences** | Theme, language, default views, independent reading-pane mode for four surfaces, and account-local Vault retention (`keep_forever` by default). |
| **Satori** | Legacy-shell-only static roadmap; the primary new shell redirects `/satori` to Inbox. |

---

## 6. Out of scope (today)

- **Collaboration & multi-user.** Sharing a Matome, shared/org-space ACL enforcement,
  multi-user sync, organization management — schema-reserved, behaviour deferred.
- **Roles / RBAC enforcement.** Role columns exist but are unenforced; the full
  configurable model is a separate deferred plan.
- **SSO** (Google / Outlook) — deferred; `owner_id` is a stable id so identities map
  cleanly later.
- **Live Satori AI** (search, Q&A over content, email/meeting insights) — roadmap only.
- **Production OCR, image description, document extraction, summarization, title
  generation, embeddings, and classification** — typed contract seams exist, but
  production AI Core currently implements audio transcript only.
- **Automatic local backup** for the accepted local-data-loss risk — explicitly out of
  scope.
- **Complete clear-local-copy and all-media rehydrate UI.** The lifecycle defines
  safe `cloud_only` behavior, but the current product does not expose the complete
  transition across audio/image/document consumers.
- **Win/macOS system-audio loopback** — deferred (Linux loopback ships).
- **Matome hard-delete UI** — archive (soft-delete + Undo) remains the aggregate's
  user-facing death path; file Items have their own confirmed delete flow.
- **Cloud → local demotion** — promotion is one-way in v1.
- **Vault-preserving password-reset journey.** Recovery-code DEK rewrap machinery
  exists but is not connected to the shipping forgot/reset screens.
- **Video playback or AI processing.** Video is Vault-backed upload/export with a
  static detail today, not an in-app player or AI input.
- **Complete promotion failure/resume UI.** The Space service returns resumable
  state, but the current screen only reloads after promotion.
- **Contact merge and full structured-field editing.** Merge is reserved/no-op;
  the current form edits display name and notes only.
- **God Mode custom host in end-user builds.** It is a build-time guarded
  developer surface, dark in the product configuration.

---

## 7. Roadmap (deferred, ordered)

The architecture leaves seams so these add without a rewrite (see `architecture.md` §11):

1. **SSO** — Google / Outlook sign-in mapped onto stable `owner_id`s.
2. **Organizations & tenancy** — enforce `space_type` (personal/shared/org) on Axis B.
3. **Configurable authorization (RBAC)** — data-driven users × groups × custom roles ×
   operations behind the existing operation-keyed gate + a Policy Decision Point.
4. **Data-policy controls** for org-administered spaces; an admin panel.
5. **Satori AI** — search, Q&A, and insights over captured content.

---

## 8. Success signals *[assumption]*

- Time-to-capture is effectively zero (no mandatory destination/title before recording).
- A high share of supported audio captures produce a transcript the user finds useful.
- Users actively use local-vs-cloud spaces (i.e. the local-first promise is exercised,
  not bypassed by syncing everything).
- The single Flutter codebase keeps per-platform parity green (see the DS-check gate).

> These are framing targets, not instrumented metrics in the codebase today.
