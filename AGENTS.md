# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

Matome is a React Native mobile app built with **Expo SDK 55** and **Expo Router v6** (file-based routing). It records audio, transcribes it via an external API, and stores recordings locally with SQLite. It uses React 19 with the new architecture and experimental React compiler enabled. The Expo app lives in `apps/mobile` inside a Bun workspaces + Turborepo monorepo.

## Commands

```bash
bun install              # Install dependencies (uses Bun, not npm)
bun run web              # Start the Next.js web app through Turbo
bun run ios              # Run on iOS simulator through Turbo
bun run android          # Run on Android emulator through Turbo
bun run lint             # Run ESLint through Turbo
```

### Testing

Tests run on **Jest 30** with the **jest-expo 55** preset and
**@testing-library/react-native 13**. Suites live in `apps/mobile/__tests__/unit/` and
`apps/mobile/__tests__/integration/`. Run all workspace tests with `bun run test`, or mobile-specific watch/coverage commands from `apps/mobile`. An Expo SDK 55 winter-runtime shim in `apps/mobile/jest.setup.js`
is required — **do not remove it** or every suite crashes on import. Maestro E2E
is planned but not yet configured. See `.docs/TESTING.md` for conventions,
structure, mock patterns, and the risk-priority order.

## Architecture

### Layered Structure

```
apps/mobile/app/          -> Expo Router routes (file-based). Thin wrappers that render Containers.
apps/mobile/Views/        -> Container/Presenter pattern per feature (Home, Details, Login, welcome)
apps/mobile/components/   -> Reusable UI components (NavBar, RecordingModal)
apps/mobile/processes/    -> Data fetching & transformation (homeData, auth)
apps/mobile/services/     -> Business logic (audioRecordingService, recordingService)
apps/mobile/stores/       -> Zustand global state (authStore, themeStore)
apps/mobile/utils/        -> Utilities (database.ts for SQLite, storage.ts for SecureStore)
apps/mobile/config/       -> API config (axios instances, interceptors), theme definitions
```

### Key Patterns

- **Container/Presenter**: Each feature in `Views/` has a `*Container.tsx` (state/logic) and a presenter (pure UI). Each component directory includes `.tsx`, `.types.ts`, `.styles.ts`, and `index.ts` barrel.
- **Path alias**: `@/*` maps to `apps/mobile` (configured in `apps/mobile/tsconfig.json`).
- **Routing**: `apps/mobile/app/(tabs)/` contains tab groups (`inbox/`, `explore/`). Dynamic routes use `[id].tsx`. Auth guard in `apps/mobile/app/_layout.tsx` redirects based on `useAuthStore`.
- **State**: Zustand for global state (auth, theme). TanStack Query is wired up but not actively used yet.
- **Data flow**: Route -> Container -> `processes/` (fetching/transforms) -> `services/` (SQLite CRUD, audio recording) -> `utils/database.ts`.
- **UI framework**: UI Kitten (`@ui-kitten/components`) with Eva Design System. Themes are defined in `config/themes.ts`.
- **Storage**: SQLite via `expo-sqlite` for recordings. `expo-secure-store` for auth tokens.
- **API**: Axios with request interceptor for auth token injection. API wrapper unwraps `response.data.data`.

### Database

SQLite `recordings` table: `id`, `title`, `summary`, `notes`, `timestamp`, `duration`, `badge`, `isProcessing`, `audioFilePath`, `createdAt`. Managed through `apps/mobile/services/recordingService.ts`.

### Auth Flow

The current auth flow uses a fake login (`processes/auth.ts`). Auth state is stored in Zustand. Root layout guards routes: authenticated users go to `(tabs)/explore`, unauthenticated users go to the welcome screen.
