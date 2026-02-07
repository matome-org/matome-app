---
name: commit
description: Create commits for all pending repository changes by strictly following CONTRIBUTING.md commit rules. Use when the user asks to commit changes, organize commits by scope, avoid oversized commits, or enforce Conventional Commits messages in English.
---

# Commit

## Overview

Create small, scoped commits from the current working tree.
Follow `CONTRIBUTING.md` exactly for commit standards and message format.

## Workflow

1. Read `CONTRIBUTING.md` before creating commits.
2. Inspect pending changes with `git status --short` and `git diff --name-only`.
3. Group files by a single intent per commit (`feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `build`, `ci`, `perf`).
4. Split mixed files with `git add -p` when one file contains multiple scopes.
5. Stage only the files/hunks for one scope and commit.
6. Repeat until all pending changes are committed.

## Commit Rules

- Use Conventional Commits messages.
- Write every commit message in English.
- Keep each commit focused on one scope.
- Avoid putting many unrelated files in the same commit.
- Prefer multiple small commits over one large mixed commit.

## Message Format

Use one of these formats:

- `type: concise summary`
- `type(scope): concise summary`

Examples:

- `feat: add recording duration badge`
- `fix(sqlite): prevent duplicate insert on save`
- `docs: update auth flow documentation`

## Execution Checklist

1. Confirm grouping is by scope, not by file count only.
2. Confirm commit message type matches the real change intent.
3. Confirm message is English and concise.
4. Confirm no unrelated file is staged.
5. Confirm working tree is clean after final commit.
