---
name: summarize
description: Review delivery adherence and generate summary artifacts for this repository workflow. Use when a user asks to compare implementation against `workflow/requirements/{task-name}.md` and create `workflow/summaries/{task-name}.md` from `.docs/summary_template.md` with reviewer-ready evidence.
---

# Summarize

Run workflow delivery-review steps 11-12: verify requirement adherence and produce a summary document.

## Workflow

1. Load review inputs.
- Read `workflow/requirements/{task-name}.md`.
- Read `workflow/plans/{task-name}.md`.
- Inspect implemented branch content.
- Read `.docs/summary_template.md`.

2. Perform adherence analysis.
- Compare implemented behavior to requirements and Definition of Done.
- Evaluate each acceptance criterion as `met` or `not met`.
- Record explicit deviations and rationale.

3. Build summary artifact.
- Create `workflow/summaries/{task-name}.md`.
- Fill `.docs/summary_template.md` completely with no placeholders.
- Include:
  - before/after state
  - key changes
  - files updated
  - validation evidence (tests and regression checks)
  - risks and follow-ups
  - references (requirements, plan, issue, commits, branch)

## Output Contract

Return sections in this order:

1. Adherence matrix (`criterion -> status -> evidence`).
2. Summary artifact status:
- file path
- completion state

## Quality Checks

- Do not leave any acceptance criterion unaccounted for.
- Keep deviations explicit and reviewable.
- Keep summary content sufficient for reviewer decision-making.
- Keep evidence concrete and traceable to repository changes.
