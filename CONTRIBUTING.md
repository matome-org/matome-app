# Contributing Guide

## Scope

This project is a React Native app using Expo SDK 54, Expo Router v6, React 19, Zustand, UI Kitten, and SQLite (`expo-sqlite`).

## Development Workflow

```bash
bun install
npx expo start
npx expo start --ios
npx expo start --android
npx expo lint
```

## Project Standards

- Keep route files in `app/` thin. Route files should primarily render Containers.
- Follow the Container/Presenter pattern inside `Views/`.
- Reusable UI belongs in `components/`.
- Data fetching and transformation belong in `processes/`.
- Business and persistence logic belong in `services/`.
- Global app state belongs in `stores/` (Zustand).
- Shared utilities belong in `utils/`.
- Use the `@/*` path alias from `tsconfig.json`.

## Commit Standards

- Use **semantic commits** (Conventional Commits), for example:
  - `feat: add recording duration badge`
  - `fix: prevent duplicate sqlite insert on save`
  - `docs: update auth flow documentation`
- Write all commit messages in **English**.
- Keep commit scope clear and focused.

## Documentation Standards

- All documentation must be written in **English**.
- Keep `README.md` concise and high-level.
- Any README section longer than 2 paragraphs must be moved to `.docs/`.
- When content is moved to `.docs/`, keep a short summary in `README.md` and link to the detailed file in `.docs/`.

## Pull Request Expectations

- Ensure lint passes before opening a PR.
- Keep changes consistent with existing architecture and file organization.
- Update docs when behavior, architecture, or workflows change.
