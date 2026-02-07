## Skills Usage Order

Use skills in this exact order:

1. `$requirements`
2. `$prepare`
3. `$planning`
4. `$implement`
5. `$commit`
6. `$summarize`

## How to Use Each Skill (with examples)

### 1) `$requirements`
- Purpose: validate feasibility, clarify scope, and create requirements.
- Input: user request.
- Output: `workflow/requirements/{task-name}.md`.
- Example: `Use $requirements to analyze this request and create workflow/requirements/audio-transcription-badges.md.`

### 2) `$prepare`
- Purpose: create GitHub issue and implementation branch from approved requirements.
- Input: `workflow/requirements/{task-name}.md`.
- Output: issue content/status and branch content/status.
- Example: `Use $prepare for workflow/requirements/audio-transcription-badges.md and prepare the issue and branch.`

### 3) `$planning`
- Purpose: create implementation plan with traceability, tests, and risk coverage.
- Input: `workflow/requirements/{task-name}.md`.
- Output: `workflow/plans/{task-name}.md`.
- Example: `Use $planning to create workflow/plans/audio-transcription-badges.md from the approved requirements.`

### 4) `$implement`
- Purpose: execute plan changes, update tests, and validate regressions.
- Input: `workflow/plans/{task-name}.md` and `workflow/requirements/{task-name}.md`.
- Output: implemented changes, tests, validation evidence.
- Example: `Use $implement to execute workflow/plans/audio-transcription-badges.md and report test and regression outcomes.`

### 5) `$commit`
- Purpose: create focused Conventional Commits according to `CONTRIBUTING.md`.
- Input: current working tree after implementation/validation.
- Output: scoped commits.
- Example: `Use $commit to create focused Conventional Commits for all pending changes.`

### 6) `$summarize`
- Purpose: compare delivery vs requirements and generate PR-ready summary.
- Input: requirements, plan, and implemented branch state.
- Output: `workflow/summaries/{task-name}.md`.
- Example: `Use $summarize to validate adherence and generate workflow/summaries/audio-transcription-badges.md.`
