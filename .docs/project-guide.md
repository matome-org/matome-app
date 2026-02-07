# Project Guide

## Overview

Matome is a React Native app using Expo SDK 54 and Expo Router v6 (file-based routing). The app captures audio, sends content to a transcription flow, and stores recording metadata locally in SQLite.

Core stack:

- React 19
- Expo Router v6
- Zustand
- UI Kitten (Eva Design System)
- Axios
- SQLite via `expo-sqlite`

## Development Commands

```bash
bun install
npx expo start
npx expo start --ios
npx expo start --android
npx expo lint
```

## Repository Structure

```text
app/          -> Expo Router routes and layout files
Views/        -> Feature-level Container/Presenter modules
components/   -> Reusable UI building blocks
processes/    -> Data fetching and transformation flows
services/     -> Domain/business logic and persistence services
stores/       -> Zustand global stores
utils/        -> Shared utility helpers
config/       -> API and theme configuration
```

## Architecture Patterns

- Keep `app/` route files thin and focused on composition.
- Follow Container/Presenter in `Views/`.
- Use `processes/` for orchestration and data preparation.
- Use `services/` for business logic and persistence operations.
- Keep shared state in `stores/`.
- Use the path alias `@/*` configured in `tsconfig.json`.

## Routing and Auth

- Routing is file-based through Expo Router.
- Tab routes live under `app/(tabs)/`.
- Dynamic routes use file names like `[id].tsx`.
- Root layout route guarding redirects users based on auth state.
- Current auth logic uses a fake login process in `processes/auth.ts`.

## Data and Storage

- Recordings are stored in SQLite.
- Recording CRUD is managed by `services/recordingService.ts`.
- Auth tokens are stored with `expo-secure-store`.
- API requests use Axios with token injection in interceptors.

## Recordings Table

`recordings` fields:

- `id`
- `title`
- `summary`
- `notes`
- `timestamp`
- `duration`
- `badge`
- `isProcessing`
- `audioFilePath`
- `createdAt`
