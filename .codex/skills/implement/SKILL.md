---
name: implement
description: Execute implementation and validation from approved workflow plans in this repository. Use when a user asks to apply `workflow/plans/{task-name}.md`, create or update tests for new and impacted behavior, analyze regressions, and report validation evidence against `workflow/requirements/{task-name}.md`.
---

# Implement

Run workflow implementation steps 8-9: implement planned changes, execute validations, and report regression impact.

## Workflow

1. Load execution inputs.
- Read `workflow/plans/{task-name}.md`.
- Read `workflow/requirements/{task-name}.md` for validation reference.

2. Implement according to plan.
- Apply code changes in small, coherent increments.
- Preserve project architecture and conventions.

3. Execute testing strategy.
- Add or update tests for all new behavior.
- Add or update tests for impacted existing behavior.
- If automated testing is unavailable for a scenario, run and document manual validation steps.

4. Analyze regressions.
- Identify pre-existing flows potentially impacted by the changes.
- Validate those flows explicitly.
- Record outcomes (`pass`/`fail`), evidence, and unresolved issues.

## Output Contract

Return sections in this order:

1. Implementation summary (`what changed` and `where`).
2. Test coverage summary (`new`, `updated`, `manual`).
3. Regression impact checklist and outcomes.
4. Outstanding risks and follow-ups.

## Quality Checks

- Do not introduce silent behavior changes.
- Keep validation directly traceable to planned scope and impact analysis.
- Keep manual validation explicit, justified, and reproducible.
- Keep unresolved risks visible and actionable.
