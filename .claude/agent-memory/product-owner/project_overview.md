---
name: Matome App — Project Overview
description: Core product context — what the app does, tech stack, current features, data model, and positioning from matome.io
type: project
---

Matome is a React Native mobile app (Expo SDK 55, expo-router v6, React 19) that lets users record audio, get it auto-transcribed via an external API, and organise recordings locally. All data is stored in SQLite on-device. Auth is handled by Supabase.

**Why:** The app is a voice-first life organiser — users capture voice notes in real time (one tap), the backend transcribes and summarises them via AI, and users can edit/annotate the transcript in Markdown. The core philosophy is "record now, organise later."

**How to apply:** Features should align with the core loop: capture → transcribe → summarise → organise. Any feature idea should fit or extend that loop.

## Product Positioning (from matome.io)
- Tagline: "Your Voice. Your Life. Finally Organized."
- Philosophy: "Your life happens in time, not in folders."
- Primary problem: busy professionals drowning in information with no time to process it — back-to-back meetings, ideas forgotten before they can be captured, instructions lost to distraction.
- Target audiences:
  1. Multi-job / freelance workers managing dual employment or multiple projects
  2. Busy professionals with continuous meetings and no memo-taking time
  3. Organisation enthusiasts who love planners but can't keep up with them
- Cultural angle: strong Japanese-market focus (product name is Japanese, UI is bilingual EN/JA, keywords include "techō" / digital planner)
- Privacy model: personal and work spaces separated under one ID; personal data device-encrypted, corporate data follows company protocols with audit trails
- Status as of April 2026: pre-launch ("Coming Soon" / 近日公開) — no pricing disclosed
- AI assistant named "Satori" is mentioned on the website (summarises meetings, extracts tasks, sends reminders) — not yet visible in the codebase as a named feature

## Tech Stack
- React Native 0.83, Expo SDK 55, Expo Router (file-based routing)
- UI Kitten / Eva Design System
- Zustand (global state), TanStack Query (wired but not yet actively used)
- SQLite via expo-sqlite (local persistence)
- Supabase (auth — email/password, session-based)
- Axios (API calls to external transcription/summarise service)
- i18next (localisation — English + Japanese)
- expo-updates / EAS Update (OTA deployment)
- React Native Reanimated + Gesture Handler

## Current Feature Set
- Audio recording with live waveform visualisation
- Auto-transcription via POST /api/v1/transcribe (external)
- AI summarisation via POST /api/v1/summarize (external)
- Recordings list (Inbox) grouped by Today / Yesterday / date
- Search across title, summary, and notes
- Details screen: audio playback, AI summary, editable Markdown notes
  - IN PROGRESS (uncommitted): Markdown toolbar (Bold/Italic/Heading/List/Checkbox) + edit/preview toggle using react-native-markdown-display
- Spaces (workspaces): create named folders, move recordings via long-press
- Settings: light/dark/system theme, English/Japanese language
- Supabase auth: email/password login & signup
- OTA updates via EAS Update

## Data Model (SQLite)
recordings: id, title, summary, notes, timestamp, duration, badge, isProcessing, audioFilePath, createdAt, workspaceId
workspaces: id, name, isDefault, createdAt

## Architecture
Container/Presenter in Views/, thin route files in app/, processes/ for data transforms, services/ for business logic, stores/ for Zustand.

## Key Gaps / Opportunities
- Calendar-first view: website promises "see your life on a timeline" — not yet built; high alignment with positioning
- Satori AI assistant: website names an AI assistant that extracts tasks and sends reminders — not in codebase yet
- Cloud sync / backup: all data is local SQLite; privacy model on website implies cloud with encryption is planned
- No notification / reminder system (Satori feature gap)
- Task extraction from transcripts: website promises this as a Satori capability
- Badge/label system is hardcoded (Work / Personal / Inbox) — not user-configurable
- No audio export / sharing
- No bulk actions on recordings (bulk delete, bulk move)
- Recording rename not surfaced in UI (title is auto-generated)
- TanStack Query is installed but unused
- No test framework configured
- Spaces lack description, icon customisation, or search
- Auth UX could be enhanced (social login, password reset)
