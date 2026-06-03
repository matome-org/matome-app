# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

Matome is a React Native mobile app built with **Expo SDK 54** and **Expo Router v6** (file-based routing). It records audio, transcribes it via an external API, and stores recordings locally with SQLite. It uses React 19 with the new architecture and experimental React compiler enabled.

## Commands

```bash
bun install              # Install dependencies (uses Bun, not npm)
npx expo start           # Start Expo dev server
npx expo start --ios     # Run on iOS simulator
npx expo start --android # Run on Android emulator
npx expo lint            # Run ESLint
```

### Testing

Tests run on **Jest 30** with the **jest-expo 55** preset and
**@testing-library/react-native 13**. Suites live in `__tests__/unit/` and
`__tests__/integration/`. Run with `bun test`, `bun run test:watch`, or
`bun run test:coverage`. An Expo SDK 55 winter-runtime shim in `jest.setup.js`
is required — **do not remove it** or every suite crashes on import. Maestro E2E
is planned but not yet configured. See `.docs/TESTING.md` for conventions,
structure, mock patterns, and the risk-priority order.

## Architecture

### Layered Structure

```
app/          -> Expo Router routes (file-based). Thin wrappers that render Containers.
Views/        -> Container/Presenter pattern per feature (Home, Details, Login, welcome)
components/   -> Reusable UI components (NavBar, RecordingModal)
processes/    -> Data fetching & transformation (homeData, auth)
services/     -> Business logic (audioRecordingService, recordingService)
stores/       -> Zustand global state (authStore, themeStore)
utils/        -> Utilities (database.ts for SQLite, storage.ts for SecureStore)
config/       -> API config (axios instances, interceptors), theme definitions
```

### Key Patterns

- **Container/Presenter**: Each feature in `Views/` has a `*Container.tsx` (state/logic) and a presenter (pure UI). Each component directory includes `.tsx`, `.types.ts`, `.styles.ts`, and `index.ts` barrel.
- **Path alias**: `@/*` maps to the project root (configured in `tsconfig.json`).
- **Routing**: `app/(tabs)/` contains tab groups (`inbox/`, `explore/`). Dynamic routes use `[id].tsx`. Auth guard in `app/_layout.tsx` redirects based on `useAuthStore`.
- **State**: Zustand for global state (auth, theme). TanStack Query is wired up but not actively used yet.
- **Data flow**: Route -> Container -> `processes/` (fetching/transforms) -> `services/` (SQLite CRUD, audio recording) -> `utils/database.ts`.
- **UI framework**: UI Kitten (`@ui-kitten/components`) with Eva Design System. Themes are defined in `config/themes.ts`.
- **Storage**: SQLite via `expo-sqlite` for recordings. `expo-secure-store` for auth tokens.
- **API**: Axios with request interceptor for auth token injection. API wrapper unwraps `response.data.data`.

### Database

SQLite `recordings` table: `id`, `title`, `summary`, `notes`, `timestamp`, `duration`, `badge`, `isProcessing`, `audioFilePath`, `createdAt`. Managed through `services/recordingService.ts`.

### Auth Flow

The current auth flow uses a fake login (`processes/auth.ts`). Auth state is stored in Zustand. Root layout guards routes: authenticated users go to `(tabs)/explore`, unauthenticated users go to the welcome screen.
