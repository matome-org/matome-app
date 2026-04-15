---
name: Matome — Product Decisions & Feature Backlog
description: Finalized feature decisions, scope choices, and deferred ideas from PO sessions
type: project
---

## Calendar / Timeline Feature — APPROVED (April 2026)

Pattern chosen: Option A — dedicated Calendar tab alongside Inbox and Spaces.
- Month grid with dot indicators per day (dot = recordings exist that day)
- Tap a day → show a day-list of that day's recordings (title, Space badge, duration)
- Day-level granularity only (no hour-level)
- Space filtering: "All" view plus filter-by-Space; calendar respects active Space context
- Primary use case: daily digest — reviewing yesterday's recordings
- Implementation philosophy: start simple, ship the month grid + day list; do NOT over-engineer

**Why:** Aligns directly with the product positioning line "Your life happens in time, not in folders." Prepares the foundation for the future Satori daily digest AI feature.
**How to apply:** Keep the initial implementation lean. New data query needed: recordings grouped by date (all, not just Inbox-null). The NavBar currently hardcodes mic-button insertion at index 1; Calendar tab changes this to index 2 (Spaces) and may require NavBar refactor.

## Markdown Editor Polish — APPROVED (April 2026)

- Save action: FAB with checkmark icon currently always visible; needs clearer Save state signal — show "unsaved changes" indicator when transcript has been modified
- Unsaved-changes guard: warn user before navigating away with unsaved edits (Alert dialog)
- No scope change to the Markdown rendering or toolbar itself

**Why:** Details screen currently has no guard — users can accidentally navigate back and lose edits. FAB purpose is not obvious.

## pt-BR Localisation — APPROVED (April 2026)

- Add Brazilian Portuguese as a third language option alongside EN and JA
- User is Brazilian; first real users are Brazilian coworkers
- All existing i18n keys must be translated
- Settings screen language picker must include pt-BR option
- i18n file to create: locales/pt.ts (or pt-BR.ts — follow existing naming convention)

**Why:** User = Brazilian; immediate user base = Brazilian coworkers. EN and JA are currently present as cultural anchors (Japanese market focus) but pt-BR is the day-one practical need.
**How to apply:** i18next is already configured; adding a new locale is additive. The languageStore and Settings screen will need pt-BR added as an option. Check if i18next language code should be "pt" or "pt-BR".

## Resume Recording Draft — APPROVED (April 2026)

- When a recording session is interrupted (crash, close) or a draft exists on launch, the app detects the partial audio file and navigates programmatically to the recording screen.
- New recorded segments are separate files on disk; the frontend merges them into one file before calling the save/upload pipeline.
- If the user discards the draft: delete all partial audio file(s), no DB entry created.
- Entry points: mic FAB (opens modal) AND programmatic navigation (app detects draft on launch → navigates directly to recording screen without showing modal first).
- Draft detection must run at app startup (root layout or auth guard).

**Why:** Users lose recordings on crash. Programmatic recovery means the app auto-restores context so the user can resume without manual action.
**How to apply:** Requires a draft state persisted to disk (e.g., a JSON sidecar file listing partial URIs + metadata). The merge step must produce a single audio file before the existing transcription pipeline is invoked — keep the save pipeline unchanged downstream.

## Satori Config Tab — APPROVED (April 2026)

- Add a 4th tab "Satori" to the NavBar alongside Inbox, Calendar, and Spaces.
- Tab bar layout: 5 items total — Inbox | Calendar | [Mic FAB] | Spaces | Satori.
- Mic FAB stays in the middle slot (between Spaces and the right side, or between Calendar and Spaces — confirmed: middle of the 5-item bar).
- Initial screen content: placeholder layout only (name "Satori", brief description of the planned AI assistant, "Coming soon" state). No real functionality yet.
- NavBar must be refactored to support a configurable icon per tab rather than hardcoded name-based conditionals.

**Why:** Website already names "Satori" as a feature. Adding the tab now establishes navigation structure before AI features land, and signals product direction to early users.
**How to apply:** The current NavBar uses hardcoded `if (route.name === 'inbox')` / `if (route.name === 'calendar')` branching. With 4 real tabs + mic = 5 items, refactor to a tab config array (name → icon mapping) and inject mic at the correct index. Add `app/(tabs)/satori/` route.

## Deferred / Not Yet Scoped
- Satori AI assistant (task extraction, reminders) — mentioned on website, no codebase presence
- Cloud sync / backup — all data local SQLite
- Social login / password reset
- Bulk actions (bulk delete, bulk move)
- Audio export / sharing
- Recording rename UI
- TanStack Query activation
- Test framework setup
- Spaces icon/description customisation
