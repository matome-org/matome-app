# Matome — Product Requirements (PRD)

> Status: agreed · Last updated: 2026-06-23
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
organized, AI-summarized page, and lets the user file it where it belongs **on their
own terms**.

The core loop is **capture → process → organize**:

1. **Capture** raw material with zero friction — record audio, capture a meeting's
   system audio, or drop in a file. No setup, no mandatory naming, works offline.
2. The backend **processes** it — transcribes, OCRs, summarizes — without the client
   doing any AI work.
3. The user **organizes** it later, at their own pace — into a Matome, into a Space,
   or leaves it loose — and decides what syncs to the cloud and what stays on-device.

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
  knowledge worker / professional who runs many short meetings and calls and wants them
  captured and summarized without manual note-taking.]*
- **Tomorrow: teams and organizations.** The schema reserves shared/org spaces,
  members, roles, and organizations; the behaviour is deferred (§7).

---

## 4. Value proposition & principles

- **Local-first, on the user's terms.** Capture and organization work offline and live
  on-device first. The user explicitly chooses what becomes a **cloud** space and
  syncs; a new space is **local by default**. *(Trade-off, consciously accepted: an
  item never filed into a cloud space exists only on the device and is lost on a device
  wipe — see `architecture.md` D6.)*
- **Zero-friction capture.** A Matome is minted implicitly from the first item — no
  blank-page creation, no mandatory title.
- **AI does the busywork, not the client.** Transcription and summarization are
  server-side; the client stays thin and ships independently of model changes.
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
| **Auth** | Register, sign in, stay signed in across reloads, sign out. |
| **Capture** | Record mic audio (pause/resume); record a meeting via system-audio loopback (Linux desktop); import audio/image/document files; recover an interrupted draft. |
| **AI processing** | Automatic transcription + summarization per item via the backend, with live status and retry. |
| **Matome** | View a per-happening page (summary, notes, items, contacts); rename; edit date/time; add/remove items; edit notes; regenerate the aggregated summary; archive + restore. |
| **Organize** | Leave items loose, group into a Matome, file into a Space; the Inbox is the derived view of everything not yet filed into a space. |
| **Spaces** | Create local or cloud spaces; list/open/delete; promote a local space to cloud with explicit itemized consent. |
| **Contacts** | Maintain a personal contact directory; tag contacts in Matomes with roles; view a contact's linked Matomes/Spaces/files. |
| **Files** | Browse all files across Matomes (grid/table); filter by scope; open by media type; bulk move/file/delete. |
| **Calendar** | Month view of activity; open a day's Matomes; filter by Space. |
| **Item detail** | Play audio, read transcript, view images/documents, edit notes, retry failed transcription, delete. |
| **Preferences** | Theme (light/dark/system), language (en/ja), default Inbox/Files view. |
| **Satori** | View the AI roadmap (informational; no live AI features ship yet). |

---

## 6. Out of scope (today)

- **Collaboration & multi-user.** Sharing a Matome, shared/org-space ACL enforcement,
  multi-user sync, organization management — schema-reserved, behaviour deferred.
- **Roles / RBAC enforcement.** Role columns exist but are unenforced; the full
  configurable model is a separate deferred plan.
- **SSO** (Google / Outlook) — deferred; `owner_id` is a stable id so identities map
  cleanly later.
- **Live Satori AI** (search, Q&A over content, email/meeting insights) — roadmap only.
- **Automatic local backup** for the accepted local-data-loss risk — explicitly out of
  scope.
- **Win/macOS system-audio loopback** — deferred (Linux loopback ships).
- **Hard-delete UI** — archive (soft-delete + Undo) is the user-facing death path.
- **Cloud → local demotion** — promotion is one-way in v1.

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
- A high share of captures get an AI summary the user keeps without editing.
- Users actively use local-vs-cloud spaces (i.e. the local-first promise is exercised,
  not bypassed by syncing everything).
- The single Flutter codebase keeps per-platform parity green (see the DS-check gate).

> These are framing targets, not instrumented metrics in the codebase today.
