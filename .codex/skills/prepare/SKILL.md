---
name: prepare
description: Create implementation preparation artifacts from approved requirements. Use when a user asks to convert `workflow/requirements/{task-name}.md` into a GitHub issue and generate or create the implementation branch using workflow naming rules.
---

# Prepare

Run workflow preparation steps 5-6: create a GitHub issue from requirements and create or define the implementation branch.

## Workflow

1. Load requirements source.
- Read `workflow/requirements/{task-name}.md`.
- Extract context, scope, acceptance criteria, and Definition of Done.

2. Build issue content.
- Produce a concise, implementation-oriented issue title and body.
- Keep issue text 1:1 aligned with requirements.
- Include an explicit reference to `workflow/requirements/{task-name}.md`.

3. Create issue or provide creation instructions.
- If tooling/access is available, create the issue and capture issue number + URL.
- If tooling/access is unavailable, return exact issue title/body and exact command(s) to create it.

4. Create branch or provide branch command.
- Generate branch name using one of:
  - `feature/{issue-number}-{task-name}`
  - `fix/{issue-number}-{task-name}` (for fixes)
- If possible, create the branch.
- If not possible, provide exact branch creation command.

## Output Contract

Return sections in this order:

1. Issue title and body used.
2. Issue status:
- issue number + URL when created
- or pending creation instructions
3. Branch status:
- branch name
- created/not-created state
- exact command when manual creation is required

## Quality Checks

- Keep strict traceability to requirements.
- Keep naming deterministic from issue number + task slug.
- Never generate a branch name without an issue number.
- Never add scope not present in requirements.
